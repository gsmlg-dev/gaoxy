#!/usr/bin/env python3
"""Scoped, offline regressions for the reproducible Hex package staging tool."""

import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/stage-hex-packages.exs"
PACKAGES = {
    "gaoxy_websock_adapter": "vendor/websock_adapter",
    "gaoxy": "apps/gaoxy",
    "gaoxy_http": "apps/gaoxy_http",
    "gaoxy_http3": "apps/gaoxy_http3",
    "gaoxy_proxy": "apps/gaoxy_proxy",
    "gaoxy_test": "apps/gaoxy_test",
}
VERSION = "9.8.7"
ENV = {**os.environ, "ELIXIR_ERL_OPTIONS": "+S 2:2", "MIX_ENV": "prod"}
REQUIREMENTS = {
    "gaoxy_websock_adapter": {
        "websock": ("websock", "~> 0.5", False),
        "plug": ("plug", "~> 1.14", False),
        "bandit": ("bandit", ">= 0.6.0", True),
        "plug_cowboy": ("plug_cowboy", "~> 2.6", True),
    },
    "gaoxy": {
        "hell": ("hell", "== 0.1.2", False),
        "abyss": ("abyss", "== 0.10.0", False),
        "telemetry": ("telemetry", "~> 1.3", False),
    },
    "gaoxy_http": {
        "gaoxy": ("gaoxy", f"== {VERSION}", False),
        "plug": ("plug", "== 1.20.3", False),
        "http_core": ("http_core", "~> 0.21 and >= 0.21.17", False),
        "websock": ("websock", "== 0.5.3", False),
        "gaoxy_websock_adapter": ("websock_adapter", f"== {VERSION}", False),
    },
    "gaoxy_http3": {
        "gaoxy_http": ("gaoxy_http", f"== {VERSION}", False),
        "elixir_quic_http3": ("elixir_quic_http3", "~> 0.21", False),
    },
    "gaoxy_proxy": {
        "gaoxy": ("gaoxy", f"== {VERSION}", False),
        "gaoxy_http": ("gaoxy_http", f"== {VERSION}", False),
        "http_fetch": ("http_fetch", "~> 0.21", False),
        "http_web_socket": ("http_web_socket", "~> 0.21", False),
    },
    "gaoxy_test": {
        "gaoxy_http": ("gaoxy_http", f"== {VERSION}", False),
        "gaoxy_http3": ("gaoxy_http3", f"== {VERSION}", True),
        "plug": ("plug", "== 1.20.3", False),
    },
}


def snapshot(directory):
    return {
        str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in directory.rglob("*") if path.is_file()
    }


class StageHexPackagesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="gaoxy-hex-test-")
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name) / "source"
        self.output = Path(self.temporary.name) / "packages"
        self.source.mkdir()
        (self.source / "mix.exs").write_text('''defmodule PackagingFixture.MixProject do
  use Mix.Project
  def project, do: [apps_path: "apps", version: "9.8.7", package: [licenses: ["Apache-2.0"]]]
end
''')
        (self.source / "LICENSE").write_bytes(b"Explicit test fixture license\n")
        shutil.copyfile(ROOT / "README.md", self.source / "README.md")
        for name, relative in PACKAGES.items():
            destination = self.source / relative
            destination.mkdir(parents=True)
            for child in (ROOT / relative).iterdir():
                if child.name in ["lib", "priv"]:
                    shutil.copytree(child, destination / child.name)
                elif child.is_file():
                    shutil.copyfile(child, destination / child.name)
            if name != "gaoxy_websock_adapter":
                manifest = destination / "mix.exs"
                manifest.write_text(re.sub(r'version: "[^"]+"', f'version: "{VERSION}"', manifest.read_text()))
        (self.source / "apps/gaoxy/priv").mkdir()
        (self.source / "apps/gaoxy/priv/payload.bin").write_bytes(bytes(range(256)))

    def stage(self):
        return subprocess.run(
            ["elixir", str(SCRIPT), str(self.source), str(self.output)],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=ENV, timeout=30,
        )

    def metadata(self, data):
        path = Path(self.temporary.name) / "metadata.config"
        path.write_bytes(data)
        code = '''
{:ok, terms} = :file.consult(String.to_charlist(hd(System.argv())))
convert = fn
  values, recur when is_list(values) ->
    if values != [] and Enum.all?(values, &match?({_, _}, &1)) do
      Map.new(values, fn {key, value} -> {key, recur.(value, recur)} end)
    else
      Enum.map(values, &recur.(&1, recur))
    end
  value, _recur -> value
end
IO.puts(JSON.encode!(convert.(terms, convert)))
'''
        result = subprocess.run(
            ["elixir", "-e", code, str(path)], env=ENV, timeout=30,
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        return json.loads(result.stdout)

    def test_builds_all_packages_with_exact_metadata_and_unchanged_payloads(self):
        before = snapshot(self.source)
        result = self.stage()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(snapshot(self.source), before)
        self.assertEqual(set(path.name for path in self.output.iterdir()), set(PACKAGES))
        for name, relative in PACKAGES.items():
            with self.subTest(package=name):
                package = self.output / name
                source = self.source / relative
                readme = "README.gaoxy.md" if name == "gaoxy_websock_adapter" else "README.md"
                self.assertEqual((package / "README.md").read_bytes(), (source / readme).read_bytes())
                self.assertEqual(snapshot(package / "lib"), snapshot(source / "lib"))
                if (source / "priv").exists():
                    self.assertEqual(snapshot(package / "priv"), snapshot(source / "priv"))
                build = subprocess.run(
                    ["mix", "hex.build"], cwd=package, env=ENV, timeout=30,
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )
                self.assertEqual(build.returncode, 0, build.stdout)
                with tarfile.open(package / f"{name}-{VERSION}.tar") as archive:
                    metadata = self.metadata(archive.extractfile("metadata.config").read())
                    contents = tarfile.open(fileobj=io.BytesIO(archive.extractfile("contents.tar.gz").read()), mode="r:gz")
                    documents = {"README.md": source / readme}
                    if name == "gaoxy_websock_adapter":
                        documents["README.upstream.md"] = source / "README.md"
                        for filename in ["LICENSE", "GAOXY.md", "SOURCE.json", "gaoxy.patch", "CHANGELOG.md"]:
                            documents[filename] = source / filename
                    for filename, original in documents.items():
                        self.assertIn(filename, contents.getnames())
                        self.assertEqual(contents.extractfile(filename).read(), original.read_bytes())
                    for member in contents.getmembers():
                        if member.isfile():
                            self.assertEqual(contents.extractfile(member).read(), (package / member.name).read_bytes())
                    self.assertEqual(
                        {member.name for member in contents.getmembers() if member.isfile() and member.name.startswith(("lib/", "priv/"))},
                        {str(path.relative_to(package)) for folder in ["lib", "priv"] for path in (package / folder).rglob("*") if path.is_file()},
                    )
                self.assertEqual(metadata["version"], VERSION)
                self.assertEqual(metadata["name"], name)
                expected_app = "websock_adapter" if name == "gaoxy_websock_adapter" else name
                self.assertEqual(metadata["app"], expected_app)
                self.assertEqual(
                    {entry["name"]: (entry["app"], entry["requirement"], entry["optional"])
                     for entry in metadata["requirements"]}, REQUIREMENTS[name],
                )
                self.assertTrue(all(entry["repository"] == "hexpm" for entry in metadata["requirements"]))
                if name == "gaoxy_websock_adapter":
                    self.assertEqual(metadata["licenses"], ["MIT", "Apache-2.0"])
                    for filename in ["LICENSE", "GAOXY.md", "SOURCE.json", "gaoxy.patch", "CHANGELOG.md"]:
                        self.assertEqual((package / filename).read_bytes(), (source / filename).read_bytes())
                    self.assertEqual((package / "README.upstream.md").read_bytes(), (source / "README.md").read_bytes())
                else:
                    self.assertEqual((package / "LICENSE").read_bytes(), (self.source / "LICENSE").read_bytes())
                    self.assertEqual(metadata["licenses"], ["Apache-2.0"])
                manifest = (package / "mix.exs").read_text()
                for forbidden in ["in_umbrella:", "override:", "path:", "git:", "config_path:", "build_path:", "deps_path:", "lockfile:"]:
                    self.assertNotIn(forbidden, manifest)
                if name == "gaoxy":
                    self.assertIn('hell: "== 0.1.2"', manifest)
                    self.assertIn('abyss: "== 0.10.0"', manifest)
                    self.assertTrue({"abyss_raw", "rustler"}.isdisjoint(
                        entry["name"] for entry in metadata["requirements"]))
                if name == "gaoxy_http":
                    self.assertIn('hex: :gaoxy_websock_adapter', manifest)
                    self.assertIn(f'"== {VERSION}"', manifest)

    def test_rejects_changed_git_pin_without_staging_packages(self):
        manifest = self.source / "apps/gaoxy/mix.exs"
        manifest.write_text(manifest.read_text().replace("59eed42b019ca41413d1b8cd7a7dc3e344bb93ee", "unreviewed-revision"))
        result = self.stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported dependency", result.stdout)
        self.assertFalse(self.output.exists())

    def test_rejects_old_bundled_abyss_git_dependency_without_staging_packages(self):
        manifest = self.source / "apps/gaoxy/mix.exs"
        original = '''{:abyss,
         git: "https://github.com/gsmlg-dev/abyss.git",
         ref: "9b710e6480900e16e304f40e63623aff8c922e19"}'''
        content, count = re.subn(r"\{:abyss,.*?\}", original, manifest.read_text(), flags=re.DOTALL)
        self.assertEqual(count, 1)
        manifest.write_text(content)
        result = self.stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported dependency", result.stdout)
        self.assertFalse(self.output.exists())

    def test_rejects_unknown_path_dependency_without_staging_packages(self):
        manifest = self.source / "apps/gaoxy_http/mix.exs"
        manifest.write_text(manifest.read_text().replace("../../vendor/websock_adapter", "../../vendor/unreviewed_adapter"))
        result = self.stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported dependency", result.stdout)
        self.assertFalse(self.output.exists())

    def test_requires_license_file(self):
        (self.source / "LICENSE").unlink()
        result = self.stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("LICENSE", result.stdout)
        self.assertFalse(self.output.exists())

    def test_stages_test_http3_umbrella_dependency_as_optional(self):
        manifest = self.source / "apps/gaoxy_test/mix.exs"
        modified, count = re.subn(
            r"\{:gaoxy_http3,\s*in_umbrella: true[^}]*\}",
            "{:gaoxy_http3, in_umbrella: true}", manifest.read_text(),
        )
        self.assertEqual(count, 1)
        manifest.write_text(modified)
        result = self.stage()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn(
            f'{{:gaoxy_http3, "== {VERSION}", [optional: true]}}',
            (self.output / "gaoxy_test/mix.exs").read_text(),
        )

    def test_keeps_other_packages_http3_umbrella_dependency_required(self):
        manifest = self.source / "apps/gaoxy_proxy/mix.exs"
        original = "{:gaoxy_http, in_umbrella: true}"
        self.assertEqual(manifest.read_text().count(original), 1)
        manifest.write_text(manifest.read_text().replace(
            original, "{:gaoxy_http3, in_umbrella: true}"))
        result = self.stage()
        self.assertEqual(result.returncode, 0, result.stdout)
        staged = (self.output / "gaoxy_proxy/mix.exs").read_text()
        self.assertIn(f'gaoxy_http3: "== {VERSION}"', staged)
        self.assertNotIn("optional: true", staged)

    def test_rejects_unreviewed_internal_optional_options_before_output(self):
        manifest = self.source / "apps/gaoxy_test/mix.exs"
        original = manifest.read_text()
        for options in [
                "in_umbrella: true, optional: false",
                "in_umbrella: true, optional: true",
                "optional: true, in_umbrella: true",
                "in_umbrella: true, runtime: false",
                "in_umbrella: true, optional: true, override: true",
                "in_umbrella: true, optional: true, runtime: false",
                'in_umbrella: true, optional: true, path: "../gaoxy_http3"']:
            with self.subTest(options=options):
                modified, count = re.subn(
                    r"\{:gaoxy_http3,\s*in_umbrella: true[^}]*\}",
                    "{:gaoxy_http3, " + options + "}", original,
                )
                self.assertEqual(count, 1)
                manifest.write_text(modified)
                try:
                    result = self.stage()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("unsupported dependency", result.stdout)
                    self.assertFalse(self.output.exists())
                finally:
                    manifest.write_text(original)

    def test_requires_each_package_readme_before_staging_packages(self):
        for name, relative in PACKAGES.items():
            with self.subTest(package=name):
                filename = "README.gaoxy.md" if name == "gaoxy_websock_adapter" else "README.md"
                readme = self.source / relative / filename
                original = readme.read_bytes()
                readme.unlink()
                try:
                    result = self.stage()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(filename, result.stdout)
                    self.assertFalse(self.output.exists())
                finally:
                    readme.write_bytes(original)

    def test_requires_explicit_license_metadata(self):
        manifest = self.source / "mix.exs"
        manifest.write_text(manifest.read_text().replace('package: [licenses: ["Apache-2.0"]]', 'package: []'))
        result = self.stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("explicitly select package licenses", result.stdout)
        self.assertFalse(self.output.exists())

    def test_rejects_nonempty_output_without_overwriting_files(self):
        self.output.mkdir()
        existing = self.output / "user-file"
        existing.write_bytes(b"preserve this unrelated file")
        result = self.stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("output directory must be empty", result.stdout)
        self.assertEqual(existing.read_bytes(), b"preserve this unrelated file")
        self.assertEqual(list(self.output.iterdir()), [existing])

    def test_package_publish_dry_run_after_fetching_dependencies(self):
        # A tiny signed dependency registry exercises Hex's actual loadpaths check
        # without downloading dependencies or compiling runtime/native code.
        directory = Path(self.temporary.name)
        dependency = directory / "dependency"
        dependency.mkdir()
        (dependency / "mix.exs").write_text('''defmodule PublishDependency.MixProject do
  use Mix.Project
  def project, do: [app: :hex_publish_fixture, version: "1.0.0", deps: [],
    description: "Explicit publication regression fixture",
    package: [licenses: ["MIT"], links: %{"Fixture" => "https://example.invalid"}]]
end
''')
        (self.source / "apps/gaoxy/mix.exs").write_text(f'''defmodule Gaoxy.MixProject do
  use Mix.Project
  def project, do: [app: :gaoxy, version: "{VERSION}", elixir: "~> 1.18",
    deps: [{{:hex_publish_fixture, "== 1.0.0"}}]]
  def application, do: []
end
''')
        result = self.stage()
        self.assertEqual(result.returncode, 0, result.stdout)
        registry = directory / "registry"
        (registry / "tarballs").mkdir(parents=True)
        requests = []

        class Handler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=str(registry), **kwargs)

            def do_GET(self):
                requests.append(("GET", self.path))
                if self.path == "/api/users/me":
                    # Erlang external term encoding of %{"organizations" => []}.
                    body = b"\x83t\x00\x00\x00\x01m\x00\x00\x00\x0dorganizationsj"
                    self.send_response(200)
                    self.send_header("Content-Type", "application/vnd.hex+erlang")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                else:
                    super().do_GET()

            def do_POST(self):
                requests.append(("POST", self.path))
                self.send_error(500, "Publication forbidden in dry-run regression")

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}"
        env = {**ENV, "HEX_HOME": str(directory / "hex-home"),
               "HEX_API_URL": url + "/api", "HEX_API_KEY": "explicit-test-fixture-key"}

        def execute(command, cwd=directory):
            result = subprocess.run(command, cwd=cwd, env=env, timeout=30,
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            self.assertEqual(result.returncode, 0, result.stdout)
            return result.stdout

        try:
            execute(["mix", "hex.build", "--output", str(registry / "tarballs/hex_publish_fixture-1.0.0.tar")], dependency)
            key = directory / "registry-private.pem"
            execute(["openssl", "genrsa", "-out", str(key), "2048"])
            execute(["mix", "hex.registry", "build", str(registry), "--name=hexpm", "--private-key=" + str(key)])
            execute(["mix", "hex.repo", "set", "hexpm", "--url", url, "--public-key", str(registry / "public_key")])
            package = self.output / "gaoxy"
            before = snapshot(package)
            unfetched = subprocess.run(
                ["mix", "hex.publish", "package", "--dry-run", "--yes"],
                cwd=package, env=env, timeout=30, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertNotEqual(unfetched.returncode, 0)
            self.assertIn('run "mix deps.get"', unfetched.stdout)
            execute(["mix", "deps.get", "--only", "prod"], package)
            output = execute(["mix", "hex.publish", "package", "--dry-run", "--yes"], package)
            self.assertIn("Publishing package...", output)
            after = snapshot(package)
            self.assertEqual({path: after[path] for path in before}, before)
            self.assertFalse(list(package.rglob("*.beam")))
            self.assertIn(("GET", "/api/users/me"), requests)
            self.assertTrue(all(method == "GET" for method, _ in requests), requests)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=10)
            self.assertFalse(thread.is_alive())


if __name__ == "__main__":
    unittest.main()
