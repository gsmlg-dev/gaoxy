# H2 default concurrency implementation

1. Run the focused existing capacity/codec baseline.
2. Add a real TLS/ALPN regression with two independent live H2 connections,
   overlapping ordinary requests, and the unchanged default 256 MiB budget;
   observe the second connection failing before the fix.
3. Split startup and maximum decode reservations. Before decompression, grow
   the connection lease to its compressed-block decode high-water requirement.
   Preserve startup worst-case budget validation and the HPACK expansion bound.
4. Test refused growth before decode, subsequent reuse and cleanup, and run
   the relevant H2 ordinary regression suite with nonzero executed counts.
5. Record fresh results and hand the diff to independent review. No publication.
