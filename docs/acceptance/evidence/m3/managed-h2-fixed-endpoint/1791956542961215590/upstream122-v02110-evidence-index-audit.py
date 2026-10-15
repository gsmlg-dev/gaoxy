import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(paths_file):
    relative_prefix = str(E.relative_to(R)) + '/'
    paths = [p.decode() for p in paths_file.read_bytes().split(b'\0') if p]
    assert paths and len(paths) == len(set(paths))
    assert all(p.startswith(relative_prefix) and '\n' not in p and '\r' not in p for p in paths)
    staged = {p.decode() for p in subprocess.check_output(
        ['git', 'diff', '--cached', '--name-only', '-z'], cwd=R).split(b'\0') if p}
    assert staged == set(paths), {'missing': sorted(set(paths) - staged), 'unexpected': sorted(staged - set(paths))}
    old_path = E / 'upstream122-v02110-final-commit-inventory.json'
    assert digest(old_path) == '5131f111e4bc4fd8d6ff0494852a8aa6b54f20f6b4b88e323e386fc93595f0a0'
    old = {item['path']: item for item in json.loads(old_path.read_text())['items']}
    expected_old = {p for p in old if p.startswith(relative_prefix)}
    assert expected_old <= set(paths), sorted(expected_old - set(paths))
    candidate_path = E / 'upstream122-v02110-closure-candidate-manifest.json'
    assert digest(candidate_path) == '68e59fb9b2f08bd3db90509bfc52dfb811e42d1ece6a49928064cb32f3150869'
    candidate = json.loads(candidate_path.read_text())
    frozen = candidate['source_files'] | candidate['authorities']
    assert all(digest(R / p) == value for p, value in frozen.items())
    checked = []
    mismatches = []
    process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=R,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for name in paths:
            path = R / name
            assert path.is_file() and not path.is_symlink(), name
            raw = path.read_bytes()
            expected = hashlib.sha256(raw).hexdigest()
            if name in old:
                assert expected == old[name]['sha256'] and len(raw) == old[name]['bytes'], name
            process.stdin.write((':' + name + '\n').encode())
            process.stdin.flush()
            header = process.stdout.readline().decode().strip().split()
            assert len(header) == 3 and header[1] == 'blob', (name, header)
            object_size = int(header[2])
            hasher = hashlib.sha256()
            remaining = object_size
            while remaining:
                chunk = process.stdout.read(min(1048576, remaining))
                assert chunk, name
                hasher.update(chunk)
                remaining -= len(chunk)
            assert process.stdout.read(1) == b'\n', name
            actual = hasher.hexdigest()
            item = {'path': name, 'bytes': len(raw), 'disk_sha256': expected,
                    'index_sha256': actual, 'object_id': header[0], 'object_bytes': object_size}
            checked.append(item)
            if actual != expected or object_size != len(raw):
                mismatches.append(item)
        process.stdin.close()
        assert process.wait(timeout=30) == 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        process.stdout.close()
        if not process.stdin.closed:
            process.stdin.close()
    assert all(digest(R / p) == value for p, value in frozen.items())
    return {'kind': 'FROZEN_EVIDENCE_GIT_INDEX_BYTE_AUDIT',
            'status': 'PASS_ALL_INDEX_BLOBS_MATCH_ORIGINAL_BYTES' if not mismatches else 'FAIL_INDEX_BYTES_DIFFER',
            'checked_at_utc': datetime.now(timezone.utc).isoformat(),
            'script_sha256': digest(Path(__file__)),
            'paths_sha256': digest(paths_file), 'paths_count': len(paths),
            'immutable_old_evidence_count': len(expected_old), 'immutable_old_hashes_preserved': True,
            'checked_bytes': sum(item['bytes'] for item in checked),
            'source52_authorities5_unchanged': True, 'cat_file_process_joined': True,
            'mismatches': mismatches, 'checked': checked}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--paths', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists()
    result = audit(args.paths)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'checked'}, indent=2))
    raise SystemExit(0 if not result['mismatches'] else 1)
