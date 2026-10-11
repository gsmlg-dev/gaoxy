Application.ensure_all_started(:ssl)
certs = "/probe/probe-fixtures"
{:ok, listener} = :ssl.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, certfile: String.to_charlist(certs <> "/cert.pem"), keyfile: String.to_charlist(certs <> "/key.pem"), verify: :verify_none])
{:ok, {_, port}} = :ssl.sockname(listener)
parent = self()
spawn(fn ->
  {:ok, socket} = :ssl.transport_accept(listener, 5000)
  result = :ssl.handshake(socket, 5000)
  send(parent, {:peer_result, result})
  :ssl.close(socket)
end)
result = :ssl.connect({127, 0, 0, 1}, port, [:binary, active: false, verify: :verify_peer, cacertfile: String.to_charlist(certs <> "/ca.pem"), server_name_indication: ~c"wrong.example", customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]], 5000)
IO.inspect(result, label: "client")
receive do
  {:peer_result, peer} -> IO.inspect(peer, label: "peer")
after
  5000 -> raise "peer did not finish"
end
IO.puts("OTP=" <> File.read!(Path.join([:code.root_dir(), "releases", :erlang.system_info(:otp_release), "OTP_VERSION"])) )
IO.inspect(Application.spec(:ssl, :vsn), label: "SSL")
:ssl.close(listener)
