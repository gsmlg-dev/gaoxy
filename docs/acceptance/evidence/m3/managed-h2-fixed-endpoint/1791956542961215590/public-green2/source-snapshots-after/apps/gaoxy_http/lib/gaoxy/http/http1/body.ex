defmodule Gaoxy.HTTP.HTTP1.Body do
  @moduledoc "Incremental request-body decoder. Each read emits at most the caller's byte credit."
  alias Gaoxy.HTTP.HTTP1.Parser
  defstruct phase: :done, total: 0, trailers: [], trailer_bytes: 0, limits: %{}

  @defaults %{
    max_body_bytes: 8_388_608,
    max_chunk_line: 1_024,
    max_trailer_bytes: 8_192,
    max_trailers: 32
  }
  @forbidden ~w(content-length transfer-encoding host connection trailer te upgrade
                authorization proxy-authorization content-encoding content-type content-range expect)
  @extensions ~r/\A(?:[ \t]*;[ \t]*[!#$%&'*+.^_`|~0-9A-Za-z-]+(?:[ \t]*=[ \t]*(?:[!#$%&'*+.^_`|~0-9A-Za-z-]+|"(?:[\x20-\x21\x23-\x5B\x5D-\x7E]|\\[\x20-\x7E])*"))?)*\z/

  def new(framing, options \\ %{}) do
    phase =
      case framing do
        :none -> :done
        {:length, 0} -> :done
        {:length, length} -> {:length, length}
        :chunked -> :chunk_size
      end

    %__MODULE__{phase: phase, limits: Map.merge(@defaults, options)}
  end

  def read(%__MODULE__{} = body, bytes, credit) when is_binary(bytes) and credit > 0 do
    consume(body, bytes, credit, [])
  end

  defp consume(%{phase: :done} = body, bytes, _credit, acc),
    do: result(:ok, body, bytes, acc)

  defp consume(%{phase: {kind, remaining}} = body, bytes, credit, acc)
       when kind in [:length, :chunk_data] do
    count = min(remaining, min(byte_size(bytes), credit))
    <<data::binary-size(^count), rest::binary>> = bytes
    total = body.total + count

    cond do
      total > body.limits.max_body_bytes ->
        {:error, 413, :body_limit}

      count == 0 ->
        result(:more, body, bytes, acc)

      count == remaining ->
        phase = if kind == :length, do: :done, else: :chunk_crlf
        consume(%{body | phase: phase, total: total}, rest, credit - count, [data | acc])

      true ->
        result(:more, %{body | phase: {kind, remaining - count}, total: total}, rest, [data | acc])
    end
  end

  defp consume(%{phase: :chunk_crlf} = body, bytes, credit, acc) do
    case bytes do
      "\r\n" <> rest -> consume(%{body | phase: :chunk_size}, rest, credit, acc)
      "" -> result(:more, body, bytes, acc)
      "\r" -> result(:more, body, bytes, acc)
      _ -> {:error, 400, :chunk_delimiter}
    end
  end

  defp consume(%{phase: :chunk_size} = body, bytes, credit, acc) do
    case line(bytes, body.limits.max_chunk_line, 400, :chunk_line_limit) do
      {:ok, line, rest} ->
        with {:ok, size} <- chunk_size(line),
             true <- body.total + size <= body.limits.max_body_bytes || {:error, 413, :body_limit} do
          phase = if size == 0, do: :trailers, else: {:chunk_data, size}
          consume(%{body | phase: phase}, rest, credit, acc)
        end

      :more ->
        result(:more, body, bytes, acc)

      error ->
        error
    end
  end

  defp consume(%{phase: :trailers} = body, bytes, credit, acc) do
    remaining = body.limits.max_trailer_bytes - body.trailer_bytes

    case line(bytes, remaining, 431, :trailer_bytes_limit) do
      {:ok, "", rest} ->
        consume(%{body | phase: :done, trailers: Enum.reverse(body.trailers)}, rest, credit, acc)

      {:ok, line, rest} ->
        with true <-
               length(body.trailers) < body.limits.max_trailers ||
                 {:error, 431, :trailer_count_limit},
             {:ok, [{name, _value} = field]} <- Parser.parse_fields([line]),
             true <- name not in @forbidden || {:error, 400, :forbidden_trailer} do
          body = %{
            body
            | trailers: [field | body.trailers],
              trailer_bytes: body.trailer_bytes + byte_size(line) + 2
          }

          consume(body, rest, credit, acc)
        end

      :more ->
        result(:more, body, bytes, acc)

      error ->
        error
    end
  end

  defp chunk_size(line) do
    [size | extension] = :binary.split(line, ";")
    suffix = if extension == [], do: "", else: ";" <> hd(extension)

    if byte_size(size) <= 16 and Regex.match?(~r/\A[0-9A-Fa-f]+\z/, size) and
         Regex.match?(@extensions, suffix) do
      {number, ""} = Integer.parse(size, 16)
      {:ok, number}
    else
      {:error, 400, :chunk_size}
    end
  end

  defp line(bytes, limit, status, reason) do
    case :binary.match(bytes, "\r\n") do
      {length, 2} when length + 2 <= limit ->
        <<line::binary-size(length), _::binary-size(2), rest::binary>> = bytes

        if Regex.match?(~r/[\r\n]/, line),
          do: {:error, 400, :line_ending},
          else: {:ok, line, rest}

      {_, 2} ->
        {:error, status, reason}

      :nomatch ->
        cond do
          byte_size(bytes) > limit -> {:error, status, reason}
          Regex.match?(~r/(?<!\r)\n|\r[^\n]/, bytes) -> {:error, 400, :line_ending}
          true -> :more
        end
    end
  end

  defp result(status, body, rest, acc),
    do: {status, IO.iodata_to_binary(Enum.reverse(acc)), body, :binary.copy(rest)}
end
