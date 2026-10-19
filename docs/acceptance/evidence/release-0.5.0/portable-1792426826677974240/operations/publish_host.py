"""Publish only independently reviewed, qualified v0.5.0 bytes and verify downloads."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
MAIN = Path("/home/gao/Workspace/gsmlg-opt/gaoxy")
RUN, NOTES, REVIEW = [Path(value).resolve() for value in sys.argv[1:]]
IDENTITY = json.loads((RUN / "context/source-identity.json").read_text())
SOURCE = IDENTITY["source_sha"]
ARTIFACTS = RUN / "artifacts"
PUBLICATION = Path(__file__).resolve().parent / f"publication-{time.time_ns()}"
PUBLICATION.mkdir()
DOWNLOADS = PUBLICATION / "downloads"
DOWNLOADS.mkdir()
RECEIPT = PUBLICATION / "publication.json"
receipt = {"status": "FAIL", "source_sha": SOURCE, "run_directory": str(RUN),
           "publication_directory": str(PUBLICATION), "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "commands": []}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save():
    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n")


def run(name, args, cwd=ROOT, timeout=180):
    row = {"name": name, "command": args, "cwd": str(cwd), "timeout_seconds": timeout,
           "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    receipt["commands"].append(row)
    save()
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    row.update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr,
               completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    save()
    result.check_returncode()
    return result.stdout.strip()


print(str(PUBLICATION), flush=True)
try:
    host = json.loads((RUN / "evidence/host-qualification.json").read_text())
    review = json.loads(REVIEW.read_text())
    assert host["status"] == review["status"] == "PASS"
    assert host["source_sha"] == review["source_sha"] == SOURCE
    assert review["run_directory"] == str(RUN)
    assert review["host_qualification_sha256"] == sha(RUN / "evidence/host-qualification.json")
    assert review["artifact_sha256"] == host["artifact_sha256"]
    assert review["reviewed_notes_sha256"] == sha(NOTES)
    receipt.update(notes_sha256=sha(NOTES), artifact_review_sha256=sha(REVIEW))
    for name, digest in host["artifact_sha256"].items():
        assert sha(ARTIFACTS / name) == digest, name
    names = ["gaoxy-0.5.0-linux-x86_64.tar.gz", "build-info.json", "SHA256SUMS"]
    assert set(host["artifact_sha256"]) == set(names)
    assert run("frozen-branch", ["git", "rev-parse", "HEAD"]) == SOURCE
    assert run("clean-branch", ["git", "status", "--porcelain"]) == ""
    assert run("main-source", ["git", "rev-parse", "HEAD"], MAIN) == SOURCE
    preparation = json.loads(Path(__file__).with_name("preparation.json").read_text())
    assert run("main-status", ["git", "status", "--porcelain"], MAIN) == preparation["status_porcelain"]
    prompt = MAIN / "gaoxy-m1.1-fix-prompt.md"
    assert prompt.exists() == preparation["prompt_exists"]
    if prompt.exists():
        assert sha(prompt) == preparation["prompt_sha256"]
    assert run("local-tag-absent", ["git", "tag", "--list", "v0.5.0"]) == ""
    assert run("remote-tag-absent", ["git", "ls-remote", "--tags", "origin", "refs/tags/v0.5.0"]) == ""
    run("push-main", ["git", "push", "origin", "main"], MAIN)
    assert run("remote-main", ["git", "ls-remote", "origin", "refs/heads/main"]).split()[0] == SOURCE
    run("annotated-tag", ["git", "tag", "-a", "v0.5.0", "-m", "Gaoxy v0.5.0", SOURCE])
    tag = run("local-tag-object", ["git", "rev-parse", "refs/tags/v0.5.0"])
    assert run("tag-type", ["git", "cat-file", "-t", tag]) == "tag"
    run("push-tag", ["git", "push", "origin", "refs/tags/v0.5.0"])
    refs = run("remote-tag", ["git", "ls-remote", "origin", "refs/tags/v0.5.0", "refs/tags/v0.5.0^{}"])
    remote = {line.split()[1]: line.split()[0] for line in refs.splitlines()}
    assert remote == {"refs/tags/v0.5.0": tag, "refs/tags/v0.5.0^{}": SOURCE}
    run("create-release", ["gh", "release", "create", "v0.5.0", *[str(ARTIFACTS / name) for name in names],
        "--repo", "gsmlg-opt/gaoxy", "--verify-tag", "--latest", "--title", "Gaoxy v0.5.0", "--notes-file", str(NOTES)], timeout=600)
    release = json.loads(run("release-metadata", ["gh", "api", "repos/gsmlg-opt/gaoxy/releases/tags/v0.5.0"]))
    (PUBLICATION / "release.json").write_text(json.dumps(release, indent=2) + "\n")
    assert release["tag_name"] == "v0.5.0" and not release["draft"] and not release["prerelease"]
    assert release["name"] == "Gaoxy v0.5.0"
    assert release["body"].replace("\r\n", "\n").strip() == NOTES.read_text().strip()
    assert sorted(asset["name"] for asset in release["assets"]) == sorted(names)
    for asset in release["assets"]:
        assert asset["size"] == (ARTIFACTS / asset["name"]).stat().st_size
        if asset.get("digest"):
            assert asset["digest"] == "sha256:" + host["artifact_sha256"][asset["name"]]
    latest = json.loads(run("latest-release", ["gh", "api", "repos/gsmlg-opt/gaoxy/releases/latest"]))
    assert latest["tag_name"] == "v0.5.0"
    run("fresh-download", ["gh", "release", "download", "v0.5.0", "--repo", "gsmlg-opt/gaoxy", "--dir", str(DOWNLOADS)], timeout=600)
    run("verify-downloads", [sys.executable, str(Path(__file__).with_name("verify_downloads.py")),
        str(ARTIFACTS), str(DOWNLOADS), str(RUN / "context/source-identity.json"), str(PUBLICATION / "download-verification.json")])
    verified = json.loads((PUBLICATION / "download-verification.json").read_text())
    assert verified["status"] == "PASS"
    final_refs = run("remote-refs-final", ["git", "ls-remote", "origin", "refs/heads/main", "refs/tags/v0.5.0", "refs/tags/v0.5.0^{}"])
    assert {line.split()[1]: line.split()[0] for line in final_refs.splitlines()} == {
        "refs/heads/main": SOURCE, "refs/tags/v0.5.0": tag, "refs/tags/v0.5.0^{}": SOURCE}
    hosted = json.loads(run("new-hosted-runs", ["gh", "run", "list", "--repo", "gsmlg-opt/gaoxy", "--commit", SOURCE,
        "--limit", "20", "--json", "databaseId,name,status,conclusion,headSha,createdAt"]))
    receipt.update(tag_object=tag, release_url=release["html_url"], release_id=release["id"],
                   assets=host["artifact_sha256"], hosted_runs=hosted,
                   new_hosted_status="NOT RUN" if not hosted else "SEE_RECORDED_RUNS", status="PASS")
except BaseException as error:
    receipt["error"] = repr(error)
    raise
finally:
    receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
print("PASS publication and fresh asset download verification", flush=True)
