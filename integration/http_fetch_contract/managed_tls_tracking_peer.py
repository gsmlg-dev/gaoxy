#!/usr/bin/env python3
"""Owned TLS adapter; historical independent wire/control helpers stay unchanged."""
import argparse
import json
import select
import sys
import time

from managed_peer import ManagedPeer


class TLSTrackingPeer(ManagedPeer):
    def __init__(self, mode):
        self.mode = mode
        self.emitted_lines = 0
        super().__init__("tls")

    def output(self, event):
        with self.lock:
            if event["event"] == "ready":
                if self.mode == "tls_h1":
                    self.context.set_alpn_protocols([])
                    self.protocol = "h1"
                event = dict(event, protocol=self.mode)
            assert self.emitted_lines < 128, "TLS95 emitted-line cap exceeded"
            self.emitted_lines += 1
            super().output(event)

    def serve(self, cid, state):
        try:
            raw = state["socket"]
            raw.settimeout(5)
            wrapped = self.context.wrap_socket(
                raw, server_side=True, do_handshake_on_connect=False)
            state["socket"] = wrapped
            wrapped.do_handshake()
            alpn = wrapped.selected_alpn_protocol()
            assert alpn == (None if self.mode == "tls_h1" else "h2")
            self.record("tls", connection=cid, alpn=alpn)
            wrapped.settimeout(0.1)
            if self.protocol == "h1":
                self.h1(cid, state)
            else:
                self.h2(cid, state)
        except (OSError, EOFError) as error:
            if not self.stopping.is_set() and not state["closed"]:
                self.record("disconnect", connection=cid,
                            reason=type(error).__name__)
        except Exception as error:
            self.record("failure", connection=cid, reason=repr(error))
        finally:
            state["socket"].close()
            state["closed"] = True
            self.record("closed", connection=cid)
            self.wire_drained(state)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", choices=["tls_h1", "tls_h2"], required=True)
    peer = TLSTrackingPeer(parser.parse_args().protocol)
    deadline = time.monotonic() + 45
    try:
        while True:
            remaining = deadline - time.monotonic()
            assert remaining > 0, "TLS95 peer lifetime deadline exceeded"
            ready, _, _ = select.select([sys.stdin], [], [], remaining)
            assert ready, "TLS95 peer control deadline exceeded"
            line = sys.stdin.readline(65537)
            if not line:
                return
            assert len(line) <= 65536 and line.endswith("\n"), "control line bound"
            item = json.loads(line)
            assert item["command"] in [
                "snapshot", "wire_snapshot", "finish_hold", "close", "stop"]
            peer.command(item)
            if item["command"] == "stop":
                return
    finally:
        if not peer.stopping.is_set():
            peer.stop()


if __name__ == "__main__":
    main()
