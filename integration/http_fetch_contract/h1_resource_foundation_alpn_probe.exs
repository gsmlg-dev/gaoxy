# Parent-owned public API diagnostic. No sockets or requests are opened.
{:ok, _} = Application.ensure_all_started(:http_fetch)

fixture =
  Path.join(
    System.tmp_dir!(),
    "gaoxy-h1-alpn-" <> Integer.to_string(System.unique_integer([:positive]))
  )

:ok = File.mkdir!(fixture)

try do
  {output, 0} =
    System.cmd("bash", ["scripts/generate-fixtures.sh", fixture], stderr_to_stdout: true)

  IO.puts(output)

  [{:Certificate, der, :not_encrypted}] =
    :public_key.pem_decode(File.read!(Path.join(fixture, "ca.pem")))

  ssl = [
    verify: :verify_peer,
    depth: 4,
    versions: [:"tlsv1.3", :"tlsv1.2"],
    cacerts: [der],
    server_name_indication: ~c"localhost"
  ]

  options = [
    origin: "https://localhost:443",
    connect_address: {127, 0, 0, 1},
    http_version: :http1,
    tls_backend: :ssl,
    http2_profile: :native_v1,
    max_requests: 32,
    max_connections: 2,
    max_pending: 0,
    idle_timeout: 30_000
  ]

  for {name, tls} <- [
        {:baseline, ssl},
        {:fixed_h1_alpn, ssl ++ [alpn_advertised_protocols: ["http/1.1"]]}
      ] do
    case HTTP.ManagedTransport.open(options ++ [ssl: tls]) do
      {:ok, scope} ->
        IO.inspect({name, :opened})
        {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
        :ok = HTTP.ManagedTransport.await_retired(receipt, 5_000)
        IO.inspect({name, :retired, :ok})

      {:error, reason} ->
        IO.inspect({name, :rejected, reason})
    end
  end

  IO.inspect({:public_api_diagnostic, :executed, 2})
after
  {:ok, _} = File.rm_rf(fixture)
  false = File.exists?(fixture)
  IO.inspect({:temporary_certificates, :removed})
end
