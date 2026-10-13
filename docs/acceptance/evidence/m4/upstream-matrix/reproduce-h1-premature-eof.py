"""Real loopback premature-EOF specimens for UP2-C1; separate from UP2 rows."""
import asyncio
import hashlib
import importlib.util
import json
import pathlib
import sys
import time

source = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('up2_h1_parser_probe', source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
output = pathlib.Path(sys.argv[2])
head = b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n'
progress = b'9\r\nprogress-\r\n'
specimens = {
    'eof_before_chunk_size': head + progress,
    'eof_in_chunk_size': head + progress + b'F',
    'eof_in_trailers': head + progress + b'0\r\nx-check: one\r\n',
}


async def check(name, wire):
    async def serve(reader, writer):
        await reader.readuntil(b'\r\n\r\n')
        writer.write(wire)
        await writer.drain()
        writer.close()
        await writer.wait_closed()

    server = await asyncio.start_server(serve, '127.0.0.1', 0)
    port = server.sockets[0].getsockname()[1]
    reader, writer = await asyncio.open_connection('127.0.0.1', port)
    peer = module.H1(reader, writer)
    row = dict(name=name, wire_sha256=hashlib.sha256(wire).hexdigest(), port=port, status='FAIL')
    try:
        sid = await peer.request(b'GET', b'/partial', [], fin=True)
        response = await asyncio.wait_for(peer.done(sid), 1)
        assert response['closed'] and not response['ended'], module.diagnostic(response)
        assert bytes(response['body']) == b'progress-', module.diagnostic(response)
        row['status'] = 'PASS'
        row['observed'] = module.diagnostic(response)
    except BaseException as error:
        row['error'] = repr(error)
        row['observed'] = module.diagnostic(peer.responses[0])
    finally:
        await peer.close()
        server.close()
        await server.wait_closed()
    return row


async def main():
    rows = [await check(name, wire) for name, wire in specimens.items()]
    report = dict(status='PASS' if all(row['status'] == 'PASS' for row in rows) else 'FAIL',
                  kind='H1_PREMATURE_EOF_PARSER_REGRESSION', command=sys.argv,
                  source=str(source), source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  executed=3, failures=sum(row['status'] == 'FAIL' for row in rows), rows=rows,
                  scope='Actual loopback TCP/parser specimens; separate from 66 TLS/H2/H3 production UP2 rows.')
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return 0 if report['status'] == 'PASS' else 1


sys.exit(asyncio.run(main()))
