defmodule Gaoxy.HTTP.ListenerSet.Plan do
  @moduledoc "A pure reusable listener declaration; endpoint state is prepared at startup."
  defstruct [
    :id,
    :target,
    :listeners,
    :service_ids,
    resource_budget: %{soft_limit: nil, hard_limit: nil},
    discovery: false,
    startup_timeout: 5_000
  ]
end

defmodule Gaoxy.HTTP.ListenerSet do
  @moduledoc """
  One logical application target and a set of required physical listeners.

  `plan/1` is pure. `prepare/2` performs startup preparation but never
  binds a socket. Direct embedding owns one core instance. Gateway callers use
  the same preparation contract with their own correctly budgeted instance.

      {Gaoxy.HTTP.ListenerSet,
       id: :site, plug: {MyPlug, []},
       listeners: [http: [port: 4000]]}

  Top-level `resource_budget: %{soft_limit: ..., hard_limit: ...}` selects one
  instance policy shared by all roles; omission uses adaptive VM-coordinated
  defaults. Service `limits` remain inside each physical listener.

  Secure roles accept `certfile` and `keyfile`. H3 requires `gaoxy_http3`.
  `discovery: [port: :bound, max_age: 60]` enables same-host Alt-Svc on secure
  H1/H2 responses. Independent port-zero bindings remain independent.
  """
  alias Gaoxy.HTTP.ListenerSet.{Plan, PreparedTarget}
  alias Gaoxy.HTTP.ListenerProvider
  @roles [:http, :https, :http3]
  @common [:id, :ip, :port, :limits, :http_limits, :extended_connect]
  @http [:protocols, :h2c, :h2_limits]
  @tls [:certfile, :keyfile, :versions, :alpn, :verify, :cacertfile, :fail_if_no_peer_cert]
  @keys [
    :id,
    :endpoint,
    :plug,
    :listeners,
    :service_ids,
    :resource_budget,
    :discovery,
    :startup_timeout
  ]

  def plan(%Plan{} = input) do
    target =
      case input.target do
        {:endpoint, module, options} -> [endpoint: {module, options}]
        {:plug, module, options} -> [plug: {module, options}]
        _ -> [endpoint: nil]
      end

    plan(
      target ++
        [
          id: input.id,
          listeners: input.listeners,
          service_ids: input.service_ids,
          discovery: input.discovery,
          startup_timeout: input.startup_timeout,
          resource_budget: input.resource_budget
        ]
    )
  end

  def plan(options) when is_list(options) do
    with :ok <- keyword(options, []),
         :ok <- known(options, @keys, []),
         {:ok, budget_plan} <- Gaoxy.Config.validate(Keyword.take(options, [:resource_budget])),
         id = Keyword.get(options, :id),
         true <- valid_id?(id) || field([:id], :invalid_id),
         {:ok, target} <- target(options),
         {:ok, listeners} <- listeners(Keyword.get(options, :listeners)),
         {:ok, ids} <- identities(id, listeners, Keyword.get(options, :service_ids, %{})),
         :ok <- conflicts(listeners, ids),
         {:ok, discovery} <- discovery(Keyword.get(options, :discovery, false), listeners),
         timeout = Keyword.get(options, :startup_timeout, 5_000),
         true <-
           (is_integer(timeout) and timeout > 0) || field([:startup_timeout], :invalid_timeout) do
      {:ok,
       %Plan{
         id: id,
         target: target,
         listeners: listeners,
         service_ids: ids,
         discovery: discovery,
         startup_timeout: timeout,
         resource_budget: budget_plan.resource_budget
       }}
    end
  end

  def plan(_), do: field([], :invalid_options)

  def child_spec(options) do
    {declaration, runtime} = split_options(options)

    %{
      id: {__MODULE__, declaration_id(declaration)},
      start: {__MODULE__, :start_link, [merge_options(declaration, runtime)]},
      restart: :transient,
      shutdown: shutdown(declaration)
    }
  end

  def start_link(options) do
    {declaration, runtime} = split_options(options)

    with {:ok, plan} <- plan(declaration) do
      # Link only after readiness, matching the core startup contract. A failed
      # required bind returns an error without also killing an untrapping caller.
      case GenServer.start(
             Gaoxy.HTTP.ListenerSet.Owner,
             {plan, runtime, self()},
             Keyword.take(runtime, [:name])
           ) do
        {:ok, owner} = result ->
          Process.link(owner)
          result

        error ->
          error
      end
    end
  end

  def info(owner), do: GenServer.call(owner, :info)

  @doc "Preflights all required providers and their complete planned service budgets, without binding."
  def preflight(%Plan{} = plan) do
    with {:ok, _} <- planned_services(plan), do: :ok
  end

  @doc false
  def planned_services(%Plan{} = plan), do: materialize(plan, :planned)

  @doc """
  Prepare one shared target and return finalized service specs without binding.
  `target:` is an internal runtime override for caller-owned generation stores.
  Discovery uses the same `activation_id:` passed to the core batch operation.
  """
  def prepare(%Plan{} = plan, options \\ []) do
    with :ok <- preflight(plan),
         :ok <- credentials(plan),
         {:ok, endpoint} <- initialize(Keyword.get(options, :target, plan.target)),
         context = discovery_context(plan, options),
         do: materialize(plan, %PreparedTarget{endpoint: endpoint, discovery: context})
  rescue
    error -> {:error, {:target_preparation_failed, Exception.message(error)}}
  catch
    kind, _ -> {:error, {:target_preparation_failed, kind}}
  end

  @doc false
  def inspect_listeners(instance, %Plan{} = plan) do
    Enum.map(plan.listeners, fn {role, options} ->
      id = Map.fetch!(plan.service_ids, role)
      info = Gaoxy.info(instance, id)

      base = %{
        role: role,
        id: id,
        transport: transport(role),
        protocols: protocols(role, options)
      }

      case info do
        %{mode: mode, local: local} ->
          Map.merge(base, Map.put(info, :state, mode)) |> Map.put(:local, local)

        error ->
          Map.merge(base, %{state: :recovering, local: error})
      end
    end)
  end

  @doc false
  def normalize_listener(role, options) when role in @roles do
    path = [:listeners, role]

    allowed =
      @common ++
        if(role == :http3,
          do: [:certfile, :keyfile, :h3_limits, :abyss_options],
          else: [:hell_options] ++ @http ++ if(role == :https, do: @tls, else: [])
        )

    with :ok <- keyword(options, path),
         :ok <- known(options, allowed, path),
         true <- owner_independent?(options) || field(path, :runtime_value),
         ip = Keyword.get(options, :ip, {127, 0, 0, 1}),
         true <- valid_ip?(ip) || field(path ++ [:ip], :invalid_ip),
         port = Keyword.get(options, :port, 0),
         true <-
           (is_integer(port) and port in 0..65_535) || field(path ++ [:port], :invalid_port),
         true <-
           (role != :http3 or tuple_size(ip) == 4) ||
             {:error, {:unsupported_capability, :quic_ipv6}},
         true <- (role != :http3 or ip != {0, 0, 0, 0}) || {:error, :wildcard_bind_unsupported},
         true <-
           is_boolean(Keyword.get(options, :extended_connect, false)) ||
             field(path ++ [:extended_connect], :invalid_boolean),
         :ok <- limit_maps(options, path),
         true <-
           Keyword.get(options, :protocols, [:http1]) in [[:http1], [:http2], [:http2, :http1]] ||
             field(path ++ [:protocols], :invalid_http_protocols),
         true <-
           Keyword.get(options, :h2c, :disabled) in [:disabled, :prior_knowledge] ||
             field(path ++ [:h2c], :invalid_http_protocols) do
      {:ok, options |> Keyword.put(:ip, ip) |> Keyword.put(:port, port) |> Enum.sort()}
    end
  end

  defp limit_maps(options, path) do
    Enum.reduce_while([:limits, :http_limits, :h2_limits, :h3_limits], :ok, fn key, :ok ->
      if is_map(Keyword.get(options, key, %{})),
        do: {:cont, :ok},
        else: {:halt, field(path ++ [key], :invalid_limits)}
    end)
  end

  @doc false
  def owner_independent?(value)
      when is_pid(value) or is_reference(value) or is_port(value) or is_function(value),
      do: false

  def owner_independent?(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.all?(&owner_independent?/1)

  def owner_independent?(value) when is_list(value), do: Enum.all?(value, &owner_independent?/1)

  def owner_independent?(value) when is_map(value),
    do: value |> Map.to_list() |> Enum.all?(&owner_independent?/1)

  def owner_independent?(_), do: true

  defp materialize(plan, target) do
    Enum.reduce_while(plan.listeners, {:ok, []}, fn {role, options}, {:ok, acc} ->
      with {:ok, provider} <- ListenerProvider.resolve(role),
           {:ok, options} <- provider.normalize(role, options),
           {:ok, spec} <-
             provider.materialize(role, Keyword.put(options, :id, plan.service_ids[role]), target) do
        {:cont, {:ok, [spec | acc]}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, specs} -> {:ok, Enum.reverse(specs)}
      error -> error
    end
  end

  defp initialize({:plug, module, options}),
    do: initialize({Gaoxy.HTTP.PlugEndpoint, {module, options}})

  defp initialize({:endpoint, module, options}), do: initialize({module, options})

  defp initialize({module, options}) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :init, 1) and
         function_exported?(module, :call, 2) do
      case module.init(options) do
        {:ok, initialized} -> {:ok, {module, initialized}}
        {:error, _} = error -> error
        _ -> {:error, :invalid_endpoint_init}
      end
    else
      {:error, :invalid_endpoint}
    end
  end

  defp initialize(_), do: {:error, :invalid_endpoint}

  defp target(options) do
    result =
      case {Keyword.get(options, :endpoint), Keyword.get(options, :plug)} do
        {{module, input}, nil} when is_atom(module) and module != nil ->
          {:ok, {:endpoint, module, input}}

        {nil, {module, input}} when is_atom(module) and module != nil ->
          {:ok, {:plug, module, input}}

        _ ->
          field([:target], :invalid_target)
      end

    with {:ok, value} <- result,
         true <- owner_independent?(value) || field([:target], :runtime_value),
         do: {:ok, value}
  end

  defp listeners(input) do
    with :ok <- keyword(input, [:listeners]),
         true <- input != [] || field([:listeners], :required),
         :ok <- known(input, @roles, [:listeners]) do
      Enum.reduce_while(@roles, {:ok, []}, fn role, {:ok, acc} ->
        case Keyword.fetch(input, role) do
          :error ->
            {:cont, {:ok, acc}}

          {:ok, options} ->
            case normalize_listener(role, options) do
              {:ok, normalized} -> {:cont, {:ok, acc ++ [{role, normalized}]}}
              error -> {:halt, error}
            end
        end
      end)
    end
  end

  defp identities(id, listeners, supplied) when is_map(supplied) do
    roles = Keyword.keys(listeners)

    if Map.keys(supplied) -- roles == [] do
      Enum.reduce_while(roles, {:ok, %{}}, fn role, {:ok, ids} ->
        service_id = Map.get(supplied, role, "#{id}:#{role}")

        cond do
          not valid_id?(service_id) -> {:halt, field([:service_ids, role], :invalid_id)}
          service_id in Map.values(ids) -> {:halt, {:error, {:duplicate_service, service_id}}}
          true -> {:cont, {:ok, Map.put(ids, role, service_id)}}
        end
      end)
    else
      field([:service_ids], :unknown_role)
    end
  end

  defp identities(_, _, _), do: field([:service_ids], :invalid_ids)

  defp conflicts(listeners, ids) do
    Enum.reduce_while(listeners, {:ok, []}, fn {role, options}, {:ok, previous} ->
      spec = %{id: ids[role], ip: options[:ip], port: options[:port], transport: transport(role)}

      case Enum.find(previous, &Gaoxy.Config.conflicts(spec, &1)) do
        nil -> {:cont, {:ok, [spec | previous]}}
        other -> {:halt, {:error, {:binding_conflict, spec.id, other.id}}}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp discovery(false, _), do: {:ok, false}
  defp discovery(nil, _), do: {:ok, false}

  defp discovery(input, listeners) when is_map(input),
    do: discovery(Map.to_list(input), listeners)

  defp discovery(input, listeners) do
    with :ok <- keyword(input, [:discovery]),
         :ok <- known(input, [:port, :max_age], [:discovery]),
         true <- Keyword.has_key?(listeners, :http3) || field([:discovery], :requires_http3),
         port = Keyword.get(input, :port, :bound),
         true <-
           (port == :bound or (is_integer(port) and port in 1..65_535)) ||
             field([:discovery, :port], :invalid_port),
         age = Keyword.get(input, :max_age, 60),
         true <-
           (is_integer(age) and age in 1..86_400) ||
             field([:discovery, :max_age], :invalid_max_age) do
      {:ok, %{port: port, max_age: age}}
    end
  end

  defp credentials(plan) do
    Enum.reduce_while(plan.listeners, :ok, fn
      {:http, _}, :ok ->
        {:cont, :ok}

      {role, options}, :ok ->
        case credential_files(options) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, field([:listeners, role, :tls], reason)}
        end
    end)
  end

  defp credential_files(options) do
    with {:ok, cert} <- File.read(options[:certfile] || ""),
         {:ok, key} <- File.read(options[:keyfile] || ""),
         true <- match?([{:Certificate, _, _} | _], :public_key.pem_decode(cert)),
         true <- :public_key.pem_decode(key) != [] do
      :ok
    else
      _ -> {:error, :invalid_credentials}
    end
  rescue
    _ -> {:error, :invalid_credentials}
  end

  defp discovery_context(%{discovery: false}, _), do: nil

  defp discovery_context(plan, options) do
    %{
      instance: options[:instance],
      activation_id: options[:activation_id],
      service_ids: Map.values(plan.service_ids),
      h3_id: plan.service_ids.http3,
      policy: plan.discovery,
      guard: Keyword.get(options, :discovery_guard)
    }
  end

  defp protocols(:http3, _), do: [:http3]

  defp protocols(role, opts),
    do: Keyword.get(opts, :protocols, if(role == :https, do: [:http2, :http1], else: [:http1]))

  defp transport(:http), do: :tcp
  defp transport(:https), do: :tls
  defp transport(:http3), do: :quic

  defp valid_id?(value),
    do:
      (is_atom(value) and not is_nil(value)) or (is_binary(value) and byte_size(value) in 1..128)

  defp valid_ip?(ip) when is_tuple(ip) and tuple_size(ip) in [4, 8] do
    bound = if tuple_size(ip) == 4, do: 255, else: 65_535
    Enum.all?(Tuple.to_list(ip), &(is_integer(&1) and &1 in 0..bound))
  end

  defp valid_ip?(_), do: false

  defp keyword(value, path) do
    if is_list(value) and Keyword.keyword?(value) and length(value) == map_size(Map.new(value)),
      do: :ok,
      else: field(path, :invalid_options)
  end

  defp known(options, allowed, path) do
    case Keyword.keys(options) -- allowed do
      [] -> :ok
      [key | _] -> field(path ++ [key], :unknown_option)
    end
  end

  defp field(path, reason), do: {:error, {:field, path, reason}}
  defp split_options(%Plan{} = plan), do: {plan, []}
  defp split_options([{:plan, %Plan{} = plan} | runtime]), do: {plan, runtime}

  defp split_options(options) when is_list(options),
    do:
      {Keyword.drop(options, [:name, :instance_name]),
       Keyword.take(options, [:name, :instance_name])}

  defp split_options(other), do: {other, []}
  defp merge_options(%Plan{} = plan, runtime), do: [plan: plan] ++ runtime
  defp merge_options(options, runtime), do: options ++ runtime
  defp declaration_id(%Plan{id: id}), do: id
  defp declaration_id(options) when is_list(options), do: Keyword.get(options, :id, :listeners)
  defp declaration_id(_), do: :listeners

  defp shutdown(declaration) do
    case plan(declaration) do
      {:ok, plan} ->
        drain =
          for {_, opts} <- plan.listeners,
              do: Map.get(Keyword.get(opts, :limits, %{}), :drain_timeout, 5_000)

        Enum.max(drain, fn -> 5_000 end) + 2_000

      _ ->
        7_000
    end
  end
end
