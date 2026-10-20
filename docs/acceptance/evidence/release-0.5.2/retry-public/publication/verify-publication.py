#!/usr/bin/env python3
"""Independent read/download-only release verification; writes this audit folder."""
import datetime
import hashlib
import io
import json
import os
import pathlib
import subprocess
import tarfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
REPO = "gsmlg-dev/gaoxy"
VERSION = "0.5.2"
SOURCE = "d9fb3a5edee0c7e1dc1d141c7ce04db788b92fdf"
RUN = "39404989025"
PACKAGES = ["gaoxy_websock_adapter", "gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy"]
COMMANDS = []


def digest(data):
    return hashlib.sha256(data).hexdigest()


def command(args, filename):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (HERE / filename).write_bytes(result.stdout)
    (HERE / (filename + ".stderr")).write_bytes(result.stderr)
    COMMANDS.append({"command": args, "exit": result.returncode, "stdout": filename,
                     "stdout_sha256": digest(result.stdout), "stderr": filename + ".stderr"})
    assert result.returncode == 0, (args, result.stderr.decode())
    return result.stdout


def api(path, filename):
    return json.loads(command(["gh", "api", path], filename))


def public(url, filename):
    with urllib.request.urlopen(url, timeout=30) as response:
        data = response.read()
        status = response.status
    (HERE / filename).write_bytes(data)
    COMMANDS.append({"url": url, "status": status, "output": filename, "sha256": digest(data)})
    assert status == 200
    return data


def payload(data):
    with tarfile.open(fileobj=io.BytesIO(data)) as outer:
        metadata = outer.extractfile("metadata.config").read()
        with tarfile.open(fileobj=io.BytesIO(outer.extractfile("contents.tar.gz").read()), mode="r:gz") as inner:
            files = {m.name: inner.extractfile(m).read() for m in inner.getmembers() if m.isfile()}
    return metadata, files


def metadata(data, name):
    path = HERE / (name + ".config")
    path.write_bytes(data)
    code = '''
{:ok, terms} = :file.consult(String.to_charlist(hd(System.argv())))
convert = fn
  values, recur when is_list(values) ->
    if values != [] and Enum.all?(values, &match?({_, _}, &1)),
      do: Map.new(values, fn {key, value} -> {key, recur.(value, recur)} end),
      else: Enum.map(values, &recur.(&1, recur))
  value, _ -> value
end
IO.puts(JSON.encode!(convert.(terms, convert)))
'''
    result = subprocess.run(["elixir", "-e", code, str(path)], capture_output=True,
                            env={**os.environ, "ELIXIR_ERL_OPTIONS": "+S 2:2"}, check=True)
    parsed = json.loads(result.stdout)
    parsed["files"] = sorted(parsed["files"])
    parsed["requirements"] = sorted(parsed["requirements"], key=lambda r: r["name"])
    return parsed


def main():
    run = api(f"repos/{REPO}/actions/runs/{RUN}", "hosted-run.json")
    jobs = api(f"repos/{REPO}/actions/runs/{RUN}/jobs", "hosted-jobs.json")
    assert run["status"] == "completed" and run["conclusion"] == "success", "HOLD: hosted execution has not succeeded"
    assert run["head_sha"] == SOURCE
    assert len(jobs["jobs"]) == 1 and jobs["jobs"][0]["conclusion"] == "success"
    assert all(s["conclusion"] in ["success", "skipped"] for s in jobs["jobs"][0]["steps"])
    release = api(f"repos/{REPO}/releases/tags/v{VERSION}", "release.json")
    assert release["tag_name"] == "v" + VERSION and not release["draft"] and not release["prerelease"]
    tag = api(f"repos/{REPO}/git/ref/tags/v{VERSION}", "tag.json")
    obj = tag["object"]
    if obj["type"] == "tag":
        obj = api(f"repos/{REPO}/git/tags/{obj['sha']}", "annotated-tag.json")["object"]
    assert obj == {"sha": SOURCE, "type": "commit", "url": f"https://api.github.com/repos/{REPO}/git/commits/{SOURCE}"}
    expected = {f"{name}-{VERSION}.tar" for name in PACKAGES} | {f"gaoxy-{VERSION}-linux-x86_64.tar.gz", "SHA256SUMS"}
    assert {a["name"] for a in release["assets"]} == expected
    downloads = HERE / "downloads"
    downloads.mkdir(exist_ok=False)
    command(["gh", "release", "download", "v" + VERSION, "--repo", REPO, "--dir", str(downloads)], "download.log")
    assets = []
    for item in release["assets"]:
        data = (downloads / item["name"]).read_bytes()
        assert len(data) == item["size"]
        assert item["digest"] == "sha256:" + digest(data), item["name"]
        assets.append({"name": item["name"], "id": item["id"], "size": len(data), "sha256": digest(data)})
    checksums = (downloads / "SHA256SUMS").read_text().splitlines()
    covered = set()
    for line in checksums:
        sha, filename = line.split(maxsplit=1)
        assert filename in expected - {"SHA256SUMS"} and filename not in covered
        assert digest((downloads / filename).read_bytes()) == sha
        covered.add(filename)
    assert len(checksums) == 6 and covered == expected - {"SHA256SUMS"}
    builds = json.loads((ROOT / "packaging/builds.json").read_text())
    package_results = []
    for name in PACKAGES:
        record = json.loads(public(f"https://hex.pm/api/packages/{name}/releases/{VERSION}", name + "-hex-record.json"))
        expected_meta = next(x["metadata"] for x in builds["packages"] if x["package"] == name)
        assert record["version"] == VERSION and not record.get("retirement")
        expected_reqs = {x["name"]: {k: x[k] for k in ["app", "optional", "requirement"]} for x in expected_meta["requirements"]}
        assert record["requirements"] == expected_reqs, name
        data = public(f"https://repo.hex.pm/tarballs/{name}-{VERSION}.tar", name + "-hex.tar")
        assert record["checksum"] == digest(data), name
        github = (downloads / f"{name}-{VERSION}.tar").read_bytes()
        local = (ROOT / f"packaging/artifacts/{name}-{VERSION}.tar").read_bytes()
        assert data == github, name
        published_metadata, published_files = payload(data)
        local_metadata, local_files = payload(local)
        assert published_files == local_files, (name, "payload differs from locally qualified artifact")
        assert metadata(published_metadata, name + "-published-metadata") == metadata(local_metadata, name + "-local-metadata"), name
        package_results.append({"name": name, "app": expected_meta["app"], "sha256": digest(data),
                                "github_public_hex_bytes_equal": True, "local_tar_bytes_equal": data == local,
                                "local_metadata_and_payload_equal": True})
    result = {"status": "PASS", "time_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "source": SOURCE, "run_id": int(RUN), "run_url": run["html_url"],
              "release_url": release["html_url"], "release_id": release["id"], "assets": assets,
              "checksum_entries_verified": 6, "packages": package_results, "commands": COMMANDS,
              "consumer_status": "Separate public consumer agent evidence remains to be reviewed",
              "findings": [], "sol_repair_rounds": 0, "command_shutdown_status": "All commands completed"}
    (HERE / "publication-download-review.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": "PASS", "receipt": str(HERE / "publication-download-review.json")}))


if __name__ == "__main__":
    try:
        main()
    finally:
        (HERE / "publication-review-commands.json").write_text(json.dumps(COMMANDS, indent=2) + "\n")
