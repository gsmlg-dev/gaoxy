Task h2_identity_close_notification_seams1 — DONE_PUBLIC_SOURCE_INVESTIGATION.

Matching Chromium revision506c834ecceaa943c5f41e6cfe7f68acb5c45346 has two useful real zero-parameter events omitted by current wrapper: CERTIFICATE_DATABASE_TRUST_STORE_CHANGED and CERTIFICATE_DATABASE_CLIENT_CERT_STORE_CHANGED. event_type_list.h3750-3753 declares them; cert_database.cc37-58 emits before observer notifications. Trust-store observer maps to kCertDatabaseChanged then pool MakeCurrentSessionsGoingAway(ERR_CERT_DATABASE_CHANGED). Client-cert change maps only cached matching servers, and returns when no cached servers exist. Event timing witnesses notification class, not guaranteed exact target-session causality.

Existing NETWORK_IP_ADDRESSES_CHANGED / NETWORK_CONNECTIVITY_CHANGED / NETWORK_CHANGED are real. IP event logs no change_type. Connectivity/network new_connection_type is a string from ConnectionTypeToString, not integer. Names/time/numeric source fields suffice without exposing addresses or arbitrary strings. No dedicated SSL_CONFIG_CHANGED or CERT_VERIFIER_CHANGED NetLog event was found in reviewed definitions/callbacks: SSLClientContext directly notifies observers; verifier REQUEST/JOB/TASK is not change evidence. Per-server client-cert cache events exist but contain host/cert material; they are not needed for the minimal expansion.

Pool MakeCurrentSessionsGoingAway stores no initiating-error NetLog event; POOL_REMOVE_SESSION is parameterless removal evidence. FINISHED_GOING_AWAY can therefore lose the original notification reason. No safe extra integer in these callback paths restores it. GOAWAY numeric fields are wire-frame evidence only. Global event adjacency/absence in an incomplete projection cannot establish or exclude exact cause.

Minimal optional root proposal: add only the two certificate-database event names to allowlist, retain current safe metadata/param filter, and independently review frozen changed wrapper bytes. Do not emit certificate/host/address/description material or invented callback enums. No wrapper was changed here; original UNKNOWN/FAIL and every acceptance boundary remain.

Five successful complete public response bodies were hashed (only excerpts/hashes retained, no downloaded file written):
net/log/net_log_event_type_list.h SHA256 0ddf9cccfbc9868a7dc26044c493abb4c3f09e0c86e303724ac6e62ac891b1b7 (196817bytes).
net/spdy/spdy_session_pool.cc SHA256 8798fe4d882c55465977b1d727d104540e1140b7d44f75e97373a5c0c0c7bcbf (41137bytes).
net/socket/ssl_client_socket.cc SHA256 68b79c7417deddb2f2cc2ff00aeb1dbf742f39f87367b52d9f9685b3b1c88eba (14849bytes).
net/base/logging_network_change_observer.cc SHA256 ea344a30d14326b7a25403a122b64a741990b1eff49d187f19d00a7d4b5bd02b (5360bytes).
net/cert/cert_database.cc SHA256 ad23fabc63f4dd04408679f4bdfcd664434e71fc24f5b0be911c0e1888e8f72e (2132bytes).

Full origins/line references/source matrix in JSON. One initial guessed public observer path returned404; empty digest is excluded and actual net/base/logging_network_change_observer.cc was located successfully. Only two assigned /tmp reports written.0runtime/import/tests/build/browser/Git/repo writes or protected reads. All commands finished; Sol5/Astra2of2 unchanged. No product decision needed; root owns any change/execution.
