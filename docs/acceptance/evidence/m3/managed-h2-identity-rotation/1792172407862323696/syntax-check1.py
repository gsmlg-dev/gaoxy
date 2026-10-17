#!/usr/bin/env python3
"""Static Python/extracted-CDP JavaScript validation; executes no protocol tests."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess

E = Path(__file__).resolve().parent
R = E.parents[5]
paths = sorted(E.glob("*.py")) + [R / "apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py"]
checks = []
for path in paths:
    tree = ast.parse(path.read_text(), filename=str(path))
    checks.append({"kind": "Python AST", "path": str(path.relative_to(R)),
                   "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "status": "PASS"})
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "BROWSER" for t in node.targets):
            code = ast.literal_eval(node.value)
            result = subprocess.run(["node", "--check", "--input-type=commonjs"], input=code, text=True, capture_output=True)
            checks.append({"kind": "extracted JavaScript", "parent": path.name,
                           "sha256": hashlib.sha256(code.encode()).hexdigest(), "actual_exit": result.returncode,
                           "stdout": result.stdout, "stderr": result.stderr})
            if result.returncode:
                raise SystemExit(json.dumps(checks))
print(json.dumps({"status": "PASS_STATIC_ONLY", "tests_executed": 0, "checks": checks}, indent=2))
