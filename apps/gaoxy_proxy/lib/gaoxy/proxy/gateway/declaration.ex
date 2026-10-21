defmodule Gaoxy.Proxy.Gateway.Plan do
  @moduledoc "Pure reusable Gateway declaration. Runtime resources are prepared during startup."
  defstruct [:id, :name, sets: [], services: [], startup_timeout: 5000]
end

defmodule Gaoxy.Proxy.Gateway.Declaration do
  @moduledoc false
  alias Gaoxy.HTTP.{ListenerSet, PlugEndpoint, Router}
  alias Gaoxy.Proxy.Gateway.{Plan, Upstream}

  def compile(%Plan{} = plan) do
    compile(
      id: plan.id,
      name: plan.name,
      startup_timeout: plan.startup_timeout,
      listener_sets: for(%{listener: listener} <- plan.sets, listener != nil, do: listener),
      services: plan.services ++ for(%{listener: nil, service: service} <- plan.sets, do: service)
    )
  rescue
    _ -> {:error, :invalid_gateway_declaration}
  end

  def compile(options) when is_list(options) do
    with true <- Keyword.keyword?(options),
         true <- length(options) == map_size(Map.new(options)),
         true <-
           Keyword.keys(options) -- [:id, :name, :listener_sets, :services, :startup_timeout] ==
             [],
         {:ok, sets} <- traverse(Keyword.get(options, :listener_sets, []), &listener_set/1),
         {:ok, services, raw_sets} <- services(Keyword.get(options, :services, [])),
         sets = sets ++ raw_sets,
         timeout = Keyword.get(options, :startup_timeout, 5000),
         true <- is_integer(timeout) and timeout > 0,
         true <- valid_id?(Keyword.get(options, :id, :gateway)),
         true <- valid_name?(options[:name]),
         true <- owner_independent?({sets, services, options[:name], options[:id]}),
         true <- unique?(Enum.map(sets, & &1.id)),
         ids = Enum.flat_map(sets, &service_ids/1) ++ Enum.map(services, & &1[:id]),
         true <- Enum.all?(ids, &valid_id?/1) and unique?(ids),
         :ok <- bindings(sets, services) do
      {:ok,
       %Plan{
         id: Keyword.get(options, :id, :gateway),
         name: options[:name],
         sets: sets,
         services: services,
         startup_timeout: timeout
       }}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_gateway_declaration}
    end
  rescue
    _ -> {:error, :invalid_gateway_declaration}
  end

  def compile(_), do: {:error, :invalid_gateway_declaration}

  def routes(routes) when is_list(routes) and length(routes) <= 1024 do
    with true <- owner_independent?(routes),
         true <- :erlang.external_size(routes) <= 1_048_576,
         {:ok, routes} <- traverse(routes, &route/1) do
      {:ok, routes}
    else
      _ -> {:error, :invalid_route_declaration}
    end
  end

  def routes(_), do: {:error, :invalid_route_declaration}

  def materialize(routes) do
    traverse(routes, fn %{target: {module, config}} = route ->
      case config do
        %Upstream{} ->
          with {:ok, accepted} <- Upstream.materialize(config),
               do: {:ok, %{route | target: {module, accepted}}}

        _ ->
          {:ok, route}
      end
    end)
  end

  def route_input(route) do
    route
    |> Map.update(:path, :any, fn
      {:exact, path} -> path
      path -> path
    end)
    |> Map.update(:methods, :any, fn
      %MapSet{} = methods -> Enum.sort(methods)
      methods -> methods
    end)
  end

  def owner_independent?(term)
      when is_pid(term) or is_reference(term) or is_port(term) or is_function(term),
      do: false

  def owner_independent?(term) when is_map(term),
    do:
      Enum.all?(Map.to_list(term), fn {k, v} ->
        owner_independent?(k) and owner_independent?(v)
      end)

  def owner_independent?(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> owner_independent?()

  def owner_independent?([]), do: true
  def owner_independent?([h | t]), do: owner_independent?(h) and owner_independent?(t)
  def owner_independent?(_), do: true

  defp listener_set(input) do
    with {:ok, plan} <- ListenerSet.plan(input),
         {:ok, routes} <- target_routes(plan.target),
         do: {:ok, %{id: plan.id, listener: gateway_budgets(plan), routes: routes, service: nil}}
  end

  defp gateway_budgets(plan) do
    listeners =
      Enum.map(plan.listeners, fn {role, options} ->
        protocols =
          Keyword.get(
            options,
            :protocols,
            if(role == :https, do: [:http2, :http1], else: [:http1])
          )

        limits = Keyword.get(options, :limits, %{})
        # Keep the HTTP/2 builder's larger native connection/worker default.
        limits =
          if :http2 in protocols and role != :http3,
            do: limits,
            else: Map.put_new(limits, :max_bytes, 67_108_864)

        {role, Keyword.put(options, :limits, limits) |> Enum.sort()}
      end)

    %{plan | listeners: listeners}
  end

  defp target_routes({:endpoint, Router, %Router{routes: routes}}),
    do: routes(Enum.map(routes, &route_input/1))

  defp target_routes({:endpoint, Router, routes}), do: routes(routes)
  defp target_routes({:endpoint, module, config}), do: routes([%{target: {module, config}}])

  defp target_routes({:plug, module, config}),
    do: routes([%{target: {PlugEndpoint, {module, config}}}])

  defp services(input) when is_list(input) do
    Enum.reduce_while(input, {:ok, [], []}, fn spec, {:ok, raw, sets} ->
      case raw_service(spec) do
        {:ok, :raw, spec} -> {:cont, {:ok, [spec | raw], sets}}
        {:ok, :set, set} -> {:cont, {:ok, raw, [set | sets]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, raw, sets} -> {:ok, Enum.reverse(raw), Enum.reverse(sets)}
      error -> error
    end
  end

  defp services(_), do: {:error, :invalid_services}

  defp raw_service(
         %{handler_options: %{endpoint: {Router, %Router{routes: routes}}} = options} = spec
       ) do
    raw_service(%{
      spec
      | handler_options:
          Map.merge(options, %{
            endpoint: {Router, Enum.map(routes, &route_input/1)},
            initialized: false
          })
    })
  end

  defp raw_service(%{handler_options: %{endpoint: {Router, routes}}} = spec) do
    with true <- valid_id?(spec[:id]),
         {:ok, routes} <- routes(routes),
         do: {:ok, :set, %{id: spec.id, listener: nil, routes: routes, service: spec}}
  end

  defp raw_service(%{} = spec), do: {:ok, :raw, spec}
  defp raw_service(_), do: {:error, :invalid_service}

  defp route(%{target: {module, config}} = input) when is_atom(module) and module != nil do
    with true <- Map.keys(input) -- [:host, :path, :methods, :target] == [],
         true <- valid_host?(Map.get(input, :host, :any)),
         true <- valid_path?(Map.get(input, :path, :any)),
         true <- valid_methods?(Map.get(input, :methods, :any)),
         true <- owner_independent?(config) do
      {:ok, input}
    else
      _ -> {:error, :invalid_route_declaration}
    end
  end

  defp route(_), do: {:error, :invalid_route_declaration}

  defp valid_host?(:any), do: true

  defp valid_host?(host) when is_binary(host) do
    match?({:ok, _, nil}, Gaoxy.HTTP.HTTP1.Parser.parse_authority(host))
  end

  defp valid_host?(_), do: false
  defp valid_path?(:any), do: true
  defp valid_path?({:prefix, "/"}), do: true
  defp valid_path?({:prefix, path}), do: valid_path?(path) and not String.ends_with?(path, "/")

  defp valid_path?("/" <> _ = path) do
    Enum.all?(:binary.bin_to_list(path), &(&1 in 33..126 and &1 not in [??, ?#, ?\\])) and
      not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, path)
  end

  defp valid_path?(_), do: false
  defp valid_methods?(:any), do: true

  defp valid_methods?(values) when is_list(values) and values != [],
    do:
      Enum.all?(
        values,
        &(is_binary(&1) and Regex.match?(~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/, &1))
      )

  defp valid_methods?(_), do: false

  defp bindings(sets, services) do
    listeners =
      Enum.flat_map(sets, fn
        %{listener: nil, service: service} ->
          [service]

        %{listener: plan} ->
          Enum.map(plan.listeners, fn {role, options} ->
            %{
              transport: if(role == :http3, do: :quic, else: :tcp),
              ip: options[:ip],
              port: options[:port]
            }
          end)
      end) ++ services

    conflicts =
      for {a, i} <- Enum.with_index(listeners),
          b <- Enum.drop(listeners, i + 1),
          a[:port] not in [nil, 0] and a[:port] == b[:port],
          family(a[:transport]) == family(b[:transport]),
          a[:ip] == b[:ip] or a[:ip] == {0, 0, 0, 0} or b[:ip] == {0, 0, 0, 0},
          do: true

    if conflicts == [], do: :ok, else: {:error, :conflicting_bindings}
  end

  defp family(t) when t in [:tcp, :tls], do: :tcp
  defp family(t) when t in [:udp, :quic], do: :udp
  defp family(t), do: t
  defp service_ids(%{listener: nil, service: spec}), do: [spec.id]
  defp service_ids(%{listener: plan}), do: Map.values(plan.service_ids)
  defp unique?(values), do: length(Enum.uniq(values)) == length(values)

  defp valid_id?(id),
    do: (is_atom(id) and id != nil) or (is_binary(id) and byte_size(id) in 1..128)

  defp valid_name?(nil), do: true
  defp valid_name?(name) when is_atom(name), do: true
  defp valid_name?({:global, name}), do: owner_independent?(name)

  defp valid_name?({:via, module, name}) when is_atom(module) and module != nil,
    do: owner_independent?(name)

  defp valid_name?(_), do: false

  defp traverse(values, fun) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      error -> error
    end
  end

  defp traverse(_, _), do: {:error, :invalid_declaration}
end
