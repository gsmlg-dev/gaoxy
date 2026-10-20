# H2 default connection concurrency

The 256 MiB default service budget currently reserves 173,039,655 bytes for
every H2 connection, including the expansion of a maximum-sized HPACK block
that an ordinary connection may never receive. A second connection is rejected
even when both exchange only small requests.

Keep the default service and protocol limits. Charge the existing transport,
parser, and connection-state reserve at connection startup. Before calling
`HPAX.decode/2`, grow that same connection lease to cover the largest compressed
header block actually received so far. Retain this decode high-water reservation
until the connection exits. A denied increase closes the connection with
`ENHANCE_YOUR_CALM` before decompression.

HPAX accumulates every decoded field before Gaoxy validates the header count and
bytes. Indexed fields may repeat a dynamic-table entry once per compressed byte;
literal strings may use HPACK Huffman expansion. Therefore retain the existing
conservative formula `2*b*(max(table_size,128)+2) + 512*b + 2*table_size`, using
the actual compressed block size `b`. The table-size and compressed-block limits
remain enforced. Startup validation still requires sufficient budget for one
maximum-sized block, writer, and stream. No dependency changes or reduced
accounting bounds are needed. Keeping each high-water reservation avoids an
accounting gap while decoded garbage awaits collection or an admitted request
is transferred to its separately charged worker.

Acceptance: two independent TLS clients negotiate H2 using the default HTTPS
protocol selection and default byte budget. Their requests overlap, both return
200, both connections remain usable, and closing both releases all admission
resources. Focused tests also cover pre-decode growth denial and preservation
of the existing worst-case HPACK expansion bound. This ordinary regression does
not revive the excluded pressure, slow-peer, or sustained-load qualification.
