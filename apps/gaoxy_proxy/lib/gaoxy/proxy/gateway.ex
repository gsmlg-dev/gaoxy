defmodule Gaoxy.Proxy.Gateway do
  @moduledoc """
  An embeddable gateway with managed upstreams, shared logical route generations,
  owner recovery and bounded lifecycle operations. It needs `gaoxy_proxy` and its
  declared dependencies; HTTP/3 additionally needs `gaoxy_http3`.

      {Gaoxy.Proxy.Gateway,
       id: :edge,
       listener_sets: [[id: "web", endpoint: {Gaoxy.HTTP.Router, routes},
                        listeners: [http: [port: 8080]]]]}

  `compile/1` does no I/O or endpoint initialization. `reload_routes/4` requires
  `expected_revision:` and a finite `timeout:`. An optional absolute monotonic
  `deadline:` can only shorten that timeout. Its result is `{:ok,
  %{revision: n, generation: token}}`. A lost/late reply returns
  `{:error, {:operation_pending, {set_id, operation_id}}}`; reconcile with
  `operation_status/2` before retrying. Receipts retain the in-flight and latest
  terminal operation per logical set. Unknown/evicted receipts prove no outcome.

  Listener bindings and certificates are fixed for the gateway lifetime.
  Successful reloads survive runtime/upstream subtree recovery. Complete root
  or VM loss returns to the host's configured startup declaration.
  """
  alias Gaoxy.HTTP.{Generation, ListenerSet}
  alias Gaoxy.Proxy.Gateway.{Control, Declaration, Plan}
  alias Gaoxy.Lifecycle

  def compile(options), do: Declaration.compile(options)

  def child_spec(options) do
    {declaration, _} = split_options(options)

    id =
      case declaration do
        %Plan{id: id} -> id
        input -> Keyword.get(input, :id, __MODULE__)
      end

    %{
      id: id,
      start: {__MODULE__, :start_link, [options]},
      restart: :transient,
      # The runtime children derive their finite budgets from the complete
      # planned services. A second fixed cap must not truncate those drains.
      shutdown: :infinity,
      type: :supervisor
    }
  end

  def start_link(options) do
    {declaration, host} = split_options(options)

    with {:ok, plan} <- compile(declaration),
         {:ok, planned} <- planned_services(plan),
         do: Gaoxy.Proxy.Gateway.Supervisor.start_link({plan, planned, host})
  end

  def info(gateway) do
    with {:ok, control} <- control(gateway), do: Control.info(control)
  catch
    :exit, _ -> {:error, :gateway_unavailable}
  end

  def reload_routes(gateway, set_id, routes, options) do
    if is_list(options) and Keyword.keyword?(options) and
         length(options) == map_size(Map.new(options)) and
         Keyword.keys(options) -- [:timeout, :deadline, :expected_revision, :operation_id] == [] do
      do_reload_routes(gateway, set_id, routes, options)
    else
      {:error, :invalid_reload_options}
    end
  end

  defp do_reload_routes(gateway, set_id, routes, options) do
    timeout = Keyword.get(options, :timeout)
    relative = if is_integer(timeout) and timeout > 0, do: Lifecycle.deadline(timeout)
    supplied = Keyword.get(options, :deadline, relative)
    revision = Keyword.get(options, :expected_revision)
    operation = Keyword.get_lazy(options, :operation_id, &make_ref/0)
    identity = {set_id, operation}

    with true <- (is_integer(timeout) and timeout > 0) || {:error, :invalid_reload_timeout},
         true <- is_integer(supplied) || {:error, :invalid_reload_deadline},
         deadline = min(relative, supplied),
         true <- Lifecycle.remaining(deadline) > 0 || {:error, :reload_timeout},
         true <-
           (is_integer(revision) and revision >= 0) || {:error, :expected_revision_required},
         true <-
           (is_reference(operation) or (is_binary(operation) and byte_size(operation) in 1..128)) ||
             {:error, :invalid_operation_id},
         {:ok, routes} <- Declaration.routes(routes),
         {:ok, control} <- control(gateway) do
      caller = self()
      tag = make_ref()
      # Admission and submission are owned independently of the requesting
      # process, including the interval between those two messages.
      {:ok, _owner} =
        Task.Supervisor.start_child(Gaoxy.Proxy.Gateway.Operations, fn ->
          result =
            with {:ok, context} <- Control.context(control, deadline),
                 store when store != nil <- context.stores[set_id],
                 {:ok, accepted} <-
                   Generation.accepted(store, max(1, Lifecycle.remaining(deadline))) do
              case Generation.admit(store, operation, revision, routes, deadline) do
                {:ok, :admitted} ->
                  Lifecycle.call(
                    context.coordinator,
                    {:reload, set_id, operation, revision, accepted.epoch, routes, deadline},
                    deadline
                  )

                {:ok, %{status: :committed} = receipt} ->
                  {:ok, Map.drop(receipt, [:status])}

                {:ok, %{status: :rejected, reason: reason}} ->
                  {:error, reason}

                {:ok, %{status: :pending}} ->
                  {:error, {:operation_pending, identity}}

                error ->
                  error
              end
            else
              nil -> {:error, :unknown_listener_set}
              error -> error
            end

          send(caller, {tag, result})
        end)

      receive do
        {^tag, {:error, {:deadline_exceeded, :cleanup_pending}}} ->
          {:error, {:operation_pending, identity}}

        {^tag, {:error, :generation_unavailable}} ->
          {:error, {:operation_pending, identity}}

        {^tag, result} ->
          result
      after
        Lifecycle.remaining(deadline) -> {:error, {:operation_pending, identity}}
      end
    else
      nil -> {:error, :unknown_listener_set}
      {:error, _} = error -> error
      _ -> {:error, :invalid_reload_options}
    end
  end

  @doc """
  Inspect a retained reload receipt within a short finite observation window.
  An unavailable authority or unknown receipt cannot establish rejection.
  """
  def operation_status(gateway, {set_id, operation}) do
    deadline = Lifecycle.deadline(100)

    with {:ok, control} <- control(gateway),
         {:ok, context} <- Control.context(control, deadline),
         store when store != nil <- context.stores[set_id] do
      case Generation.operation_status(store, operation, Lifecycle.remaining(deadline)) do
        {:error, _} -> {:ok, %{status: :unknown}}
        result -> result
      end
    else
      nil -> {:error, :unknown_listener_set}
      {:error, _} -> {:error, :gateway_unavailable}
    end
  catch
    :exit, _ -> {:error, :gateway_unavailable}
  end

  def operation_status(_, _), do: {:error, :invalid_operation_id}

  @doc "Stop the entire gateway. Deadline uncertainty identifies the supervised cleanup owner."
  def stop(gateway, timeout \\ 5000)

  def stop(gateway, timeout) when is_integer(timeout) and timeout > 0 do
    deadline = Lifecycle.deadline(timeout)

    with root when is_pid(root) <- GenServer.whereis(gateway),
         {:ok, control} <- control(root) do
      caller = self()
      tag = make_ref()

      {:ok, owner} =
        Task.Supervisor.start_child(Gaoxy.Proxy.Gateway.Operations, fn ->
          result = stop_attempt(control, root, deadline)

          if result == :ok and Lifecycle.remaining(deadline) > 0 do
            send(caller, {tag, :ok})
          else
            send(caller, {tag, {:error, {:deadline_exceeded, :cleanup_pending, self()}}})
            reconcile_stop(control, root)
          end
        end)

      receive do
        {^tag, result} -> result
      after
        Lifecycle.remaining(deadline) -> {:error, {:deadline_exceeded, :cleanup_pending, owner}}
      end
    else
      nil -> {:error, :gateway_unavailable}
      error -> error
    end
  end

  def stop(_, _), do: {:error, :invalid_stop_timeout}

  @doc false
  def control(gateway) do
    root = GenServer.whereis(gateway)

    case Registry.lookup(Gaoxy.Proxy.Gateway.Registry, {:control_of, root}) do
      [{^root, control}] -> {:ok, GenServer.whereis(control)}
      _ -> {:error, :gateway_unavailable}
    end
  catch
    :exit, _ -> {:error, :gateway_unavailable}
  end

  @doc false
  def planned_services(%Plan{} = plan) do
    result =
      Enum.reduce_while(plan.sets, {:ok, plan.services}, fn set, {:ok, acc} ->
        result =
          case set.listener do
            nil ->
              spec = %{
                set.service
                | handler_options:
                    Map.merge(
                      set.service.handler_options,
                      %{endpoint: {Gaoxy.Proxy.Gateway.Unprepared, nil}, initialized: false}
                    )
              }

              with {:ok, spec} <- Gaoxy.Config.service(spec), do: {:ok, [spec]}

            listener ->
              ListenerSet.planned_services(listener)
          end

        case result do
          {:ok, specs} -> {:cont, {:ok, acc ++ specs}}
          error -> {:halt, error}
        end
      end)

    with {:ok, specs} <- result,
         {:ok, config} <- Gaoxy.Config.validate(services: specs, activation: :deferred),
         do: {:ok, config.services}
  end

  defp stop_runtime(context, deadline) do
    case GenServer.whereis(context.instance) do
      nil -> :ok
      instance -> Gaoxy.stop(instance, max(1, Lifecycle.remaining(deadline)))
    end
  end

  defp stop_attempt(control, root, deadline) do
    if Process.alive?(root) do
      with {:ok, context} <- Control.context(control, deadline),
           :ok <- Control.drain(control, deadline),
           :ok <- stop_runtime(context, deadline) do
        Supervisor.stop(root, :normal, max(1, Lifecycle.remaining(deadline)))
      end
    else
      :ok
    end
  catch
    :exit, _ -> {:error, :cleanup_pending}
  end

  defp reconcile_stop(control, root) do
    # The caller deadline controls its result, not ownership of the remaining
    # cleanup. Retry barriers as well as shutdown: an earlier timed-out barrier
    # may never have reached one or more stores.
    case stop_attempt(control, root, Lifecycle.deadline(100)) do
      :ok ->
        :ok

      _ ->
        monitor = Process.monitor(root)

        receive do
          {:DOWN, ^monitor, :process, ^root, _} -> :ok
        after
          10 ->
            Process.demonitor(monitor, [:flush])
            reconcile_stop(control, root)
        end
    end
  end

  defp split_options(%Plan{} = plan), do: {plan, []}

  defp split_options(options) when is_list(options),
    do: {Keyword.delete(options, :host), Keyword.get(options, :host, [])}
end

defmodule Gaoxy.Proxy.Gateway.Unprepared do
  @moduledoc false
  def init(value), do: {:ok, value}
  def call(exchange, _), do: {:error, :gateway_not_ready, exchange}
end
