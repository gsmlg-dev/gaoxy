"""Separately authorized official acquisition; never constructs the baseline."""
from pathlib import Path
import datetime
import hashlib
import io
import json
import tarfile
import time
import urllib.request

root = Path.cwd()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2'
receipt_path = out / 'tls95-telemetry-acquisition.json'
assert not receipt_path.exists(), 'Preserve every acquisition receipt'
cache = root / '.audit/m3-transport/tls95-telemetry-1.4.2.tar'
url = 'https://repo.hex.pm/tarballs/telemetry-1.4.2.tar'
outer_sha = '928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1'
inner_sha = 'a0cb522801dffb1c49fe6e30561badffc7b6d0e180db1300df759faa22062855'
sha = lambda data: hashlib.sha256(data).hexdigest()
inventory = json.loads((out / 'tls-registration-inventory.json').read_text())['input_sha256']
protected = {p: sha((root / p).read_bytes()) for p in inventory}
assert protected == inventory, 'Reviewed acquisition inputs drifted'
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
timer = time.monotonic()
record = {'url': url, 'expected_outer_sha256': outer_sha, 'expected_inner_sha256': inner_sha,
          'started_utc': started, 'socket_timeout_seconds': 30, 'size_cap': 8 * 1024 * 1024,
          'collector_sha256': sha(Path(__file__).read_bytes()), 'baseline_constructed': False}
try:
    if cache.exists():
        assert cache.is_file() and not cache.is_symlink()
        archive = cache.read_bytes()
        record['acquisition'] = 'verified_existing_official_archive'
    else:
        request = urllib.request.Request(url, headers={'User-Agent': 'Gaoxy-TLS95-qualification'})
        with urllib.request.urlopen(request, timeout=30) as response:
            assert response.status == 200 and response.url == url
            archive = response.read(record['size_cap'] + 1)
            record['http_status'] = response.status
        assert len(archive) <= record['size_cap']
        cache.write_bytes(archive)
        record['acquisition'] = 'official_https_public_archive'
    record['archive_sha256'] = sha(archive)
    assert sha(archive) == outer_sha
    with tarfile.open(fileobj=io.BytesIO(archive)) as outer:
        members = outer.getmembers()
        assert len(members) == 4 and all(m.isfile() for m in members)
        parts = {m.name: outer.extractfile(m).read() for m in members}
    assert set(parts) == {'VERSION', 'CHECKSUM', 'metadata.config', 'contents.tar.gz'}
    actual_inner = sha(parts['VERSION'] + parts['metadata.config'] + parts['contents.tar.gz'])
    assert actual_inner == parts['CHECKSUM'].decode().lower() == inner_sha
    record['inner_sha256'] = actual_inner
    shipped = {}
    with tarfile.open(fileobj=io.BytesIO(parts['contents.tar.gz']), mode='r:gz') as inner:
        for member in inner.getmembers():
            if member.isdir():
                continue
            assert member.isfile() and not Path(member.name).is_absolute() and '..' not in Path(member.name).parts
            assert member.name not in shipped
            data = inner.extractfile(member).read()
            assert data == (root / 'deps/telemetry' / member.name).read_bytes()
            shipped[member.name] = sha(data)
    assert b'1.4.2' in (root / 'deps/telemetry/src/telemetry.app.src').read_bytes()
    historical_lock = (root / '.audit/m3-transport/installed-0.21.1-preserved/source/mix.lock').read_text()
    assert outer_sha in historical_lock and inner_sha in historical_lock
    record.update(status='PASS_ARCHIVE_AND_SHIPPED_IDENTITY', shipped=shipped,
                  installed_hex_sha256=sha((root / 'deps/telemetry/.hex').read_bytes()))
except BaseException as error:
    record.update(status='FAIL_ACQUISITION_OR_VERIFICATION', error=repr(error))
    raise
finally:
    after = {p: sha((root / p).read_bytes()) for p in protected}
    record.update(completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  elapsed_seconds=round(time.monotonic()-timer, 3),
                  protected_inputs_before=protected, protected_inputs_after=after,
                  protected_inputs_unchanged=protected==after)
    receipt_path.write_text(json.dumps(record, indent=2, sort_keys=True)+'\n')
    print(json.dumps({k: v for k, v in record.items() if k not in ['protected_inputs_before', 'protected_inputs_after', 'shipped']}, indent=2))
    assert protected == after
