#!/usr/bin/env python3
"""Read back the published 0.12.1 cohort; never publish, extract, or run artifacts."""
import argparse
import datetime
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

VERSION = "0.12.1"
TAG = f"v{VERSION}"
REPO = "gsmlg-dev/gaoxy"
ROOT = Path(__file__).resolve().parents[2]
PACKAGES = {
    "gaoxy": "apps/gaoxy",
    "gaoxy_http": "apps/gaoxy_http",
    "gaoxy_http3": "apps/gaoxy_http3",
    "gaoxy_proxy": "apps/gaoxy_proxy",
    "gaoxy_test": "apps/gaoxy_test",
    "gaoxy_websock_adapter": "vendor/websock_adapter",
}
HTTP_CORE_REQUIREMENT = "~> 0.21 and >= 0.21.16"
RUNTIME_DEPENDENCIES = (
    "http_core", "elixir_quic", "elixir_quic_http3", "ex_ssl",
    "http_fetch", "http_runtime", "http_web_socket",
)
STANDALONE = f"gaoxy-{VERSION}-linux-x86_64.tar.gz"
PAYLOADS = {STANDALONE, *(f"{name}-{VERSION}.tar" for name in PACKAGES)}
EXPECTED = PAYLOADS | {"SHA256SUMS"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def command(args, timeout=60):
    result = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    require(result.returncode == 0,
            f"command failed ({result.returncode}): {args!r}: "
            + result.stderr.decode(errors="replace"))
    return result.stdout


def api(path):
    return json.loads(command(["gh", "api", path]))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    with path.open("x") as output:
        json.dump(value, output, indent=2, sort_keys=True)
        output.write("\n")


def download(url, destination, limit=128 * 1024 * 1024):
    started, size = time.monotonic(), 0
    request = urllib.request.Request(url, headers={"User-Agent": "gaoxy-public-artifact-verifier"})
    with urllib.request.urlopen(request, timeout=30) as response, destination.open("xb") as output:
        while True:
            require(time.monotonic() - started < 120, f"download deadline: {url}")
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            require(size <= limit, f"download exceeded {limit} bytes: {url}")
            output.write(chunk)


def archive_members(archive):
    members = {}
    for member in archive.getmembers():
        name = str(PurePosixPath(member.name))
        require(not name.startswith("/") and ".." not in PurePosixPath(name).parts,
                f"unsafe archive path: {member.name}")
        require(name not in members, f"duplicate archive member: {name}")
        members[name] = member
    return members


def archive_bytes(archive, members, name, limit=16 * 1024 * 1024):
    member = members.get(name)
    require(member is not None and member.isfile(), f"missing regular archive member: {name}")
    require(member.size <= limit, f"oversized archive member: {name}")
    return archive.extractfile(member).read()


def tag_sha():
    target = api(f"repos/{REPO}/git/ref/tags/{TAG}")["object"]
    for _ in range(5):
        if target["type"] == "commit":
            return target["sha"]
        require(target["type"] == "tag", f"unexpected tag target: {target}")
        target = api(f"repos/{REPO}/git/tags/{target['sha']}")["object"]
    raise ValueError("annotated tag nesting exceeds five levels")


def source_files(sha, relative):
    tree = command(["git", "ls-tree", "-r", "-z", sha, "--", f"{relative}/lib"])
    sources = {}
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        mode, kind, blob = metadata.decode().split()
        path = path.decode()
        if path.endswith(".ex"):
            require(kind == "blob" and mode in ("100644", "100755"),
                    f"source is not a regular Git blob: {path}")
            sources[path[len(relative) + 1:]] = (path, blob)
    require(sources, f"no committed Elixir sources: {relative} at {sha}")
    return sources


def require_no_hpax(data, context):
    require(re.search(r"\bhpax\b", data, re.IGNORECASE) is None,
            f"HPAX remains in {context}")


def check_hex_requirements(metadata, package):
    requirements = metadata.get("requirements", {})
    require_no_hpax(json.dumps(requirements), f"Hex requirements: {package}")
    if package == "gaoxy_http":
        dependency = requirements.get("http_core", {})
        require(dependency.get("requirement") == HTTP_CORE_REQUIREMENT
                and dependency.get("app") == "http_core"
                and dependency.get("optional") is False,
                f"wrong required http_core floor: {dependency}")
    return requirements


def expected_runtime_versions(sha):
    lock = command(["git", "show", f"{sha}:mix.lock"]).decode()
    versions = {}
    for app in RUNTIME_DEPENDENCIES:
        values = re.findall(r'"' + re.escape(app)
                            + r'": \{:hex, :' + re.escape(app) + r', "([^"\n]+)"', lock)
        require(len(values) == 1, f"missing exact-source lock version: {app}: {values}")
        version = values[0]
        numeric = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", version)
        require(numeric is not None and tuple(map(int, numeric.groups())) >= (0, 21, 16),
                f"dependency below HPACK fix floor: {app}: {version}")
        versions[app] = version
    return versions


def check_package(path, package, sha):
    relative = PACKAGES[package]
    sources = source_files(sha, relative)
    with tarfile.open(path, "r:") as outer:
        members = archive_members(outer)
        metadata = archive_bytes(outer, members, "metadata.config").decode()
        for key, expected in (("name", package), ("version", VERSION)):
            values = re.findall(r'^\{<<"' + key + r'">>,\s*<<"([^"\n]+)">>\}',
                                metadata, re.MULTILINE)
            require(values == [expected], f"wrong package {key}: {package}: {values}")
        require_no_hpax(metadata, f"package metadata: {package}")
        contents = archive_bytes(outer, members, "contents.tar.gz")
    checked = {}
    with tarfile.open(fileobj=io.BytesIO(contents), mode="r:gz") as inner:
        members = archive_members(inner)
        manifests = [name for name in members if PurePosixPath(name).name in ("mix.exs", "mix.lock")]
        require("mix.exs" in manifests, f"missing package manifest: {package}")
        checked_manifests = {}
        for name in sorted(manifests):
            manifest = archive_bytes(inner, members, name)
            require_no_hpax(manifest.decode(), f"package manifest: {package}/{name}")
            checked_manifests[name] = {"sha256": digest(manifest), "bytes": len(manifest)}
        if package == "gaoxy_http":
            manifest = archive_bytes(inner, members, "mix.exs").decode()
            require(re.search(r'\{:http_core,\s*"' + re.escape(HTTP_CORE_REQUIREMENT) + r'"', manifest),
                    "packaged gaoxy_http manifest lacks required http_core floor")
        actual = {name for name in members if name.startswith("lib/") and name.endswith(".ex")}
        require(actual == set(sources), f"package/source lib .ex file set differs: {package}")
        for name, (source_path, blob) in sorted(sources.items()):
            source = command(["git", "show", f"{sha}:{source_path}"])
            archived = archive_bytes(inner, members, name)
            require(archived == source, f"package source differs: {package}/{name} at {sha}")
            checked[name] = {"source_path": source_path, "source_commit": sha,
                             "git_blob_sha": blob, "sha256": digest(source), "bytes": len(source)}
    return {"version": VERSION, "source_root": relative, "source_files": checked,
            "source_file_count": len(checked), "manifests": checked_manifests,
            "hpax_absent": True}


def check_standalone(path, dependency_versions):
    with tarfile.open(path, "r:gz") as archive:
        members = archive_members(archive)
        start = archive_bytes(archive, members, "releases/start_erl.data").decode().split()
        require(len(start) == 2 and start[1] == VERSION, f"wrong start_erl.data: {start}")
        rel_path = f"releases/{VERSION}/gaoxy.rel"
        release = archive_bytes(archive, members, rel_path).decode()
        require(re.search(r'\{release,\s*\{"gaoxy",\s*"' + re.escape(VERSION) + r'"\}', release),
                "standalone release version differs")
        require_no_hpax(release, "standalone release metadata")
        lib_entries = {PurePosixPath(name).parts[1] for name in members
                       if len(PurePosixPath(name).parts) >= 2
                       and PurePosixPath(name).parts[0] == "lib"}
        require(not any(re.match(r"hpax(?:-|$)", name, re.IGNORECASE) for name in lib_entries),
                "standalone contains an HPAX runtime directory")
        app_metadata = {}
        for name in sorted(members):
            if name.startswith("lib/") and name.endswith(".app"):
                data = archive_bytes(archive, members, name).decode()
                require_no_hpax(data, f"standalone application metadata: {name}")
                app_metadata[name] = {"sha256": digest(data.encode()), "bytes": len(data.encode())}
        require(app_metadata, "standalone has no runtime application metadata")
        dependencies = {}
        for app, version in dependency_versions.items():
            values = re.findall(r'\{' + re.escape(app) + r',\s*"([^"\n]+)",', release)
            require(values == [version], f"standalone dependency version differs: {app}: {values}")
            app_file = f"lib/{app}-{version}/ebin/{app}.app"
            data = archive_bytes(archive, members, app_file).decode()
            require(re.findall(r'\{vsn,\s*"([^"\n]+)"\}', data) == [version],
                    f"standalone dependency .app version differs: {app}")
            dependencies[app] = {"version": version, "metadata_path": app_file,
                                 "metadata_sha256": digest(data.encode())}
        applications = {}
        for app in ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server"):
            values = re.findall(r'\{' + app + r',\s*"([^"\n]+)",', release)
            require(values == [VERSION], f"standalone application version differs: {app}: {values}")
            app_file = f"lib/{app}-{VERSION}/ebin/{app}.app"
            app_data = archive_bytes(archive, members, app_file).decode()
            require(re.findall(r'\{vsn,\s*"([^"\n]+)"\}', app_data) == [VERSION],
                    f"standalone .app version differs: {app}")
            if app in ("gaoxy_http", "gaoxy_http3"):
                expected_dependency = "http_core" if app == "gaoxy_http" else "elixir_quic_http3"
                app_lists = re.findall(r"\{applications,\s*\[([^]]*)\]\}", app_data)
                require(len(app_lists) == 1
                        and expected_dependency in {item.strip() for item in app_lists[0].split(",")},
                        f"standalone {app} lacks runtime dependency {expected_dependency}")
            applications[app] = {"version": VERSION, "metadata_path": app_file,
                                 "metadata_sha256": digest(app_data.encode())}
    return {"version": VERSION, "erts_version": start[0], "release_metadata_path": rel_path,
            "release_metadata_sha256": digest(release.encode()), "applications": applications,
            "dependencies": dependencies, "hpax_absent": True,
            "runtime_application_metadata": app_metadata,
            "runtime_application_metadata_count": len(app_metadata)}


def verify(sha, output, receipt):
    require(command(["git", "rev-parse", f"{sha}^{{commit}}" ]).decode().strip() == sha,
            "expected source commit is unavailable locally")
    remote_sha = tag_sha()
    require(remote_sha == sha, f"remote tag differs: {remote_sha} != {sha}")
    receipt["remote_tag_sha"] = remote_sha
    release = api(f"repos/{REPO}/releases/tags/{TAG}")
    write_json(output / "github-release.json", release)
    require(release["tag_name"] == TAG and not release["draft"] and not release["prerelease"],
            "release is not the expected published stable release")
    assets = {asset["name"]: asset for asset in release["assets"]}
    require(len(assets) == len(release["assets"]) and set(assets) == EXPECTED,
            f"release assets differ: {sorted(assets)}")
    args = ["gh", "release", "download", TAG, "--repo", REPO, "--dir", str(output)]
    for name in sorted(EXPECTED):
        args += ["--pattern", name]
    command(args, timeout=180)
    receipt["release_url"] = release["html_url"]
    receipt["assets"] = {}
    for name, asset in sorted(assets.items()):
        data = (output / name).read_bytes()
        checksum = digest(data)
        require(asset.get("digest") == f"sha256:{checksum}", f"GitHub digest differs: {name}")
        require(asset["size"] == len(data), f"GitHub asset size differs: {name}")
        receipt["assets"][name] = {"sha256": checksum, "bytes": len(data), "asset_id": asset["id"]}
    sums = {}
    for line in (output / "SHA256SUMS").read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        require(match is not None, f"invalid SHA256SUMS entry: {line!r}")
        checksum, name = match.groups()
        require(name not in sums, f"duplicate checksum entry: {name}")
        sums[name] = checksum
    require(set(sums) == PAYLOADS and len(sums) == 7, "SHA256SUMS must cover exactly seven payloads")
    for name, checksum in sums.items():
        require(receipt["assets"][name]["sha256"] == checksum, f"SHA256SUMS differs: {name}")
    receipt["sha256sums_entries"] = len(sums)
    receipt["packages"] = {}
    for package in PACKAGES:
        name = f"{package}-{VERSION}.tar"
        api_path = output / f"hex-{package}.json"
        download(f"https://hex.pm/api/packages/{package}/releases/{VERSION}", api_path, 1024 * 1024)
        metadata = json.loads(api_path.read_text())
        require(metadata["version"] == VERSION and metadata.get("retirement") is None,
                f"Hex version is missing or retired: {package}")
        requirements = check_hex_requirements(metadata, package)
        require(metadata["checksum"] == sums[name], f"Hex API checksum differs: {package}")
        public_path = output / f"hex-{name}"
        download(f"https://repo.hex.pm/tarballs/{name}", public_path)
        require(public_path.read_bytes() == (output / name).read_bytes(),
                f"public Hex archive differs from GitHub: {package}")
        receipt["packages"][package] = check_package(public_path, package, sha)
        receipt["packages"][package]["hex_requirements"] = requirements
        receipt["packages"][package]["hex_url"] = metadata["html_url"]
        receipt["packages"][package]["archive_sha256"] = sums[name]
    receipt["standalone"] = check_standalone(output / STANDALONE, expected_runtime_versions(sha))
    require(tag_sha() == sha, "remote tag changed during verification")
    receipt["status"] = "PASS"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sha", required=True, help="full exact published source commit")
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.sha), "--sha must be a full lowercase commit SHA")
    output = Path(tempfile.mkdtemp(prefix="public-artifacts-", dir=Path(__file__).resolve().parent))
    receipt = {"status": "FAIL", "repo": REPO, "version": VERSION, "tag": TAG,
               "source_commit": args.sha, "source_root": str(ROOT), "output_directory": str(output),
               "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    try:
        verify(args.sha, output, receipt)
    except Exception as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
    receipt["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    write_json(output / "receipt.json", receipt)
    print(json.dumps({"status": receipt["status"], "receipt": str(output / "receipt.json"),
                      "error": receipt.get("error")}, sort_keys=True), flush=True)
    return 0 if receipt["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
