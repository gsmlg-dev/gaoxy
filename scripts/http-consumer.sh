#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd "$(dirname "$0")/.." && pwd)
consumer_root=$(mktemp -d)
trap 'rm -rf "$consumer_root"' EXIT
mkdir -p "$consumer_root/apps" "$consumer_root/integration" "$consumer_root/vendor"
cp -R "$project_root/apps/gaoxy" "$project_root/apps/gaoxy_http" "$consumer_root/apps/"
cp -R "$project_root/vendor/websock_adapter" "$consumer_root/vendor/"
cp -R "$project_root/integration/http_consumer" "$consumer_root/integration/"
cp "$project_root/mix.lock" "$consumer_root/integration/http_consumer/mix.lock"
cd "$consumer_root/integration/http_consumer"
export MIX_ENV=test
mix deps.get --check-locked
mix compile --warnings-as-errors
mix test --warnings-as-errors
