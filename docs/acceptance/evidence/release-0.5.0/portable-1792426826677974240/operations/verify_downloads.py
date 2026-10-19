#!/usr/bin/env python3
"""Compare fresh Gaoxy 0.5 downloads with qualified bytes; inspect without extracting."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import tarfile

VERSION = "0.5.0"
NAMES = ("gaoxy-0.5.0-linux-x86_64.tar.gz", "build-info.json", "SHA256SUMS")
APPLICATIONS = {name: VERSION for name in
                ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server")}
AUDIT = Path(__file__).resolve().parent
HELL = {"application": "hell", "version": "0.1.2",
        "source_url": "https://github.com/gsmlg-dev/hell.git",
        "git_sha": "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee",
        "root_lock_sha256": "9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777"}


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            result.update(block)
    return result.hexdigest()


def compare(original, downloaded):
    original_hash, downloaded_hash = hashlib.sha256(), hashlib.sha256()
    equal = True
    with original.open("rb") as left, downloaded.open("rb") as right:
        while True:
            a, b = left.read(1048576), right.read(1048576)
            original_hash.update(a)
            downloaded_hash.update(b)
            equal = equal and a == b
            if not a and not b:
                break
    return {"qualified_sha256": original_hash.hexdigest(),
            "download_sha256": downloaded_hash.hexdigest(),
            "qualified_bytes": original.stat().st_size,
            "download_bytes": downloaded.stat().st_size, "byte_equal": equal,
            "status": "PASS" if equal else "FAIL"}


def safe_name(name):
    path = PurePosixPath(name)
    require(bool(name) and not path.is_absolute() and ".." not in path.parts
            and "\\" not in name, f"unsafe archive path: {name!r}")
    return path.as_posix()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("qualified_artifacts", type=Path)
    parser.add_argument("fresh_downloads", type=Path)
    parser.add_argument("source_identity", type=Path)
    parser.add_argument("output_receipt", type=Path)
    args = parser.parse_args()
    qualified, downloads = args.qualified_artifacts.resolve(), args.fresh_downloads.resolve()
    identity_path, output = args.source_identity.resolve(), args.output_receipt.resolve()
    protected = {identity_path, *(qualified / name for name in NAMES),
                 *(downloads / name for name in NAMES)}
    if output in protected or output.exists():
        parser.error("output receipt must be a new path distinct from all input files")
    report = {"kind": "FRESH_RELEASE_DOWNLOAD_BYTE_AND_INVENTORY_VERIFICATION",
              "status": "FAIL", "started_at_utc": utc(),
              "qualified_artifacts": str(qualified), "fresh_downloads": str(downloads),
              "source_identity_path": str(identity_path), "files": {},
              "checks": {name: {"status": "NOT RUN"} for name in
                         ("identity", "file_set", "bytes", "checksums", "metadata", "archive")},
              "errors": [], "scope": "read-only download inspection; no remote, runtime or deployment claim"}
    stage = "identity"
    try:
        require(args.source_identity.is_file() and not args.source_identity.is_symlink(),
                "source identity must be a regular file, not a symlink")
        active_path = AUDIT / "active-run.json"
        require(active_path.is_file() and not active_path.is_symlink(),
                "active run must be a regular frozen-input pointer, not a symlink")
        active = json.loads(active_path.read_text())
        run_path = Path(active["run_directory"])
        require(run_path.is_absolute(), "frozen run directory must be absolute")
        context = run_path.resolve() / "context"
        frozen_identity_path = context / "source-identity.json"
        scope_path = context / "ordinary-scope.json"
        for path in (frozen_identity_path, scope_path):
            require(path.is_file() and not path.is_symlink(),
                    f"frozen input must be a regular file, not a symlink: {path}")
        require(identity_path == frozen_identity_path.resolve(),
                "supplied source identity differs from frozen active-run context")
        identity = json.loads(frozen_identity_path.read_text())
        require(identity["version"] == VERSION
                and re.fullmatch(r"[0-9a-f]{40}", identity["source_sha"])
                and identity["source_sha"] == active["source_sha"],
                "source identity version/SHA differs from frozen reviewed source")
        require(identity["root_lock_sha256"] == HELL["root_lock_sha256"],
                "frozen source lock differs from reviewed Hell provenance")
        scope_bytes = scope_path.read_bytes()
        scope = json.loads(scope_bytes)
        require(scope["version"] == identity["version"], "frozen ordinary scope version mismatch")
        scope_sha256 = hashlib.sha256(scope_bytes).hexdigest()
        expected_suites = [{"name": batch["name"], "command": batch["command"],
                            "applications": batch["applications"], "status": "PASS"}
                           for batch in scope["batches"]]
        report["frozen_inputs"] = {"active_run_path": str(active_path),
                                   "active_run_sha256": digest(active_path),
                                   "run_directory": str(run_path.resolve()),
                                   "ordinary_scope_path": str(scope_path),
                                   "ordinary_scope_sha256": scope_sha256}
        for field in ("source_archive_sha256", "root_lock_sha256"):
            require(re.fullmatch(r"[0-9a-f]{64}", identity[field]), f"invalid identity {field}")
        report["identity"] = identity
        report["source_identity_sha256"] = digest(identity_path)
        report["checks"][stage] = {"status": "PASS"}

        stage = "file_set"
        require(qualified != downloads, "downloads must be separate from qualified artifacts")
        entries = list(downloads.iterdir())
        require({p.name for p in entries} == set(NAMES), "downloads must contain exactly three release assets")
        for directory in (qualified, downloads):
            for name in NAMES:
                path = directory / name
                require(path.is_file() and not path.is_symlink(), f"missing/nonregular asset: {path}")
        report["checks"][stage] = {"status": "PASS", "names": list(NAMES)}

        stage = "bytes"
        for name in NAMES:
            report["files"][name] = compare(qualified / name, downloads / name)
        require(all(row["byte_equal"] and row["qualified_sha256"] == row["download_sha256"]
                    for row in report["files"].values()), "fresh asset bytes differ from qualified originals")
        report["checks"][stage] = {"status": "PASS", "files": len(NAMES)}

        stage = "checksums"
        lines = (downloads / "SHA256SUMS").read_text().splitlines()
        require(len(lines) == 2, "SHA256SUMS must contain exactly two entries")
        sums = {}
        for line in lines:
            parsed = re.fullmatch(r"([0-9a-f]{64})  (gaoxy-0\.5\.0-linux-x86_64\.tar\.gz|build-info\.json)", line)
            require(parsed is not None, "invalid checksum entry")
            value, name = parsed.groups()
            require(name not in sums, "duplicate checksum entry")
            sums[name] = value
        require(set(sums) == set(NAMES[:2]), "checksum asset names mismatch")
        require(all(sums[name] == report["files"][name]["download_sha256"] for name in sums),
                "download checksums mismatch")
        report["checks"][stage] = {"status": "PASS", "entries": sums}

        stage = "metadata"
        info = json.loads((downloads / "build-info.json").read_text())
        report["metadata"] = {key: info[key] for key in
                              ("version", "source_sha", "source_archive_sha256", "root_lock_sha256",
                               "platform", "applications", "archive_entries", "compatibility_tests",
                               "compatibility_failures", "ordinary_suites", "packaged_websocket_profiles", "formatter_scope",
                               "hell_provenance")}
        for field in ("version", "source_sha", "source_archive_sha256", "root_lock_sha256"):
            require(info[field] == identity[field], f"metadata identity mismatch: {field}")
        require(info["platform"] == "linux/amd64", "platform must be Linux x86_64")
        require(info["applications"] == APPLICATIONS, "metadata must declare all five own apps at 0.5.0")
        require(info["archive_sha256"] == sums[NAMES[0]], "metadata archive SHA mismatch")
        require(info["ordinary_scope_sha256"] == scope_sha256, "ordinary scope hash mismatch")
        require(info["ordinary_suites"] == expected_suites, "ordinary commands/counts differ from reviewed scope")
        require(info["hell_provenance"] == HELL, "metadata Hell provenance differs from reviewed pin")
        changed = identity["changed_elixir_paths"]
        prefix = "docs/acceptance/evidence/"
        current = [name for name in changed if not name.startswith(prefix)]
        historical = [name for name in changed if name.startswith(prefix)]
        require(current and len(changed) == len(set(changed)), "empty/duplicate formatter identity")
        formatter = {"historical_prefix": prefix,
                     "path_hash_encoding": "UTF-8 compact JSON array in source identity order",
                     "changed_count": len(changed), "current_count": len(current),
                     "excluded_historical_count": len(historical)}
        for label, paths in (("changed", changed), ("current", current), ("excluded_historical", historical)):
            formatter[f"{label}_paths_sha256"] = hashlib.sha256(
                json.dumps(paths, separators=(",", ":")).encode()).hexdigest()
        require(info["formatter_scope"] == formatter, "formatter scope differs from full source identity")
        actual = sum(row["executed"] for suite in info["ordinary_suites"]
                     for row in suite["applications"].values())
        totals = {field: sum(row[field] for suite in info["ordinary_suites"]
                             for row in suite["applications"].values())
                  for field in ("executed", "excluded", "skipped", "failures")}
        require(totals == {"executed": 210, "excluded": 144, "skipped": 0, "failures": 0},
                "ordinary counts must be 210 executed, 144 excluded, zero skips/failures")
        require(actual > 0 and info["compatibility_tests"] == actual
                and info["compatibility_failures"] == 0, "zero/mismatched/failing ordinary execution")
        checks = info["checks"]
        require(bool(checks) and all(row["exit_code"] == 0 for row in checks), "missing or failing build checks")
        for suite in expected_suites:
            rows = [row for row in checks if row["name"] == suite["name"]]
            require(len(rows) == 1 and rows[0]["command"] == suite["command"], "ordinary command receipt mismatch")
        hell_startup = [row for row in checks if row["name"] == "packaged-hell-startup"]
        require(len(hell_startup) == 1 and hell_startup[0]["exit_code"] == 0,
                "missing/duplicate/failing packaged Hell startup check")
        profiles = info["packaged_websocket_profiles"]
        require([row["protocol"] for row in profiles] == ["h2", "h2c", "h3"], "missing/duplicate WS profile")
        for row in profiles:
            require(row["status"] == "PASS" and row["executed"] == 15 and row["failures"] == 0,
                    "packaged WebSocket profile must record 15 executed, zero failures and PASS")
            require(re.fullmatch(r"[0-9a-f]{64}", row["report_sha256"]), "invalid WS report digest")
            safe_name(row["report"])
        require((info["core_transports"], info["gateway_exchanges"], info["h3_checks"]) == (3, 2, 3),
                "packaged ordinary smoke counts mismatch")
        report["checks"][stage] = {"status": "PASS", "ordinary_suites": info["ordinary_suites"],
                                   "ordinary_totals": totals, "hell_provenance": HELL,
                                   "packaged_hell_startup": hell_startup[0],
                                   "packaged_websocket_profiles": profiles,
                                   "external_profile_reports": "not required; qualified metadata bytes verified"}

        stage = "archive"
        inventory, seen, own_apps, start_data, elf_files = [], set(), {}, [], []
        hell_version, gaoxy_dependencies = None, None
        with tarfile.open(downloads / NAMES[0], mode="r:gz") as archive:
            for member in archive.getmembers():
                require(member.isfile() or member.isdir(), f"link/special archive entry: {member.name}")
                normalized = safe_name(member.name)
                require(normalized not in seen, f"duplicate archive path: {normalized}")
                seen.add(normalized)
                inventory.append({"name": normalized, "type": "file" if member.isfile() else "directory",
                                  "bytes": member.size})
                require(not normalized.endswith("/ebin/thousand_island.app"),
                        "archive contains old Thousand Island application")
                if normalized.endswith("/ebin/hell.app"):
                    require(member.isfile() and hell_version is None,
                            "Hell application metadata must occur exactly once as a regular file")
                    content = archive.extractfile(member).read().decode()
                    versions = re.findall(r'\{vsn,\s*"([^"]+)"\}', content)
                    require(versions == [HELL["version"]], "wrong Hell application version")
                    hell_version = versions[0]
                if not member.isfile():
                    continue
                for app in APPLICATIONS:
                    if normalized.endswith(f"/ebin/{app}.app"):
                        require(app not in own_apps, f"duplicate app metadata: {app}")
                        content = archive.extractfile(member).read().decode()
                        versions = re.findall(r'\{vsn,\s*"([^"]+)"\}', content)
                        require(versions == [VERSION], f"wrong app version: {app}")
                        own_apps[app] = versions[0]
                        if app == "gaoxy":
                            dependencies = re.findall(r'\{applications,\s*\[([^\]]*)\]\}', content)
                            require(len(dependencies) == 1, "missing/duplicate Gaoxy applications metadata")
                            gaoxy_dependencies = re.findall(r'[a-z][a-z0-9_]*', dependencies[0])
                            require("hell" in gaoxy_dependencies
                                    and "thousand_island" not in gaoxy_dependencies,
                                    "Gaoxy application dependencies must include Hell and exclude Thousand Island")
                if normalized == "releases/start_erl.data":
                    start_data = archive.extractfile(member).read().decode().split()
                with archive.extractfile(member) as stream:
                    header = stream.read(20)
                if header.startswith(b"\x7fELF"):
                    require(len(header) == 20 and header[4:6] == b"\x02\x01"
                            and struct.unpack("<H", header[18:20])[0] == 62,
                            f"non-x86_64 ELF object: {normalized}")
                    elf_files.append(normalized)
        require(inventory and len(inventory) == info["archive_entries"], "archive inventory count mismatch")
        require(own_apps == APPLICATIONS, "archive must contain all five app versions")
        require(hell_version == HELL["version"], "archive must contain exactly one Hell 0.1.2 application")
        require(len(start_data) == 2 and start_data[1] == VERSION, "start_erl.data release version mismatch")
        require(bool(elf_files), "archive contains no x86_64 ELF object")
        report["checks"][stage] = {"status": "PASS", "entries": len(inventory),
                                   "regular_files": sum(row["type"] == "file" for row in inventory),
                                   "directories": sum(row["type"] == "directory" for row in inventory),
                                   "inventory_sha256": hashlib.sha256(json.dumps(inventory, sort_keys=True).encode()).hexdigest(),
                                   "application_versions": own_apps, "start_erl_data": start_data,
                                   "hell": {"application": "hell", "version": hell_version,
                                            "gaoxy_applications": gaoxy_dependencies,
                                            "thousand_island_application_present": False},
                                   "elf_x86_64_count": len(elf_files), "elf_paths": elf_files,
                                   "extracted_or_executed": False}
        report["status"] = "PASS"
    except Exception as error:
        report["checks"][stage] = {"status": "FAIL", "error": f"{type(error).__name__}: {error}"}
        report["errors"].append({"stage": stage, "error": f"{type(error).__name__}: {error}"})
    finally:
        report["completed_at_utc"] = utc()
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("x") as stream:
            stream.write(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "receipt": str(output), "errors": report["errors"]}))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
