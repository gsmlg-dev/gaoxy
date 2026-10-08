# ADR 003: Explicit providers and dependency isolation

OTP `:ssl` is the TCP TLS foundation/reference provider. Custom `SSL` server
selection stays unsupported until its public server contract passes; no fallback
is allowed. QUIC has its own TLS integration. Core depends on ordinary transport
hosts and telemetry, with no Plug/Phoenix/Bandit/HTTP Fetch/QUIC engine activation.
Future optional engines may use a thin integration package if their manifests
otherwise force optional dependencies into external ordinary consumers.
