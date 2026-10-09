#!/usr/bin/env bash
set -euo pipefail
fixture_dir=${1:?fixture output directory required}

# Resolve once. OPENSSL_BIN is one executable path, never shell code.
openssl_bin=${OPENSSL_BIN:-openssl}
if ! openssl_bin=$(command -v "$openssl_bin") || [[ ! -x "$openssl_bin" ]]; then
  echo "OPENSSL_BIN must select an available executable: ${OPENSSL_BIN:-openssl}" >&2
  exit 1
fi
version=$("$openssl_bin" version)
if [[ "$version" != 'OpenSSL 3.'* ]]; then
  echo "OPENSSL_BIN requires OpenSSL 3.x; selected $openssl_bin: $version" >&2
  exit 1
fi
printf 'Certificate tool: %s; %s\n' "$openssl_bin" "$version"

umask 077
mkdir -p "$fixture_dir"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gaoxy-certificates.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
step=configuration
trap 'echo "Certificate fixture failed during $step ($openssl_bin; $version)" >&2' ERR

# Every certificate profile is supplied here; machine OpenSSL configuration
# cannot add extensions, change defaults, or redirect a serial file.
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
CONFIG
export OPENSSL_CONF="$work_dir/openssl.cnf"

step=CA-generation
"$openssl_bin" req -x509 -newkey rsa:2048 -nodes -days 2 -sha256 \
  -config "$OPENSSL_CONF" -extensions ca -subj '/CN=Gaoxy test CA' \
  -keyout "$work_dir/ca-key.pem" -out "$work_dir/ca.pem"
step=server-request
"$openssl_bin" req -new -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' \
  -config "$OPENSSL_CONF" -keyout "$work_dir/key.pem" -out "$work_dir/request.pem"
step=server-signing
"$openssl_bin" x509 -req -in "$work_dir/request.pem" -CA "$work_dir/ca.pem" \
  -CAkey "$work_dir/ca-key.pem" -CAserial "$work_dir/ca.srl" -CAcreateserial \
  -days 2 -sha256 -extfile "$OPENSSL_CONF" -extensions server -out "$work_dir/cert.pem"
step=server-purpose-and-DNS-verification
"$openssl_bin" verify -x509_strict -purpose sslserver -verify_hostname localhost \
  -CAfile "$work_dir/ca.pem" "$work_dir/cert.pem"
step=server-purpose-and-IP-verification
"$openssl_bin" verify -x509_strict -purpose sslserver -verify_ip 127.0.0.1 \
  -CAfile "$work_dir/ca.pem" "$work_dir/cert.pem"
step=fixture-output
# Only the leaf private key and public chain survive; caller owns its directory.
cp "$work_dir/ca.pem" "$work_dir/cert.pem" "$work_dir/key.pem" "$fixture_dir/"
chmod 600 "$fixture_dir/ca.pem" "$fixture_dir/cert.pem" "$fixture_dir/key.pem"
