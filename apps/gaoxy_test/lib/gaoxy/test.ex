defmodule Gaoxy.Test do
  @moduledoc """
  Isolated real HTTP fixtures with atomic request expectations.

  `open/1` defaults to automatic per-test ExUnit verification. Use it in a test
  body or per-test setup, never `setup_all`. Shared fixtures must use explicit
  `mode: :manual` ownership and verification. This module never starts ExUnit.

  Callbacks are unary Plug functions. Bodies remain lazy; `capture_body: bytes`
  records at most that many bytes as the callback reads, without consuming the
  body ahead of it. Journal eviction never removes verification accounting.

  `close/2` retains its report for `:retention` milliseconds (default 60 seconds).
  Automatic on-exit verification consumes that report; expired handles fail.
  """
  alias Gaoxy.Test.{Expectations, Handle, Instance}

  @defaults [
    mode: :auto,
    profile: :http1,
    timeout: 5_000,
    retention: 60_000,
    journal_limit: 100,
    capture_body: false
  ]

  def open(options \\ []) do
    options = validate_options(options)

    case Application.ensure_all_started(:gaoxy_test) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        raise Gaoxy.Test.SetupError,
          message: "fixture application startup failed: #{inspect(reason)}"
    end

    fixture_id = make_ref()

    case DynamicSupervisor.start_child(
           Gaoxy.Test.Supervisor,
           {Instance, {self(), fixture_id, options}}
         ) do
      {:ok, pid} ->
        handle = %Handle{pid: pid, id: fixture_id, timeout: options[:timeout]}

        try do
          if options[:mode] == :auto, do: Gaoxy.Test.ExUnit.register(handle)
          handle
        catch
          kind, reason ->
            stacktrace = __STACKTRACE__
            Instance.call(handle, {:close, handle.timeout, true}, handle.timeout + 1_000)
            :erlang.raise(kind, reason, stacktrace)
        end

      {:error, reason} ->
        raise Gaoxy.Test.SetupError, message: "fixture startup failed: #{inspect(reason)}"
    end
  end

  def url(server, path \\ "/") do
    if not is_binary(path) or not String.starts_with?(path, "/"),
      do: raise(ArgumentError, "URL path must start with /")

    String.trim_trailing(info(server).url, "/") <> path
  end

  def info(server), do: Instance.call(server, :info)

  def expect(server, method, path, handler, options \\ []) do
    unless Keyword.keyword?(options) and Keyword.keys(options) -- [:times] == [],
      do: raise(ArgumentError, "expect options accept only :times")

    requirement =
      if Keyword.has_key?(options, :times), do: {:exact, options[:times]}, else: :at_least_one

    register(server, method, path, handler, requirement)
  end

  def expect_once(server, method, path, handler),
    do: expect(server, method, path, handler, times: 1)

  def stub(server, method, path, handler), do: register(server, method, path, handler, :stub)
  def requests(server), do: Instance.call(server, :requests)

  def await_request(server, matcher, timeout \\ 5_000) do
    timeout = positive!(timeout, :timeout)

    unless is_map(matcher) and Map.keys(matcher) -- [:method, :path, :after] == [],
      do: raise(ArgumentError, "await matcher accepts :method, :path and :after")

    method = Expectations.normalize_method(Map.fetch!(matcher, :method))
    path = Expectations.normalize_path(Map.fetch!(matcher, :path))
    cursor = Map.get(matcher, :after, 0)

    unless is_integer(cursor) and cursor >= 0,
      do: raise(ArgumentError, "after must be a nonnegative cursor")

    Instance.call(
      server,
      {:await, %{method: method, path: path, after: cursor}, timeout},
      timeout + 1_000
    )
  end

  def verify!(server, options \\ []) do
    timeout = operation_timeout(server, options)
    server |> Instance.call({:verify, timeout}, timeout + 1_000) |> assert_report!()
  end

  def verify_and_close!(server, options \\ []), do: server |> close(options) |> assert_report!()

  def close(server, options \\ []) do
    timeout = operation_timeout(server, options)
    Instance.call(server, {:close, timeout, false}, timeout + 1_000)
  end

  @doc false
  def assert_report!(%{status: :ok}), do: :ok

  def assert_report!(%{
        failures: [%{type: :callback, kind: kind, reason: reason, stacktrace: stacktrace}]
      }) do
    :erlang.raise(kind, reason, stacktrace)
  end

  def assert_report!(report) do
    failures = Enum.map_join(report.failures, "\n", &format_failure/1)

    raise Gaoxy.Test.VerificationError,
      message: "Gaoxy.Test verification failed:\n" <> failures,
      report: report
  end

  defp register(server, method, path, handler, requirement) do
    method = Expectations.normalize_method(method)
    path = Expectations.normalize_path(path)

    case Instance.call(server, {:register, method, path, handler, requirement}) do
      :ok -> :ok
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp validate_options(options) do
    unless Keyword.keyword?(options), do: raise(ArgumentError, "options must be a keyword list")
    unknown = Keyword.keys(options) -- Keyword.keys(@defaults)
    if unknown != [], do: raise(ArgumentError, "unknown fixture options: #{inspect(unknown)}")
    options = Keyword.merge(@defaults, options)

    unless options[:mode] in [:auto, :manual],
      do: raise(ArgumentError, "mode must be :auto or :manual")

    unless options[:profile] in [:http1, :https, :h2c, :http2, :http3],
      do: raise(ArgumentError, "unsupported fixture profile")

    for key <- [:timeout, :retention, :journal_limit], do: positive!(options[key], key)
    unless options[:capture_body] == false, do: positive!(options[:capture_body], :capture_body)
    options
  end

  defp operation_timeout(%Handle{timeout: default}, options) do
    unless Keyword.keyword?(options) and Keyword.keys(options) -- [:timeout] == [],
      do: raise(ArgumentError, "operation options accept only :timeout")

    positive!(Keyword.get(options, :timeout, default), :timeout)
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value

  defp positive!(_value, name),
    do: raise(ArgumentError, "#{name} must be a finite positive integer")

  defp format_failure(%{route: {method, path}} = failure),
    do: "#{method} #{path}: #{inspect(Map.delete(failure, :route))}"

  defp format_failure(failure), do: inspect(failure)
end
