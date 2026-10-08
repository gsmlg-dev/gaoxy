#!/usr/bin/env python3
"""Run a named ExUnit suite and fail on an empty or failing execution."""
import re
import subprocess
import sys

result = subprocess.run(["mix", "test", "--warnings-as-errors", *sys.argv[1:]],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print(result.stdout, end="")
counts = [int(match) for match in re.findall(r"Result:\s+(?:\d+/)?(\d+) passed", result.stdout)]
# Elixir 1.18/1.19 format: "N tests, 0 failures".
counts.extend(int(match) for match in re.findall(r"(\d+) tests?, \d+ failures", result.stdout))
if not counts or sum(counts) == 0:
    print("FAIL: zero executed tests", file=sys.stderr)
    sys.exit(1)
sys.exit(result.returncode)
