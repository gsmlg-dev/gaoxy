"""Freeze a clean committed release source and copy its exact reviewed recipes."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
AUDIT = Path(__file__).resolve().parent
RECIPE = ROOT / "docs/acceptance/evidence/release-0.5.0/portable/recipe"
RUN = AUDIT / f"portable-{time.time_ns()}"
CONTEXT = RUN / "context"
CONTEXT.mkdir(parents=True)
(RUN / "evidence").mkdir()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert git("status", "--porcelain") == ""
source = git("rev-parse", "HEAD")
assert "[skip ci]" in git("show", "-s", "--format=%s", source)
assert sha(ROOT / "mix.lock") == "9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777"
projects = [ROOT / "mix.exs", *sorted((ROOT / "apps").glob("*/mix.exs"))]
assert len(projects) == 6
for project in projects:
    assert re.findall(r'\bversion:\s*"([^"]+)"', project.read_text()) == ["0.5.0"], project
recipes = {}
for path in sorted(RECIPE.iterdir()):
    assert path.is_file() and not path.is_symlink(), path
    shutil.copyfile(path, CONTEXT / path.name)
    assert sha(path) == sha(CONTEXT / path.name)
    recipes[path.name] = sha(path)
assert len(recipes) == 8
archive = CONTEXT / "source.tar"
with archive.open("wb") as output:
    subprocess.run(["git", "archive", "--format=tar", source], cwd=ROOT,
                   stdout=output, check=True, timeout=120)
with archive.open("rb") as stream:
    archived_source = subprocess.check_output(["git", "get-tar-commit-id"], stdin=stream, text=True).strip()
assert archived_source == source
changed = git("diff", "--name-only", "--diff-filter=ACMR", "v0.4.0", source, "--", "*.ex", "*.exs").splitlines()
assert changed and len(changed) == len(set(changed))
identity = {"version": "0.5.0", "source_sha": source,
            "source_archive_sha256": sha(archive), "root_lock_sha256": sha(ROOT / "mix.lock"),
            "changed_elixir_paths": changed}
(CONTEXT / "source-identity.json").write_text(json.dumps(identity, indent=2) + "\n")
with tarfile.open(archive) as package:
    entries = package.getmembers()
    assert all(not Path(member.name).is_absolute() and ".." not in Path(member.name).parts
               for member in entries)
    regular_files = sum(member.isfile() for member in entries)
receipt = {"status": "PASS", "source_sha": source, "run_directory": str(RUN),
           "captured_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "identity": identity, "source_regular_files": regular_files,
           "recipe_sha256": recipes, "archive_commit": archived_source,
           "source_identity_sha256": sha(CONTEXT / "source-identity.json")}
(RUN / "evidence/source-preparation.json").write_text(json.dumps(receipt, indent=2) + "\n")
(AUDIT / "active-run.json").write_text(json.dumps({"run_directory": str(RUN), "source_sha": source}, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
