defmodule Gaoxy.Proxy.UpstreamGroups.Probe do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Lifecycle
  alias Gaoxy.HTTP.Resources

  alias Gaoxy.Proxy.{
    HTTPFetchClient,
    ManagedH2Client,
    ManagedH2Envelope,
    ManagedH2GroupBoundary,
    ManagedH2GroupAccounting,
    UpstreamGroups,
    UpstreamTransports
  }

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @day 86_400_000
  @h2 ManagedH2Client
  @normal_keys ~w(owner token member deadline health url group)a
  @state_keys @normal_keys ++
                ~w(cleanup_deadline owner_monitor timer request original_request managed_transport transport_selection transport_pins terminal cancelled headers outcome client limits request_options submitted_url)a
  @cleared ~w(member group health url request_options managed_transport submitted_url)a
  @finite_atoms ~w(invalid_request invalid_policy invalid_response upstream_failure upstream_task upstream_delivery_limit upstream_delivery_overlap upstream_trailer_limit timeout request_timeout unavailable cancelled cleanup_pending cleanup_unconfirmed invalid_resource invalid_resource_pin invalid_transport_endpoint unauthorized retiring resource_unavailable)a
  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)

  @impl true
  def init(%{recovery: _} = args) do
    with {:ok, args} <- UpstreamGroups.probe_recovery_arguments(args),
         {:ok, _} <- ManagedH2GroupAccounting.startup(__MODULE__, args),
         :ok <- ManagedH2GroupAccounting.preflight_control(:monitor, args.owner) do
      state = Map.put(args, :owner_monitor, Process.monitor(args.owner))

      case ManagedH2GroupAccounting.validate({:state, :recovery}, state) do
        :ok ->
          send(self(), :recover)
          {:ok, state}

        {:error, reason} ->
          Process.demonitor(state.owner_monitor, [:flush])
          {:stop, reason}
      end
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  def init(%{group: %{execution_profile: :managed_h2}} = args), do: init_group(args)

  def init(%{member: %{config: %{upstream_protocol: protocol}}} = args)
      when protocol in [:http2, :h2c],
      do: init_group(args)

  def init(%{member: %{config: %{client: @h2}}} = args), do: init_group(args)

  def init(args) do
    deadline = Map.get(args, :deadline, Lifecycle.deadline(args.health.timeout))
    timer = Process.send_after(self(), :expired, Lifecycle.remaining(deadline))

    state =
      Map.merge(args, %{
        deadline: deadline,
        cleanup_deadline: deadline + 1_000,
        owner_monitor: Process.monitor(args.owner),
        timer: timer,
        request: nil,
        original_request: nil,
        managed_transport: nil,
        transport_selection: nil,
        transport_pins: [],
        terminal: false,
        cancelled: false,
        headers: false,
        outcome: :failure
      })

    {:ok, state, {:continue, :open}}
  end

  defp init_group(args) do
    with {:ok, args} <- UpstreamGroups.probe_start_arguments(args),
         {:ok, _} <- ManagedH2GroupAccounting.startup(__MODULE__, args),
         :ok <- ManagedH2GroupAccounting.preflight_control(:monitor, args.owner) do
        timer = Process.send_after(self(), :expired, Lifecycle.remaining(args.deadline))

        state =
          Map.merge(args, %{
            cleanup_deadline: args.deadline + 1_000,
            owner_monitor: Process.monitor(args.owner),
            timer: timer,
            request: nil,
            original_request: nil,
            managed_transport: nil,
            transport_selection: nil,
            transport_pins: [],
            terminal: false,
            cancelled: false,
            headers: false,
            outcome: :failure,
            client: @h2,
            limits: args.member.config.limits,
            request_options: nil,
            submitted_url: nil
          })

        case account_state(state) do
          :ok -> {:ok, state, {:continue, :open}}
          {:error, reason} ->
            Process.cancel_timer(timer)
            Process.demonitor(state.owner_monitor, [:flush])
            {:stop, reason}
        end
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:open, %{client: @h2} = state), do: start_group_open(state)

  def handle_continue(:open, %{group: %{execution_profile: :managed_h2}} = state),
    do: start_group_open(state)

  def handle_continue(:open, %{member: %{config: %{upstream_protocol: protocol}}} = state)
      when protocol in [:http2, :h2c],
      do: start_group_open(state)

  def handle_continue(:open, %{member: %{config: %{client: @h2}}} = state),
    do: start_group_open(state)

  def handle_continue(:open, %{member: %{config: %{transport: nil}}} = state),
    do: open(state)

  def handle_continue(:open, state) do
    config = state.member.config

    with {:ok, instance} <- UpstreamGroups.claim_probe(state.owner, state.token, state.deadline),
         :ok <- opening_allowed(state),
         :ok <-
           UpstreamTransports.validate_endpoint(
             config.transport,
             %{
               origin: URI.to_string(config.uri),
               upstream_protocol: :http1,
               instance: instance
             },
             state.deadline
           ),
         :ok <- opening_allowed(state),
         {:ok, pins} <- Resources.pin_many([config.transport], self(), :request, state.deadline) do
      state = %{state | transport_pins: pins}

      with :ok <- opening_allowed(state),
           {:ok, client, token} <-
             UpstreamTransports.checkout(config.transport, pins, self(), state.deadline) do
        state = %{
          state
          | transport_selection: {config.transport, token},
            managed_transport: client
        }

        case opening_allowed(state) do
          :ok -> open(state)
          {:error, _} -> rejected(state)
        end
      else
        {:error, _} -> rejected(state)
      end
    else
      {:error, _} -> rejected(state)
    end
  end

  def handle_continue(:group_open, state) do
    with :ok <- account_state(state),
         :ok <- opening_allowed(state),
         {:ok, options} <- staged_group_options(state),
         :ok <- account(state, :options, options),
         :ok <- group_local_status(state, Lifecycle.now()),
         remaining = state.deadline - Lifecycle.now(),
         true <- remaining in 1..@day,
         options = %{options | timeout: remaining, opening_timeout: remaining},
         :ok <- account(state, :options, options),
         :ok <- apply(Gaoxy.Proxy.ManagedH2GroupBoundary, :activation, []) do
      case group_open_result(state, ManagedH2Client.open(options), Lifecycle.now()) do
        {:ok, staged, :group_bind} ->
          {:noreply, staged, {:continue, :group_bind}}

        {:error, {:cleanup_unconfirmed, _} = reason, dropped} ->
          # This discriminator holds every ledger, including when no request or
          # selection exists. It must never enter settle/complete or refund.
          {:stop, reason, dropped}

        {:error, reason, dropped} when reason in [:cancelled, :request_timeout, :timeout] ->
          rejected(dropped)

        {:error, _reason, dropped} ->
          settle(%{dropped | terminal: true})
      end
    else
      _ -> rejected(drop_group_opening(state))
    end
  end

  def handle_continue(:group_bind, state) do
    with :ok <- account_state(state),
         :ok <- opening_allowed(state),
         :ok <- group_local_status(state, Lifecycle.now()),
         true <- state.client == @h2 and state.request === state.original_request,
         true <- valid_group_handle?(state.original_request),
         true <- is_binary(state.submitted_url),
         true <- state.request_options == nil and state.managed_transport == nil,
         true <- active_transport_ledger?(state),
         :ok <- bind(state) do
      case opening_allowed(state) do
        :ok ->
          schedule()
          {:noreply, state}

        _ ->
          settle(%{drop_group_opening(state) | cancelled: true, terminal: true})
      end
    else
      _ -> settle(%{drop_group_opening(state) | cancelled: true, terminal: true})
    end
  end

  defp start_group_open(state) do
    with :ok <- account_state(state),
         :ok <- opening_allowed(state),
         :ok <- apply(Gaoxy.Proxy.ManagedH2GroupBoundary, :activation, []) do
      checkout_group(state)
    else
      _ -> rejected(drop_group_opening(state))
    end
  end

  defp checkout_group(state) do
    config = state.member.config

    with :ok <- account_state(state),
         :ok <- account(state, {:control, :probe},
           {:claim_probe, state.token, state.group, state.deadline}),
         {:ok, instance} <-
           UpstreamGroups.claim_probe(state.owner, state.token, state.group, state.deadline),
         :ok <- account(state, {:control, :probe}, {:ok, instance}),
         :ok <- opening_allowed(state),
         identity = %{
           origin: :binary.copy(config.uri.scheme <> "://" <> config.uri.authority),
           upstream_protocol: config.upstream_protocol,
           instance: instance
         },
         authority = {config.upstream_protocol,
           if(config.uri.scheme == "https", do: :https, else: :http),
           String.downcase(config.uri.host), config.uri.port},
         :ok <- account(state, {:control, :identity},
           {:validate_endpoint, config.transport, authority, instance, state.deadline}),
         :ok <- UpstreamTransports.validate_endpoint(config.transport, identity, state.deadline),
         :ok <- opening_allowed(state),
         {:ok, pins} = pin_reply <-
           Resources.pin_many([config.transport], self(), :request, state.deadline) do
      # Real owned pins must survive every post-reply refusal for cleanup.
      state = %{state | transport_pins: pins}

      with :ok <- account(state, {:owner_reply, :transport, :pin}, pin_reply),
           :ok <- account(state, :captured_pins, pins),
           :ok <- account_state(state),
           :ok <- opening_allowed(state),
           :ok <- account(state, {:owner_call, :transport, :checkout},
             {:checkout, config.transport, pins, self(), state.deadline}),
           {:ok, client, token} <-
             UpstreamTransports.checkout(config.transport, pins, self(), state.deadline) do
        state = %{
          state
          | transport_selection: {config.transport, token},
            managed_transport: client
        }

        with :ok <- account(state, :checked, client),
             :ok <- account_state(state),
             :ok <- opening_allowed(state),
             {:ok, staged, :group_open} <- prepare_group_open(state, instance, Lifecycle.now()) do
          {:noreply, staged, {:continue, :group_open}}
        else
          {:error, _, dropped} -> rejected(dropped)
          _ -> rejected(drop_group_opening(state))
        end
      else
        _ -> rejected(drop_group_opening(state))
      end
    else
      _ -> rejected(drop_group_opening(state))
    end
  end

  @doc false
  def prepare_group_open(state, instance, now) do
    if group_intent?(state) do
      with :ok <- account_state(state),
           true <- normal_group_state?(state),
           :ok <- account(state, :selected, state.member),
           :ok <- account(state, :checked, state.managed_transport),
           {:ok, _} <- UpstreamGroups.probe_start_arguments(Map.take(state, @normal_keys)),
           true <- is_pid(instance),
           true <- state.client == @h2 and state.limits === state.member.config.limits,
           true <- transport_aliases?(state),
           :ok <- group_local_status(state, now),
           limits = probe_limits(state.member.config.limits, state.health.timeout),
           neutral = %{
             target: state.health.path,
             method: :head,
             fields: [],
             body_mode: :none,
             max_upload_bytes: 1,
             request_limits: request_limits()
           },
           :ok <- account(state, :neutral, neutral),
           context = %{
             group: state.group,
             instance: instance,
             limits: limits,
             deadline: state.deadline,
             opening_deadline: state.deadline,
             now: now
           },
           :ok <- account(state, :context, context),
           {:ok, options, effective} <-
             ManagedH2GroupBoundary.prepare(
               state.member, neutral, state.managed_transport, context),
           :ok <- account(state, :request, options.request),
           :ok <- account(state, :options, options) do
        staged = %{
          drop_group_opening(state)
          | limits: effective,
            request_options: {:group_prepared, options}
        }

        case account_state(staged) do
          :ok -> {:ok, staged, :group_open}
          _ -> {:error, :invalid_request, drop_group_opening(state)}
        end
      else
        {:error, reason} when reason in [:cancelled, :request_timeout, :timeout] ->
          {:error, reason, drop_group_opening(state)}

        _ ->
          {:error, :invalid_request, drop_group_opening(state)}
      end
    else
      {:error, :invalid_request, drop_group_opening(state)}
    end
  end

  @doc false
  def drop_group_opening(state) do
    if group_intent?(state) do
      limits = Map.get(state, :limits)
      limits = if valid_limits?(limits), do: limits, else: nil

      state
      |> Map.merge(Map.new(@cleared, &{&1, nil}))
      |> Map.merge(%{client: @h2, limits: limits})
    else
      state
    end
  end

  @doc false
  def group_open_result(state, result, now) do
    if group_intent?(state) do
      result_accounting = account(state, :open_result, result)

      cond do
        successful_result?(result) ->
          handle = successful_handle(result)

          captured =
            if ManagedH2GroupAccounting.validate(:open_result, {:ok, handle, nil}) == :ok,
              do: Map.merge(state, %{request: handle, original_request: handle}),
              else: state

          if result_accounting == :ok and match?({:ok, _, nil}, result) and valid_group_handle?(handle) do
            with :ok <- account_state(state),
                 {:ok, options} <- staged_group_options(state),
                 :ok <- account(state, :options, options),
                 :ok <- group_local_status(captured, now),
                 bound = %{drop_group_opening(captured) | submitted_url: options.request.url},
                 :ok <- account_state(bound) do
              {:ok, bound, :group_bind}
            else
              {:error, reason} when reason in [:cancelled, :request_timeout, :timeout] ->
                {:error, reason, drop_group_opening(captured)}
              _ -> {:error, :invalid_request, drop_group_opening(captured)}
            end
          else
            {:error, {:cleanup_unconfirmed, :invalid_response}, drop_group_opening(captured)}
          end

        match?({:error, :cleanup_unconfirmed}, result) ->
          {:error, {:cleanup_unconfirmed, :cleanup_unconfirmed}, drop_group_opening(state)}

        match?({:error, {:cleanup_unconfirmed, _}}, result) ->
          {:error, group_reason(elem(result, 1)), drop_group_opening(state)}

        true ->
          # Refused raw error interiors are normalized immediately below and
          # never retained in S or projected as an accepted U capability.
          with :ok <- account_state(state),
               {:ok, options} <- staged_group_options(state),
               :ok <- account(state, :options, options),
               :ok <- group_local_status(state, now) do
            reason =
              case result do
                {:error, reason} -> group_reason(reason)
                _ -> :invalid_response
              end

            {:error, reason, drop_group_opening(state)}
          else
            {:error, reason} when reason in [:cancelled, :request_timeout, :timeout] ->
              {:error, reason, drop_group_opening(state)}
            _ -> {:error, :invalid_request, drop_group_opening(state)}
          end
      end
    else
      {:error, :invalid_request, drop_group_opening(state)}
    end
  end

  defp account(state, selector, original) do
    if group_intent?(state), do: ManagedH2GroupAccounting.validate(selector, original), else: :ok
  end

  defp account_state(state), do: account(state, {:state, :probe}, state)

  defp group_intent?(state) do
    match?(%{client: @h2}, state) or
      match?(%{group: %{execution_profile: :managed_h2}}, state) or
      match?(%{member: %{config: %{upstream_protocol: p}}} when p in [:http2, :h2c], state) or
      match?(%{member: %{config: %{client: @h2}}}, state)
  end

  defp normal_group_state?(
         %{
           cleanup_deadline: cleanup,
           owner_monitor: monitor,
           timer: timer,
           request: nil,
           original_request: nil,
           request_options: nil,
           submitted_url: nil,
           terminal: terminal,
           cancelled: cancelled,
           headers: headers,
           outcome: outcome
         } = state
       )
       when map_size(state) == 23 do
    exact_state_keys?(state) and signed_time?(cleanup) and is_reference(monitor) and
      is_reference(timer) and
      is_boolean(terminal) and is_boolean(cancelled) and is_boolean(headers) and
      outcome in [:failure, :success, :cancelled]
  end

  defp normal_group_state?(_), do: false
  defp exact_state_keys?(state), do: Enum.sort(Map.keys(state)) == Enum.sort(@state_keys)

  defp transport_aliases?(%{
         member: %{config: %{transport: transport}},
         transport_selection: {transport, token},
         transport_pins: pins
       })
       when is_reference(token),
       do: pin_alias?(pins, transport)

  defp transport_aliases?(_), do: false

  defp active_transport_ledger?(%{
         transport_selection: {
           %{provider: UpstreamTransports, owner: owner, owner_epoch: epoch, resource: resource} =
             transport,
           token
         },
         transport_pins: pins
       }) do
    map_size(transport) == 4 and is_pid(owner) and is_reference(epoch) and
      is_reference(resource) and is_reference(token) and pin_alias?(pins, transport)
  end

  defp active_transport_ledger?(_), do: false

  defp pin_alias?(
         [
           %{
             provider: UpstreamTransports,
             owner: owner,
             owner_epoch: epoch,
             operation: operation,
             ref: ref,
             handles: [transport],
             kind: :request,
             holder: holder
           } = pin
         ],
         %{owner: owner, owner_epoch: epoch} = transport
       ) do
    map_size(pin) == 8 and is_reference(operation) and is_reference(ref) and is_pid(holder)
  end

  defp pin_alias?(_, _), do: false

  defp group_local_status(state, now) do
    deadline = Map.get(state, :deadline)
    cancelled = Map.get(state, :cancelled)
    terminal = Map.get(state, :terminal)

    cond do
      not signed_time?(now) or not signed_time?(deadline) ->
        {:error, :invalid_request}

      deadline > @signed_max - 1_000 or not signed_time?(deadline - now) ->
        {:error, :invalid_request}

      not is_boolean(cancelled) or not is_boolean(terminal) ->
        {:error, :invalid_request}

      cancelled or terminal ->
        {:error, :cancelled}

      deadline <= now ->
        {:error, :request_timeout}

      deadline - now > @day ->
        {:error, :invalid_request}

      true ->
        :ok
    end
  end

  defp signed_time?(value),
    do: is_integer(value) and value >= @signed_min and value <= @signed_max

  defp valid_limits?(
         %{
           max_chunk_bytes: chunk,
           opening_timeout: opening,
           idle_timeout: idle,
           write_timeout: write,
           max_lifetime: lifetime
         } = limits
       )
       when map_size(limits) == 5 do
    is_integer(chunk) and chunk in 1..65_536 and
      Enum.all?([opening, idle, write, lifetime], &(is_integer(&1) and &1 in 1..@day))
  end

  defp valid_limits?(_), do: false

  defp probe_limits(limits, timeout),
    do: %{
      limits
      | opening_timeout: min(limits.opening_timeout, timeout),
        write_timeout: min(limits.write_timeout, timeout),
        max_lifetime: min(limits.max_lifetime, timeout)
    }

  defp request_limits,
    do: %{
      max_headers: 256,
      max_header_bytes: 65_536,
      max_trailers: 128,
      max_trailer_bytes: 65_536
    }

  defp staged_group_options(
         %{client: @h2, request_options: {:group_prepared, options}, limits: limits} = state
       )
       when is_map(options) and map_size(options) == 7 do
    with true <- exact_state_keys?(state),
         %{
           request: request,
           managed_transport: checked,
           timeout: timeout,
           opening_timeout: opening,
           write_timeout: write,
           deadline: deadline,
           opening_deadline: opening_deadline
         } <- options,
         true <-
           Enum.all?(
             [:member, :group, :health, :url, :managed_transport, :submitted_url],
             &(Map.get(state, &1) == nil)
           ),
         true <- valid_limits?(limits),
         :ok <- ManagedH2Envelope.validate_request(request),
         true <- request.method == :head and request.fields == [] and request.body_mode == :none,
         true <- request.max_upload_bytes == 1 and request.request_limits == request_limits(),
         :ok <- ManagedH2Envelope.validate_checked_client(checked, request.protocol),
         true <- checked_origin?(checked, request),
         true <- deadline === state.deadline and opening_deadline === state.deadline,
         true <- Enum.all?([timeout, opening, write], &(is_integer(&1) and &1 in 1..@day)),
         true <-
           opening <= timeout and timeout <= limits.max_lifetime and
             opening <= limits.opening_timeout,
         true <- write == limits.write_timeout do
      {:ok, options}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp staged_group_options(_), do: {:error, :invalid_request}

  defp checked_origin?(checked, request) do
    uri = URI.parse(request.url)
    scheme = if uri.scheme == "https", do: :https, else: :http

    {request.protocol, scheme, String.downcase(uri.host), uri.port} ===
      {checked.policy.protocol, checked.policy.scheme, checked.policy.host, checked.policy.port}
  end

  defp successful_result?(:ok), do: true

  defp successful_result?(value) when is_tuple(value) and tuple_size(value) > 0,
    do: elem(value, 0) == :ok

  defp successful_result?(_), do: false

  defp successful_handle(value) when is_tuple(value) and tuple_size(value) >= 2,
    do: elem(value, 1)

  defp successful_handle(_), do: nil

  defp valid_group_handle?(handle) do
    case ManagedH2Client.completion(handle) do
      %HTTP.RequestCompletion{} = completion when map_size(completion) == 4 ->
        completion === handle.completion

      _ ->
        false
    end
  end

  defp group_reason({:cleanup_unconfirmed, cause}),
    do: {:cleanup_unconfirmed, if(cause in @finite_atoms, do: cause, else: :cleanup_unconfirmed)}

  defp group_reason(reason), do: finite_reason(reason, 0)
  defp finite_reason(reason, _) when reason in @finite_atoms, do: reason
  defp finite_reason(:not_running, _), do: :unavailable
  defp finite_reason({:deadline_exceeded, :cleanup_pending}, _), do: :timeout
  defp finite_reason(:transport_endpoint_mismatch, _), do: :unavailable
  defp finite_reason(:request_limit, _), do: :unavailable
  defp finite_reason(:resource_admission_closed, _), do: :unavailable

  defp finite_reason({:capacity, kind}, _)
       when kind in [:request_tokens, :pins, :owned_payload_bytes],
       do: :unavailable

  defp finite_reason({kind, reason}, depth)
       when depth < 3 and
              kind in [
                :cleanup_failed,
                :transport_cleanup_failed,
                :pin_release_failed,
                :service_cleanup_failed,
                :selection_cleanup_failed
              ],
       do: {kind, finite_reason(reason, depth + 1)}

  defp finite_reason(_, _), do: :upstream_failure

  defp opening_allowed(state) do
    monitor = state.owner_monitor

    receive do
      {:"$gen_cast", :cancel} -> {:error, :cancelled}
      :expired -> {:error, :cancelled}
      {:DOWN, ^monitor, :process, _, _} -> {:error, :cancelled}
    after
      0 ->
        if Lifecycle.remaining(state.deadline) > 0 and Process.alive?(state.owner),
          do: :ok,
          else: {:error, :cancelled}
    end
  end

  defp rejected(state),
    do: settle(%{state | terminal: true, cancelled: true, outcome: :cancelled})

  defp open(state) do
    config = state.member.config

    options = %{
      url: state.url,
      method: :head,
      headers: [],
      body: :none,
      cacertfile: config.cacertfile,
      connect_address: config.connect_address,
      managed_transport: state.managed_transport,
      timeout: Lifecycle.remaining(state.deadline),
      opening_timeout: state.health.timeout,
      write_timeout: min(config.limits.write_timeout, state.health.timeout)
    }

    case HTTPFetchClient.open(options) do
      {:ok, request, _} ->
        state = %{state | request: request, original_request: request}

        case bind(state) do
          :ok ->
            schedule()
            {:noreply, state}

          {:error, _} ->
            settle(%{state | cancelled: true, terminal: true})
        end

      {:error, {:cleanup_unconfirmed, _} = reason} ->
        {:stop, reason, state}

      {:error, _} ->
        complete(%{state | terminal: true})
    end
  end

  defp bind(state) do
    selected_client = client(state)
    completion = selected_client.completion(state.original_request)

    with :ok <- account_state(state),
         :ok <- account(state, {:control, :probe}, {:bind_probe, state.token, completion}),
         :ok <- bind_transport(state, completion),
         do: UpstreamGroups.bind_probe(state.owner, state.token, completion)
  end

  defp bind_transport(%{transport_selection: nil}, _), do: :ok

  defp bind_transport(%{transport_selection: {handle, token}} = state, completion) do
    with :ok <- account(state, {:owner_call, :transport, :bind},
           {:bind_completion, handle, token, completion}),
         do: UpstreamTransports.bind_completion(handle, token, completion)
  end

  @impl true
  def handle_cast(:cancel, state), do: settle(%{state | cancelled: true, terminal: true})

  @impl true
  def handle_info(:recover, %{recovery: {kind, token}} = state) do
    case HTTPFetchClient.await_completion(state.completion, true) do
      :ok ->
        send(state.owner, {:recovered, kind, token, self(), :ok})
        {:stop, :normal, state}

      {:error, :cleanup_pending} ->
        if Lifecycle.remaining(state.deadline) > 0 do
          Process.send_after(self(), :recover, 5)
          {:noreply, state}
        else
          send(state.owner, {:recovered, kind, token, self(), {:error, :cleanup_unconfirmed}})
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason} ->
        send(state.owner, {:recovered, kind, token, self(), {:error, reason}})
        {:stop, reason, state}
    end
  end

  def handle_info(:expired, state), do: settle(%{state | cancelled: true, terminal: true})
  def handle_info(:poll, %{terminal: true} = state), do: settle(state)

  def handle_info(:poll, %{client: @h2} = state) do
    {event, request} = ManagedH2Client.poll_headers({state.request, state.submitted_url})
    dispatch(event, %{state | request: request})
  end

  def handle_info(:poll, state) do
    {event, request} = HTTPFetchClient.poll_headers(state.request)
    dispatch(event, %{state | request: request})
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_monitor: ref, recovery: _} = state),
    do: {:stop, :owner_down, state}

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_monitor: ref} = state),
    do: settle(%{state | cancelled: true, terminal: true})

  def handle_info(message, %{client: @h2, request: request} = state) when not is_nil(request) do
    {event, request} = ManagedH2Client.event({request, state.submitted_url}, message)
    dispatch(event, %{state | request: request})
  end

  def handle_info(message, %{request: request} = state) when not is_nil(request) do
    {event, request} = HTTPFetchClient.event(request, message)
    dispatch(event, %{state | request: request})
  end

  def handle_info(_, state), do: {:noreply, state}

  defp dispatch({:headers, status, _}, state) do
    state = clear_submitted_url(state)

    state = %{
      state
      | headers: true,
        outcome: if(status in 200..299, do: :success, else: :failure)
    }

    if state.request.stream == nil do
      settle(%{state | terminal: true})
    else
      selected_client = client(state)
      :ok = selected_client.subscribe(state.request)
      {:noreply, state}
    end
  end

  defp dispatch(:end, state), do: settle(%{state | terminal: true})

  defp dispatch({:chunk, _, _}, state),
    do: settle(%{state | outcome: :failure, cancelled: true, terminal: true})

  defp dispatch({:error, _}, state),
    do: settle(%{state | outcome: :failure, cancelled: true, terminal: true})

  defp dispatch(:none, state) do
    if not state.headers, do: schedule()
    {:noreply, state}
  end

  defp dispatch(_, state), do: {:noreply, state}

  defp settle(state), do: settle_request(clear_submitted_url(state))

  defp settle_request(%{client: @h2, original_request: nil} = state), do: complete(state)

  defp settle_request(%{client: @h2} = state),
    do: cleanup_request(state, state.original_request, ManagedH2Client)

  defp settle_request(%{request: nil} = state), do: complete(state)

  defp settle_request(state) do
    request = if state.managed_transport, do: state.original_request, else: state.request
    cleanup_request(state, request, HTTPFetchClient)
  end

  defp cleanup_request(state, request, client) do
    case client.cleanup(request, state.cancelled) do
      :ok ->
        complete(state)

      {:error, :cleanup_pending} ->
        if Lifecycle.remaining(state.cleanup_deadline) > 0 do
          schedule()
          {:noreply, state}
        else
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason} ->
        {:stop, {:cleanup_failed, reason}, state}
    end
  end

  defp complete(state) do
    Process.cancel_timer(state.timer)

    case finish_transport(state) do
      {:ok, state} ->
        result = with :ok <- account(state, {:control, :probe},
                        {:probe_finished, state.token, state.outcome}),
                      do: UpstreamGroups.probe_finished(state.owner, state.token, state.outcome)

        case result do
          :ok -> {:stop, :normal, state}
          {:error, _} -> {:stop, :owner_unavailable, state}
        end

      {:pending, state} ->
        if Lifecycle.remaining(state.cleanup_deadline) > 0 do
          schedule()
          {:noreply, state}
        else
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason, state} ->
        {:stop, {:cleanup_failed, reason}, state}
    end
  end

  defp finish_transport(%{transport_selection: nil} = state), do: release_transport_pins(state)

  defp finish_transport(%{transport_selection: {handle, token}} = state) do
    result = with :ok <- account_state(state),
                  :ok <- account(state, {:owner_call, :transport, :finish}, {:finish, handle, token}),
                  do: UpstreamTransports.finish(handle, token)

    case result do
      :ok -> release_transport_pins(%{state | transport_selection: nil})
      {:error, :cleanup_pending} -> {:pending, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp release_transport_pins(state) do
    result = with :ok <- account(state, :captured_pins, state.transport_pins),
                  :ok <- account_pin_releases(state, state.transport_pins),
                  do: Resources.release(state.transport_pins)

    case result do
      :ok -> {:ok, %{state | transport_pins: []}}
      {:error, reason} -> {:error, {:pin_release_failed, reason}, state}
    end
  end

  defp account_pin_releases(state, pins) do
    Enum.reduce_while(pins, :ok, fn pin, :ok ->
      case account(state, {:owner_call, :transport, :release}, {:release, pin}) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp client(%{client: @h2}), do: ManagedH2Client
  defp client(_), do: HTTPFetchClient
  defp clear_submitted_url(%{client: @h2} = state), do: %{state | submitted_url: nil}
  defp clear_submitted_url(state), do: state

  defp schedule, do: Process.send_after(self(), :poll, 5)
end
