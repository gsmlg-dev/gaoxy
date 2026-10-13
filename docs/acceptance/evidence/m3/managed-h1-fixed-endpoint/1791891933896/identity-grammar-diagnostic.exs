origins = [
          "",
          "ftp://example.test",
          "http://",
          "http://example.test:0",
          "http://example.test:65536",
          "http://example.test:abc",
          "http://user:password@example.test",
          "http://example.test/path",
          "http://example.test/?",
          "http://example.test/?q=1",
          "http://example.test/#",
          "http://example.test/#fragment",
          "http://example.test/\\path",
          "http://example.test/\r\n",
          "http://example.test/%GG",
          "http://" <> String.duplicate("a", 254),
          <<"http://example.test/", 255>>
]

for origin <- origins do
  uri = URI.parse(origin)
  accepted = uri.scheme in ["http", "https"] and is_binary(uri.host) and byte_size(uri.host) in 1..253 and is_integer(uri.port) and uri.port in 1..65_535 and uri.path in [nil, "", "/"] and uri.query == nil and uri.fragment == nil and uri.userinfo == nil
  if accepted, do: IO.inspect({origin, uri}, label: "URI structural acceptance")
end
