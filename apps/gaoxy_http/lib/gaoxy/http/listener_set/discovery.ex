defmodule Gaoxy.HTTP.ListenerSet.Discovery do
  @moduledoc false
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.Lifecycle

  # Renderers invoke this before their ordinary header/accounting checks. A
  # failed observation suppresses advertisement; no stale event can enable it.
  def headers(%{discovery: nil}, _, headers), do: headers

  def headers(exchange, status, headers) when is_list(headers) and status in 200..599 do
    if Exchange.secure?(exchange) and
         exchange.request.version in [:"HTTP/1.0", :"HTTP/1.1", :"HTTP/2"] and
         not (exchange.request.method == "CONNECT" and exchange.request.protocol != nil) do
      managed =
        Enum.reject(headers, fn
          {name, _} when is_binary(name) -> String.downcase(name) == "alt-svc"
          _ -> false
        end)

      case observe(exchange) do
        {:ok, port, age} -> [{"alt-svc", "h3=\":#{port}\"; ma=#{age}"} | managed]
        _ -> managed
      end
    else
      headers
    end
  end

  def headers(_, _, headers), do: headers

  defp observe(%{discovery: context, deadline: deadline}) do
    timeout = min(50, Lifecycle.remaining(deadline))

    if timeout > 0 do
      Lifecycle.bounded(
        fn ->
          with true <- context.guard == nil or context.guard.() == true,
               {:ok, %{status: :committed}} <-
                 Gaoxy.activation_status(context.instance, context.activation_id),
               true <-
                 Enum.all?(context.service_ids, fn id ->
                   match?(
                     %{mode: :ready, local: {:ok, {_, port}}} when port > 0,
                     Gaoxy.info(context.instance, id)
                   )
                 end),
               %{mode: :ready, local: {:ok, {_, bound}}} <-
                 Gaoxy.info(context.instance, context.h3_id),
               port = if(context.policy.port == :bound, do: bound, else: context.policy.port),
               do: {:ok, port, context.policy.max_age}
        end,
        timeout
      )
    else
      {:error, :deadline_exceeded}
    end
  catch
    _, _ -> {:error, :unavailable}
  end
end
