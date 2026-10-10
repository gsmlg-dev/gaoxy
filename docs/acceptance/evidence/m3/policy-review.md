# Independent destination policy specification and quality review

Reviewer `/root/upstream_cleanup`; read-only source review, no policy edits or build commands. Checkout `22b76e8051ddaf09e36797cb781b9b119870a9d4` plus parent-owned task diff. Reviewed approved destination-policy design, DestinationPolicy source and its6tests. This is the pure policy slice, not forward/CONNECT/dial acceptance.

Verdict: FINDING requiring a focused regression and default-denial fix before security acceptance.

## DP1 — deprecated IPv6 site-local private addresses are allowed by broad public rules (high)

The reserved list covers `fc00::/7` and `fe80::/10` but omits `fec0::/10` (deprecated site-local addressing, still meaningful on existing private networks). A policy rule with `cidrs: ["::/0"]`, `allow_reserved: false` and otherwise matching principal/host/port authorizes `{0xFEC0,0,0,0,0,0,0,1}` because it matches no @reserved entry. This defeats the default-deny-private boundary. Deny site-local by default and permit only an explicit narrow reserved exception, consistent with the existing IPv6/64-or-narrower rule. Add standalone and mixed-public-answer pin regressions.

## Positive checks

- Authentication requires exactly one bounded Proxy-Authorization credential and suppresses callback exceptions/credential material in errors.
- Principal, canonical host, port, operation and method match before resolution; unknown fields/empty rules are rejected.
- IPv4-mapped IPv6 normalizes before pin filtering; malformed tuple words and zone-qualified hosts reject.
- Every successfully resolved candidate is validated; mixed allowed/denied answer lists fail closed.
- CIDR/host/principal lists and prepared policy payloads have finite bounds; reserved opt-in requires narrow CIDRs.
- Configured deny_cidrs wins even over explicit reserved exceptions by code inspection.
- Numeric destination resolution is revalidated against the exact policy; DNS lookup uses one absolute remaining deadline for both families and yields a pinned numeric dial candidate.

## Verification limits

Parent has reported the original6expectedred tests. This review does not claim a green test run. Add deny_cidrs precedence coverage (currently source-only) and execute fresh scoped policy tests after DP1 repair. End-to-end authorization before dial, pinned connect_address/SNI identity, resolver/network behaviors and application credential stripping remain integration gates.
