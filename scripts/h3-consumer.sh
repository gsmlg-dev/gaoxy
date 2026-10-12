#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd "$(dirname "$0")/.." && pwd)
consumer_root=$(mktemp -d)
trap 'rm -rf "$consumer_root"' EXIT
mkdir -p "$consumer_root/apps" "$consumer_root/integration" "$consumer_root/vendor"
cp -R "$project_root/apps/gaoxy" "$project_root/apps/gaoxy_http" \
  "$project_root/apps/gaoxy_http3" "$consumer_root/apps/"
cp -R "$project_root/vendor/websock_adapter" "$consumer_root/vendor/"
cp -R "$project_root/integration/h3_consumer" "$consumer_root/integration/"
cp "$project_root/mix.lock" "$consumer_root/integration/h3_consumer/mix.lock"
bash "$project_root/scripts/generate-fixtures.sh" "$consumer_root/certificates"
export GAOXY_H3_CONSUMER_CERT_DIR="$consumer_root/certificates"
export GAOXY_H3_CONSUMER_PYTHON="${GAOXY_QUIC_PYTHON:-$project_root/integration/quic_consumer/.venv/bin/python}"
cd "$consumer_root/integration/h3_consumer"
export MIX_ENV=test
mix deps.get --check-locked
sha256sum mix.lock
mix compile --warnings-as-errors
python "$project_root/scripts/check-tests.py" test/consumer_test.exs
