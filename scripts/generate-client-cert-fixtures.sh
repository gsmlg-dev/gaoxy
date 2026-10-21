#!/usr/bin/env bash
set -euo pipefail
fixture_dir=${1:?fixture output directory required}
openssl_bin=${OPENSSL_BIN:-openssl}
openssl_bin=$(command -v "$openssl_bin")
version=$("$openssl_bin" version)
[[ "$version" == 'OpenSSL 3.'* ]] || { echo 'OpenSSL 3.x required' >&2; exit 1; }
umask 077
mkdir -p "$fixture_dir"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gaoxy-client-certs.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
cat > "$work_dir/openssl.cnf" <<'CONFIG'
[req]
distinguished_name=subject
prompt=no
[subject]
CN=localhost
[ca]
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
[server]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
subjectAltName=DNS:localhost,IP:127.0.0.1
[client]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
CONFIG
export OPENSSL_CONF="$work_dir/openssl.cnf"
for authority in ca wrong-ca; do
  "$openssl_bin" req -x509 -newkey rsa:2048 -nodes -days 2 -sha256 \
    -config "$OPENSSL_CONF" -extensions ca -subj '/CN=Gaoxy client test CA' \
    -keyout "$work_dir/$authority-key.pem" -out "$work_dir/$authority.pem" 2>/dev/null
done
for profile in server client wrong-client; do
  authority=ca
  extension=client
  [[ "$profile" != server ]] || extension=server
  [[ "$profile" != wrong-client ]] || authority=wrong-ca
  "$openssl_bin" req -new -newkey rsa:2048 -nodes -sha256 -subj "/CN=$profile" \
    -config "$OPENSSL_CONF" -keyout "$fixture_dir/$profile-key.pem" \
    -out "$work_dir/$profile.csr" 2>/dev/null
  "$openssl_bin" x509 -req -in "$work_dir/$profile.csr" -CA "$work_dir/$authority.pem" \
    -CAkey "$work_dir/$authority-key.pem" -CAserial "$work_dir/$authority.srl" -CAcreateserial \
    -days 2 -sha256 -extfile "$OPENSSL_CONF" -extensions "$extension" \
    -out "$fixture_dir/$profile.pem" 2>/dev/null
done
cp "$work_dir/ca.pem" "$fixture_dir/ca.pem"
"$openssl_bin" verify -x509_strict -purpose sslserver -verify_hostname localhost \
  -CAfile "$fixture_dir/ca.pem" "$fixture_dir/server.pem"
"$openssl_bin" verify -x509_strict -purpose sslclient \
  -CAfile "$fixture_dir/ca.pem" "$fixture_dir/client.pem"
