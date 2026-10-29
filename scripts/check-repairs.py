#!/usr/bin/env python3
"""Run correctness repairs and curated ordinary compatibility with exact counts."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
# Each file is checked separately: losing a case or excluding it fails the gate.
SUITES = {
    'unit': [
        ('apps/gaoxy/test/resource_budget_safety_test.exs', 15),
        ('apps/gaoxy/test/resource_budget_config_test.exs', 14),
        ('apps/gaoxy/test/resource_budget_activation_test.exs', 5),
        ('apps/gaoxy_http/test/resource_budget_config_test.exs', 3),
        ('apps/gaoxy_http3/test/resource_budget_config_test.exs', 3),
        ('apps/gaoxy_proxy/test/resource_budget_config_test.exs', 2),
        ('apps/gaoxy/test/system_memory_test.exs', 35),
        ('apps/gaoxy/test/resource_budget_policy_test.exs', 9),
        ('apps/gaoxy_http/test/plug_response_headers_test.exs', 11),
        ('apps/gaoxy_http/test/http2_codec_test.exs', 5),
        ('apps/gaoxy_http/test/protocol_detector_test.exs', 6),
        ('apps/gaoxy_http/test/http_protocol_defaults_test.exs', 9),
        ('apps/gaoxy_server/test/config_test.exs', 3),
        ('apps/gaoxy_http/test/plug_body_test.exs', 28),
        ('apps/gaoxy_http/test/head_content_length_test.exs', 4),
        ('apps/gaoxy_http/test/http2_authority_test.exs', 8),
        ('apps/gaoxy_proxy/test/cookie_headers_test.exs', 5),
        ('apps/gaoxy/test/config_test.exs', 4),
        ('apps/gaoxy_http/test/http1_parser_test.exs', 9),
        ('apps/gaoxy_http/test/http1_body_test.exs', 6),
        ('apps/gaoxy_proxy/test/http_headers_test.exs', 19),
        ('apps/gaoxy_http/test/managed_proxy_renderer_test.exs', 10),
        ('apps/gaoxy_http/test/http2_worker_accounting_test.exs', 8),
        ('apps/gaoxy_http/test/http2_facade_test.exs', 2),
        ('apps/gaoxy_http3/test/transport_test.exs', 13),
        ('apps/gaoxy_http3/test/operations_test.exs', 18),
        ('apps/gaoxy_http3/test/websocket_test.exs', 9),
        ('apps/gaoxy_http3/test/lifecycle_test.exs', 7),
        ('apps/gaoxy_test/test/expectations_test.exs', 6),
        ('apps/gaoxy/test/backend_options_test.exs', 5),
        ('apps/gaoxy_http/test/backend_options_test.exs', 2),
        ('apps/gaoxy_http3/test/backend_options_test.exs', 1),
        ('apps/gaoxy/test/activation_config_test.exs', 1),
        ('apps/gaoxy_http/test/listener_set_plan_test.exs', 6),
        ('apps/gaoxy_http/test/phoenix_adapter_test.exs', 3),
        ('apps/gaoxy_http/test/gateway_generation_test.exs', 3),
        ('apps/gaoxy_proxy/test/gateway_plan_test.exs', 3),
        ('apps/gaoxy_proxy/test/gateway_config_test.exs', 3),
        ('apps/gaoxy/test/client_certificate_config_test.exs', 4),
        ('apps/gaoxy_http/test/phoenix_client_certificate_config_test.exs', 2),
        ('apps/gaoxy_http/test/websocket_configured_limits_test.exs', 5),
        ('apps/gaoxy_http/test/websocket_incremental_frame_test.exs', 15),
        ('apps/gaoxy_http/test/websocket_lifecycle_config_test.exs', 3),
        ('apps/gaoxy/test/websocket_accounting_test.exs', 4),
        ('apps/gaoxy_http/test/websocket_application_options_test.exs', 2),
        ('apps/gaoxy_http/test/stream_lifetime_config_test.exs', 3),
        ('apps/gaoxy_http/test/stream_lifetime_contract_test.exs', 3),
        ('apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs', 2),
        ('apps/gaoxy_http/test/supervised_shutdown_budget_config_test.exs', 1),
        ('apps/gaoxy_http3/test/supervised_shutdown_budget_test.exs', 2),
        ('apps/gaoxy_test/test/sse_encoding_test.exs', 1),
        ('apps/gaoxy_test/test/server_profile_config_test.exs', 1),
    ],
    'component': [
        ('apps/gaoxy/test/resource_budget_owner_test.exs', 52),
        ('apps/gaoxy/test/system_memory_native_test.exs', 9),
        ('apps/gaoxy/test/quic_context_test.exs', 2),
        ('apps/gaoxy_http/test/exchange_peer_close_test.exs', 7),
        ('apps/gaoxy_http/test/http2_startup_peer_close_test.exs', 8),
        ('apps/gaoxy_http/test/http2_websocket_idle_test.exs', 6),
        ('apps/gaoxy_http/test/websocket_stream_test.exs', 22),
        ('apps/gaoxy_http/test/websocket_event_retention_test.exs', 2),
        ('apps/gaoxy/test/websocket_admission_test.exs', 11),
        ('apps/gaoxy_test/test/core_test.exs', 9),
        ('apps/gaoxy_test/test/lifecycle_test.exs', 12),
        ('apps/gaoxy_test/test/subprocess_test.exs', 8),
        ('apps/gaoxy_test/test/protocol_test.exs', 12),
        ('apps/gaoxy_test/test/helper_test.exs', 16),
        ('apps/gaoxy_test/test/recovery_test.exs', 4),
        ('apps/gaoxy_http/test/stream_lifetime_generation_test.exs', 9),
        ('apps/gaoxy/test/backend_options_runtime_test.exs', 4),
        ('apps/gaoxy_http/test/backend_options_runtime_test.exs', 3),
        ('apps/gaoxy/test/staged_activation_test.exs', 11),
        ('apps/gaoxy_http/test/listener_set_test.exs', 4),
        ('apps/gaoxy_proxy/test/gateway_test.exs', 5),
        ('apps/gaoxy_proxy/test/gateway_lifecycle_test.exs', 10),
        ('apps/gaoxy_http/test/stream_lifetime_test.exs', 9),
        ('apps/gaoxy_http/test/supervised_shutdown_budget_test.exs', 4),
        ('apps/gaoxy/test/certificate_fixture_test.exs', 3),
    ],
    'protocol': [
        ('apps/gaoxy_http/test/plug_response_headers_network_test.exs', 4),
        ('apps/gaoxy_http/test/exchange_peer_close_network_test.exs', 2),
        ('apps/gaoxy_http/test/http2_startup_peer_close_network_test.exs', 1),
        ('apps/gaoxy_http/test/head_content_length_network_test.exs', 2),
        ('apps/gaoxy_http3/test/head_content_length_network_test.exs', 1),
        ('apps/gaoxy_http/test/request_lifetime_network_test.exs', 10),
        ('apps/gaoxy_http/test/mixed_http_network_test.exs', 7),
        ('apps/gaoxy_server/test/mixed_http_routing_test.exs', 1),
        ('apps/gaoxy_server/test/standalone_recovery_test.exs', 2),
        ('apps/gaoxy_http/test/plug_body_network_test.exs', 4),
        ('apps/gaoxy_http/test/poll_boundary_network_test.exs', 6),
        ('apps/gaoxy_http3/test/plug_body_network_test.exs', 1),
        ('apps/gaoxy_http/test/http2_authority_network_test.exs', 1),
        ('apps/gaoxy_proxy/test/cookie_forwarding_network_test.exs', 3),
        ('apps/gaoxy_proxy/test/websocket_protocol_rejection_test.exs', 1),
        ('apps/gaoxy_http3/test/websocket_proxy_rejection_test.exs', 1),
        ('apps/gaoxy_proxy/test/websocket_tls_test.exs', 3),
        ('apps/gaoxy_http/test/http2_websocket_network_test.exs', 4),
        ('apps/gaoxy_http3/test/websocket_network_test.exs', 2),
        ('apps/gaoxy_http/test/mixed_connection_lifecycle_test.exs', 19),
        ('apps/gaoxy_http/test/connection_poll_test.exs', 11),
        ('apps/gaoxy_http/test/native_proxy_seams_test.exs', 21),
        ('apps/gaoxy_http/test/http_protocol_defaults_network_test.exs', 2),
        ('apps/gaoxy_http/test/websocket_configured_limits_network_test.exs', 1),
        ('apps/gaoxy_http/test/websocket_default_capacity_network_test.exs', 5),
        ('apps/gaoxy_http3/test/backend_options_network_test.exs', 4),
        ('apps/gaoxy_http3/test/listener_set_network_test.exs', 8),
        ('apps/gaoxy_server/test/gateway_listener_set_test.exs', 2),
        ('apps/gaoxy_http/test/stream_lifetime_h2_test.exs', 2),
        ('apps/gaoxy/test/runtime_instance_network_test.exs', 1),
        ('apps/gaoxy/test/tls_test.exs', 1),
        ('apps/gaoxy/test/datagram_egress_test.exs', 3),
        ('apps/gaoxy/test/backend_telemetry_test.exs', 1),
    ],
}


def selected_entries(selector):
    selected = SUITES if selector == "all" else {selector: SUITES[selector]}
    seen = set()
    for entries in selected.values():
        for path, expected in entries:
            if path not in seen:
                seen.add(path)
                yield path, expected



def executed(output):
    summaries = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", output)
    modern = re.findall(r"Result:\s+(\d+)(?:/(\d+))? passed([^\n]*)", output)
    if not summaries and not modern:
        raise ValueError("missing ExUnit summary")
    count = 0
    for total, failures, suffix in summaries:
        if int(failures) or re.search(r"[1-9]\d* (?:excluded|skipped)", suffix):
            raise ValueError("failing, excluded or skipped required cases")
        count += int(total)
    for passed, total, suffix in modern:
        if (total and int(passed) != int(total)) or re.search(
                r"[1-9]\d* (?:failures?|failed|excluded|skipped)", suffix):
            raise ValueError("failing, excluded or skipped required cases")
        count += int(passed)
    if count <= 0:
        raise ValueError("zero executed tests")
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=[*SUITES, "all"], nargs="?", default="all")
    args = parser.parse_args()
    env = dict(os.environ, MIX_ENV="test")  # The release parent uses MIX_ENV=prod.
    env.setdefault("GAOXY_QUIC_PYTHON", str(ROOT / ".audit/h2peer/bin/python"))
    total = 0
    print("REPAIR_SOURCE", subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), flush=True)
    for path, expected in selected_entries(args.suite):
        if not (ROOT / path).is_file():
            raise ValueError(f"missing required test file: {path}")
        command = [sys.executable, "scripts/check-tests.py", path, "--seed", "0", "--max-cases", "1"]
        print("REPAIR_COMMAND", " ".join(command), flush=True)
        result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout, end="", flush=True)
        if result.returncode:
            raise ValueError(f"required file failed: {path}, exit {result.returncode}")
        actual = executed(result.stdout)
        if actual != expected:
            raise ValueError(f"required case count changed: {path}, expected {expected}, executed {actual}")
        total += actual
    print(f"REPAIR_PASS {total} executed, 0 failures, 0 excluded, 0 skipped", flush=True)


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        sys.exit(f"REPAIR_FAIL: {error}")
