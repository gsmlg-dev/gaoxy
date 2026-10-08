#!/usr/bin/env bash
set -euo pipefail
fixture_dir=${1:?fixture output directory required}
mkdir -p "$fixture_dir"
umask 077
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -sha256 \
  -subj '/CN=Gaoxy test CA' -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$fixture_dir/ca-key.pem" -out "$fixture_dir/ca.pem" 2>/dev/null
openssl req -new -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' \
  -keyout "$fixture_dir/key.pem" -out "$fixture_dir/request.pem" 2>/dev/null
cat > "$fixture_dir/extensions" <<'EOF'
subjectAltName=DNS:localhost,IP:127.0.0.1
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF
openssl x509 -req -in "$fixture_dir/request.pem" -CA "$fixture_dir/ca.pem" \
  -CAkey "$fixture_dir/ca-key.pem" -CAcreateserial -days 2 -sha256 \
  -extfile "$fixture_dir/extensions" -out "$fixture_dir/cert.pem" 2>/dev/null
openssl verify -CAfile "$fixture_dir/ca.pem" "$fixture_dir/cert.pem"
