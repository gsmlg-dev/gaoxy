#!/usr/bin/env python3
"""Require exact, disjoint active and explicitly retained app-test ownership."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent


def check(root, manifest):
    spec = importlib.util.spec_from_file_location('test_manifest', manifest)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    suites = module.SUITES
    if set(suites) != {'unit', 'component', 'protocol'}:
        raise ValueError('canonical suites must be unit, component and protocol')
    active = {}
    counts = {}

    def exact(path):
        if not isinstance(path, str) or any(char in path for char in '*?[]'):
            raise ValueError(f'wildcard or invalid path: {path}')
        if not re.fullmatch(r'apps/[^/]+/test/(?:[^/]+/)*[^/]+_test\.exs', path) or '..' in Path(path).parts:
            raise ValueError(f'invalid test path: {path}')
        if not (root / path).is_file():
            raise ValueError(f'missing test file: {path}')

    for suite, entries in suites.items():
        counts[suite] = 0
        for path, count in entries:
            exact(path)
            if type(count) is not int or count <= 0:
                raise ValueError(f'expected positive case count: {path}')
            if path in active:
                raise ValueError(f'duplicate active ownership: {path}')
            active[path] = suite
            counts[suite] += count
    retained = set()
    inventory = json.loads((root / 'scripts/test-inventory.json').read_text())
    for entry in inventory['retained']:
        path = entry['path']
        exact(path)
        if not isinstance(entry.get('reason'), str) or not entry['reason'].strip():
            raise ValueError(f'retained reason required: {path}')
        if path in retained:
            raise ValueError(f'duplicate retained path: {path}')
        if path in active:
            raise ValueError(f'active/retained overlap: {path}')
        if entry.get('disposition') not in {'specialist_deferred', 'existing_not_scheduled'}:
            raise ValueError(f'known retained disposition required: {path}')
        retained.add(path)
    actual = {str(path.relative_to(root)) for path in (root / 'apps').glob('*/test/**/*_test.exs')}
    unknown = actual - active.keys() - retained
    if unknown:
        raise ValueError('unknown test files: ' + ', '.join(sorted(unknown)))
    for path in sorted(actual):
        source = (root / path).read_text()
        declared = bool(re.search(r'^\s*@moduletag\s+(?::unit\b|unit:\s*true\b)', source, re.M))
        if declared != (active.get(path) == 'unit'):
            raise ValueError(f'unit declaration disagrees with manifest: {path}')
    print('INVENTORY_PASS', ', '.join(f'{suite}={counts[suite]}' for suite in suites),
          f'active_files={len(active)} retained_files={len(retained)}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--manifest', type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    check(root, args.manifest or root / 'scripts/check-repairs.py')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError) as error:
        sys.exit(f'INVENTORY_FAIL: {error}')
