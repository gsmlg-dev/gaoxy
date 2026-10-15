#!/usr/bin/env python3
"""Real TLS rotation after an actual managed-group health HEAD and GOAWAY."""
import argparse
import hashlib
from pathlib import Path
import ssl
import sys
import time

from managed_h2_fixed_peer import Commands, Peer


class GroupBrowserPeer(Peer):
    def __init__(self, negative):
        super().__init__('tls', False, 'h2')
        self.negative = negative
        self.rotated = False

    def prepare(self, commands):
        if not super().prepare(commands):
            return False
        self.trust = self.ca
        if self.negative:
            root = Path(__file__).resolve().parents[4]
            source = (root / 'scripts/generate-fixtures.sh').read_text()
            if self.negative == 'wrong-name':
                # The initial identity is valid localhost. The replacement leaf
                # is signed by another explicitly trusted test CA but names
                # wrong.invalid, so localhost fails only the identity check.
                source = source.replace('DNS:localhost', 'DNS:wrong.invalid')
                source = source.replace('CN=localhost', 'CN=wrong.invalid')
                source = source.replace('-verify_hostname localhost', '-verify_hostname wrong.invalid')
            script = Path(self.temp.name) / 'rotation-fixtures.sh'
            script.write_text(source)
            alternate = Path(self.temp.name) / 'alternate'
            result = self.preparation_command(['bash', str(script), str(alternate)],
                                              commands, time.monotonic() + 20)
            if result is None:
                return False
            self.replacement = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.replacement.load_cert_chain(str(alternate / 'cert.pem'), str(alternate / 'key.pem'))
            self.replacement.set_alpn_protocols(['h2'])
            self.replacement.set_servername_callback(
                lambda sock, name, _context: setattr(sock, '_gaoxy_sni', name))
            self.rotation = dict(kind=self.negative,
                initial_certificate_sha256=hashlib.sha256(Path(self.cert).read_bytes()).hexdigest(),
                replacement_certificate_sha256=hashlib.sha256((alternate / 'cert.pem').read_bytes()).hexdigest(),
                replacement_ca_sha256=hashlib.sha256((alternate / 'ca.pem').read_bytes()).hexdigest(),
                replacement_fixture_script_sha256=hashlib.sha256(script.read_bytes()).hexdigest())
            if self.negative == 'wrong-name':
                bundle = Path(self.temp.name) / 'trusted-ca-bundle.pem'
                bundle.write_bytes(Path(self.ca).read_bytes() + (alternate / 'ca.pem').read_bytes())
                self.trust = str(bundle)
        self.identity['group_browser_peer_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        return True

    def start(self):
        super().start()
        self.emit('group_browser_ready', trust=self.trust, negative=self.negative,
                  rotation=None if not self.negative else self.rotation)

    def automatic(self, number, client, stream, target, method):
        if self.negative and not self.rotated and target == '/health' and method == 'HEAD':
            super().command(dict(op='goaway', connection=number, stream=stream,
                                 last_stream=stream, code=0))
        super().automatic(number, client, stream, target, method)

    def command(self, value):
        if value['op'] != 'rotate_tls':
            return super().command(value)
        if not self.negative or self.rotated:
            raise RuntimeError('TLS rotation requires one negative fixture and happens exactly once')
        with self.lock:
            if self.requests != 1 or self.accepts != 1 or len(self.workers) != 1:
                raise RuntimeError('TLS rotation requires exactly one real initial health HEAD connection')
            client = self.clients[1]
            if list(client['targets'].values()) != ['/health'] or not client['eof']:
                raise RuntimeError('TLS rotation requires actual initial HEAD physical EOF after GOAWAY')
            worker = self.workers[0]
        worker.join(2)
        if worker.is_alive():
            raise RuntimeError('initial health connection worker did not join before rotation')
        with self.lock:
            self.context = self.replacement
            self.rotated = True
            self.emit('tls_rotated', initial_connection=1, initial_worker_joined=True,
                      requests_before_rotation=self.requests, **self.rotation)
        return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--negative', choices=('wrong-ca', 'wrong-name'))
    args = parser.parse_args()
    peer = GroupBrowserPeer(args.negative)
    commands = Commands()
    try:
        if peer.prepare(commands):
            peer.start()
            while peer.command(commands.read()):
                pass
    except Exception as error:
        peer.fail(error)
    finally:
        peer.stop()
    return int(peer.failed)


if __name__ == '__main__':
    sys.exit(main())
