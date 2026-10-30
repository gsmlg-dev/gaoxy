#!/usr/bin/env python3
"""Read back an explicitly selected published cohort; never publish, extract, or run artifacts."""
import argparse
import datetime
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile

VERSION = None
TAG = None
REPO = "gsmlg-dev/gaoxy"
ROOT = Path(__file__).resolve().parents[3]
PACKAGES = {
    "gaoxy": "apps/gaoxy",
    "gaoxy_http": "apps/gaoxy_http",
    "gaoxy_http3": "apps/gaoxy_http3",
    "gaoxy_proxy": "apps/gaoxy_proxy",
    "gaoxy_test": "apps/gaoxy_test",
    "gaoxy_websock_adapter": "vendor/websock_adapter",
}
HTTP_CORE_REQUIREMENT = "~> 0.21 and >= 0.21.17"
RUNTIME_DEPENDENCIES = (
    "http_core", "elixir_quic", "elixir_quic_http3", "ex_ssl",
    "http_fetch", "http_runtime", "http_web_socket",
)
HELL_URL = "https://github.com/gsmlg-dev/hell.git"
HELL_REF = "4fb5d53a1b2acfb5afc9b1ceba65fdc52d61ef83"
PINNED_VERSIONS = {"hell": "0.1.3", "abyss": "0.10.0", "plug_crypto": "2.2.1"}
STANDALONE = None
PAYLOADS = set()
EXPECTED = set()
WORKFLOW_PATH = ".github/workflows/release.yml"
ARTIFACT_NAME = None


def require(condition, message):
    if not condition:
        raise ValueError(message)


def configure(version):
    # Use release.yml's strict SemVer contract; no implicit/latest version.
    number = r"(?:0|[1-9][0-9]*)"
    prerelease = rf"(?:{number}|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    semver = rf"{number}\.{number}\.{number}(?:-{prerelease}(?:\.{prerelease})*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    require(re.fullmatch(semver, version), "--version must be a SemVer without a v prefix")
    global VERSION, TAG, STANDALONE, PAYLOADS, EXPECTED, ARTIFACT_NAME
    VERSION, TAG = version, f"v{version}"
    STANDALONE = f"gaoxy-{version}-linux-x86_64.tar.gz"
    PAYLOADS = {STANDALONE, *(f"{name}-{version}.tar" for name in PACKAGES)}
    EXPECTED = PAYLOADS | {"SHA256SUMS"}
    ARTIFACT_NAME = f"gaoxy-{version}-linux-x86_64"


def command(args, timeout=60):
    result = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    require(result.returncode == 0,
            f"command failed ({result.returncode}): {args!r}: "
            + result.stderr.decode(errors="replace"))
    return result.stdout


def api(path):
    return json.loads(command(["gh", "api", path]))


def paginated_api(path, key):
    pages = json.loads(command(["gh", "api", "--paginate", "--slurp", path], timeout=180))
    require(isinstance(pages, list), f"missing paginated API response: {path}")
    return [item for page in pages for item in page[key]]


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
    tree = command(["git", "ls-tree", "-r", "-z", sha, "--", f"{relative}/lib", f"{relative}/priv"])
    sources = {}
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        mode, kind, blob = metadata.decode().split()
        path = path.decode()
        if path.startswith((f"{relative}/lib/", f"{relative}/priv/")):
            require(kind == "blob" and mode in ("100644", "100755"),
                    f"source is not a regular Git blob: {path}")
            sources[path[len(relative) + 1:]] = (path, blob)
    require(sources, f"no committed package lib/priv sources: {relative} at {sha}")
    return sources


def require_no_hpax(data, context):
    require(re.search(r"\bhpax\b", data, re.IGNORECASE) is None,
            f"HPAX remains in {context}")


def check_hex_requirements(metadata, package):
    app = "websock_adapter" if package == "gaoxy_websock_adapter" else package
    require(metadata.get("meta", {}).get("app") == app, f"wrong Hex application identity: {package}")
    requirements = metadata.get("requirements", {})
    siblings = {
        "gaoxy_http": {"gaoxy", "gaoxy_websock_adapter"},
        "gaoxy_http3": {"gaoxy_http"},
        "gaoxy_proxy": {"gaoxy", "gaoxy_http"},
        "gaoxy_test": {"gaoxy_http", "gaoxy_http3"},
    }.get(package, set())
    require(set(requirements) & set(PACKAGES) == siblings,
            f"wrong sibling dependency set: {package}")
    for sibling in siblings:
        dependency = requirements[sibling]
        sibling_app = "websock_adapter" if sibling == "gaoxy_websock_adapter" else sibling
        optional = package == "gaoxy_test" and sibling == "gaoxy_http3"
        require(dependency.get("app") == sibling_app
                and dependency.get("requirement") == "== " + VERSION
                and dependency.get("optional") is optional,
                f"wrong sibling dependency version/app/optionality: {package}/{sibling}")
    if package == "gaoxy_websock_adapter":
        for name in ("bandit", "plug_cowboy"):
            require(requirements.get(name, {}).get("optional") is True,
                    f"adapter optional dependency differs: {name}")
    require_no_hpax(json.dumps(requirements), f"Hex requirements: {package}")
    if package == "gaoxy":
        for app in ("hell", "abyss"):
            dependency = requirements.get(app, {})
            require(dependency.get("requirement") == "== " + PINNED_VERSIONS[app]
                    and dependency.get("app") == app
                    and dependency.get("optional") is False,
                    f"wrong required {app} pin: {dependency}")
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
    expected = {**dict.fromkeys(RUNTIME_DEPENDENCIES, "0.21.17"),
                "abyss": PINNED_VERSIONS["abyss"],
                "plug_crypto": PINNED_VERSIONS["plug_crypto"]}
    for app, version in expected.items():
        values = re.findall(r'"' + re.escape(app)
                            + r'": \{:hex, :' + re.escape(app) + r', "([^"\n]+)"', lock)
        require(values == [version],
                f"wrong exact-source lock version: {app}: {values}, expected {version}")
        versions[app] = version
    hell_lock = (f'"hell": {{:git, "{HELL_URL}", "{HELL_REF}", '
                 f'[ref: "{HELL_REF}"]}}')
    require(lock.count(hell_lock) == 1, "source Hell lock differs from released public API pin")
    manifest = command(["git", "show", f"{sha}:apps/gaoxy/mix.exs"]).decode()
    require(re.search(r'\{:hell,\s*git:\s*"' + re.escape(HELL_URL)
                      + r'",\s*ref:\s*"' + HELL_REF + r'"\}', manifest),
            "source gaoxy manifest lacks approved Hell URL/ref")
    require(re.search(r'\{:abyss,\s*"== 0\.10\.0"\}', manifest),
            "source gaoxy manifest lacks exact Abyss 0.10.0")
    staging = command(["git", "show", f"{sha}:scripts/stage-hex-packages.exs"]).decode()
    require(re.search(r'hell:\s*\{"' + re.escape(HELL_URL) + r'",\s*"'
                      + HELL_REF + r'",\s*"0\.1\.3"\}', staging),
            "source staging does not map approved Hell pin to Hex 0.1.3")
    versions["hell"] = PINNED_VERSIONS["hell"]
    return versions


def check_package(path, package, sha):
    relative = PACKAGES[package]
    sources = source_files(sha, relative)
    with tarfile.open(path, "r:") as outer:
        members = archive_members(outer)
        metadata = archive_bytes(outer, members, "metadata.config").decode()
        for key, expected in (("name", package), ("version", VERSION),
                              ("app", "websock_adapter" if package == "gaoxy_websock_adapter" else package)):
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
        if package == "gaoxy":
            manifest = archive_bytes(inner, members, "mix.exs").decode()
            require(not re.search(r"\b(?:git|github|path|in_umbrella):", manifest),
                    "packaged gaoxy manifest contains a source-only dependency")
            for app in ("hell", "abyss"):
                require(re.search(r"(?:\{:" + app + r',\s*"== '
                                  + re.escape(PINNED_VERSIONS[app]) + r'"\}|\b'
                                  + app + r':\s*"== '
                                  + re.escape(PINNED_VERSIONS[app])
                                  + r'"(?=\s*(?:,|\])))', manifest),
                        f"packaged gaoxy manifest lacks exact {app} pin")
        if package == "gaoxy_http":
            manifest = archive_bytes(inner, members, "mix.exs").decode()
            require(re.search(r'\{:http_core,\s*"' + re.escape(HTTP_CORE_REQUIREMENT) + r'"', manifest),
                    "packaged gaoxy_http manifest lacks required http_core floor")
        manifest = archive_bytes(inner, members, "mix.exs").decode()
        app = "websock_adapter" if package == "gaoxy_websock_adapter" else package
        require(re.findall(r'\bapp:\s*:([a-z_][a-z0-9_]*)', manifest) == [app],
                f"packaged manifest app differs: {package}")
        require(re.findall(r'\bversion:\s*"([^"\n]+)"', manifest) == [VERSION],
                f"packaged manifest version differs: {package}")
        actual = {name for name, member in members.items()
                  if name.startswith(("lib/", "priv/")) and not member.isdir()}
        require(actual == set(sources), f"package/source lib/priv file set differs: {package}")
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
        boot = archive_bytes(archive, members, f"releases/{VERSION}/start.boot")
        require(boot, "standalone start.boot is empty")
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
            if app in ("gaoxy", "gaoxy_http", "gaoxy_http3"):
                expected_dependencies = {"gaoxy": ("hell", "abyss"),
                                         "gaoxy_http": ("http_core",),
                                         "gaoxy_http3": ("elixir_quic_http3",)}[app]
                app_lists = re.findall(r"\{applications,\s*\[([^]]*)\]\}", app_data)
                require(len(app_lists) == 1
                        and set(expected_dependencies) <= {item.strip() for item in app_lists[0].split(",")},
                        f"standalone {app} lacks runtime dependencies {expected_dependencies}")
            applications[app] = {"version": VERSION, "metadata_path": app_file,
                                 "metadata_sha256": digest(app_data.encode())}
    return {"version": VERSION, "erts_version": start[0],
            "start_boot_sha256": digest(boot), "release_metadata_path": rel_path,
            "release_metadata_sha256": digest(release.encode()), "applications": applications,
            "dependencies": dependencies, "hpax_absent": True,
            "runtime_application_metadata": app_metadata,
            "runtime_application_metadata_count": len(app_metadata)}


def check_workflow_artifact(sha, output, receipt):
    runs = paginated_api(
        f"repos/{REPO}/actions/workflows/release.yml/runs?head_sha={sha}"
        "&event=workflow_dispatch&branch=main&status=success&per_page=100",
        "workflow_runs")
    require(runs, f"no successful release.yml workflow_dispatch run on main at {sha}")
    selected = None
    for run in sorted(runs, key=lambda item: item["id"], reverse=True):
        require(run["head_sha"] == sha and run["head_branch"] == "main"
                and run["event"] == "workflow_dispatch" and run["status"] == "completed"
                and run["conclusion"] == "success" and run["path"] == WORKFLOW_PATH,
                f"release workflow source or completion differs: run {run['id']}")
        artifacts = paginated_api(
            f"repos/{REPO}/actions/runs/{run['id']}/artifacts?per_page=100", "artifacts")
        matches = [item for item in artifacts if item["name"] == ARTIFACT_NAME]
        require(len(matches) <= 1, f"duplicate release artifacts in run {run['id']}")
        if matches:
            selected = run, matches[0]
            break
    require(selected is not None, f"successful release run has no {ARTIFACT_NAME} artifact")
    run, artifact = selected
    workflow_run = artifact.get("workflow_run", {})
    require(not artifact["expired"] and workflow_run.get("id") == run["id"]
            and workflow_run.get("head_sha") == sha and workflow_run.get("head_branch") == "main",
            "release artifact is expired or belongs to a different source run")
    metadata_digest = artifact.get("digest", "")
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", metadata_digest),
            "release Actions artifact has no SHA256 digest")
    data = command(["gh", "api", f"repos/{REPO}/actions/artifacts/{artifact['id']}/zip"],
                   timeout=180)
    require(len(data) <= 128 * 1024 * 1024, "release Actions artifact exceeds 128 MiB")
    checksum = digest(data)
    require(metadata_digest == f"sha256:{checksum}", "Actions artifact ZIP digest differs")
    archive_path = output / "release-actions-artifact.zip"
    with archive_path.open("xb") as archive_output:
        archive_output.write(data)
    compared = {}
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members = archive.infolist()
        names = [member.filename for member in members]
        require(len(names) == len(set(names)) and set(names) == EXPECTED,
                f"Actions artifact files differ: {sorted(names)}")
        for member in members:
            require(not member.is_dir() and member.file_size <= 128 * 1024 * 1024,
                    f"invalid Actions artifact member: {member.filename}")
            published = (output / member.filename).read_bytes()
            require(member.file_size == len(published),
                    f"Actions artifact member size differs: {member.filename}")
            built = archive.read(member)
            require(built == published, f"Actions artifact differs from public asset: {member.filename}")
            compared[member.filename] = {"sha256": digest(built), "bytes": len(built)}
    receipt["release_build"] = {
        "run_id": run["id"], "head_sha": run["head_sha"], "head_branch": run["head_branch"],
        "event": run["event"], "conclusion": run["conclusion"], "workflow_path": run["path"],
        "run_url": run["html_url"], "artifact_id": artifact["id"], "artifact_name": artifact["name"],
        "artifact_digest": metadata_digest, "download_sha256": checksum,
        "archive_path": str(archive_path), "compared_files": compared,
        "compared_file_count": len(compared),
        "evidence_kind": "GitHub Actions run metadata and matching artifact payloads",
        "cryptographic_build_attestation_verified": False,
    }


def check_source_versions(sha):
    tree = command(["git", "ls-tree", "-r", "--name-only", sha, "--", "apps"]).decode().splitlines()
    manifests = ["mix.exs", *(name for name in tree if re.fullmatch(r"apps/[^/]+/mix\.exs", name))]
    require(len(manifests) == 7, "exact-source own manifest cohort differs")
    for name in manifests:
        data = command(["git", "show", f"{sha}:{name}"]).decode()
        require(re.findall(r'\bversion:\s*"([^"\n]+)"', data) == [VERSION],
                f"publication source version differs: {name}")
    # The vendored app keeps its upstream source version; the stager supplies VERSION.
    vendor = command(["git", "show", f"{sha}:vendor/websock_adapter/mix.exs"]).decode()
    require(re.findall(r'\bapp:\s*:([a-z_][a-z0-9_]*)', vendor) == ["websock_adapter"],
            "vendored adapter source app differs")


def verify(sha, output, receipt, downloaded_assets=None):
    require(command(["git", "rev-parse", f"{sha}^{{commit}}" ]).decode().strip() == sha,
            "expected source commit is unavailable locally")
    check_source_versions(sha)
    dependency_versions = expected_runtime_versions(sha)
    receipt["source_dependencies"] = dependency_versions
    receipt["hell_source_to_hex"] = {"git_url": HELL_URL, "source_ref": HELL_REF,
                                      "hex_version": PINNED_VERSIONS["hell"]}
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
    if downloaded_assets is None:
        args = ["gh", "release", "download", TAG, "--repo", REPO, "--dir", str(output)]
        for name in sorted(EXPECTED):
            args += ["--pattern", name]
        command(args, timeout=180)
    else:
        receipt["downloaded_assets_input"] = str(downloaded_assets)
        for name in sorted(EXPECTED):
            source = downloaded_assets / name
            require(source.is_file(), f"missing downloaded asset: {name}")
            shutil.copyfile(source, output / name)
    receipt["release_url"] = release["html_url"]
    receipt["assets"] = {}
    for name, asset in sorted(assets.items()):
        data = (output / name).read_bytes()
        checksum = digest(data)
        require(asset.get("digest") == f"sha256:{checksum}", f"GitHub digest differs: {name}")
        require(asset["size"] == len(data), f"GitHub asset size differs: {name}")
        receipt["assets"][name] = {"sha256": checksum, "bytes": len(data), "asset_id": asset["id"]}
    check_workflow_artifact(sha, output, receipt)
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
    receipt["package_source_file_count"] = sum(
        package["source_file_count"] for package in receipt["packages"].values())
    receipt["standalone"] = check_standalone(output / STANDALONE, dependency_versions)
    require(tag_sha() == sha, "remote tag changed during verification")
    receipt["status"] = "PASS"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="explicit published version without v prefix")
    parser.add_argument("--sha", required=True, help="full exact published source commit")
    parser.add_argument("--downloaded-assets", type=Path,
                        help="reuse previously downloaded assets; all remote metadata, checksum and source checks still run")
    args = parser.parse_args()
    configure(args.version)
    require(re.fullmatch(r"[0-9a-f]{40}", args.sha), "--sha must be a full lowercase commit SHA")
    output = Path(tempfile.mkdtemp(prefix="public-artifacts-", dir=Path(__file__).resolve().parent))
    receipt = {"status": "FAIL", "repo": REPO, "version": VERSION, "tag": TAG,
               "source_commit": args.sha, "source_root": str(ROOT),
               "verifier_sha256": digest(Path(__file__).read_bytes()), "output_directory": str(output),
               "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    try:
        verify(args.sha, output, receipt, args.downloaded_assets)
    except Exception as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
    receipt["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    write_json(output / "receipt.json", receipt)
    print(json.dumps({"status": receipt["status"], "receipt": str(output / "receipt.json"),
                      "error": receipt.get("error")}, sort_keys=True), flush=True)
    return 0 if receipt["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
