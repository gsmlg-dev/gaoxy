# Internal request #6: configured WebSocket message capacity

An omitted `max_message_size` follows `max_frame_size`, including its unchanged
262,144-byte default. An explicitly supplied message limit remains authoritative.
Phoenix already forwards its accepted `max_frame_size` transport option, so no new
Phoenix option or dependency is needed. The existing startup clamp of both limits
to one quarter of the service `max_bytes` budget remains authoritative.

The wire parser continues to bound each frame and the message assembler continues
to count the total payload across fragments. A larger configured frame therefore
permits the intended message capacity without removing either resource boundary.

Acceptance uses a real Phoenix Endpoint and channel over loopback TCP, with
unfragmented and fragmented messages above 256 KiB, oversized frame and aggregate
rejection, the unchanged default, and the service-budget clamp. Direct WebSock
users retain explicit lower message limits.
