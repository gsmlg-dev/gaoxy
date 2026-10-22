#!/usr/bin/env python3
"""Offline negative controls for the public dependency read-back checks."""
import copy
import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("verifier", HERE / "verify-public-artifacts.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)
SHA = "55ed97d2b05ba2a8dd7c911472833e71dd6b87f7"


class Checks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="offline-check-", dir=HERE)
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "standalone.tar.gz"
        self.versions = {name: "0.21.16" for name in verifier.RUNTIME_DEPENDENCIES}

    def archive(self, change=None):
        versions = {name: verifier.VERSION for name in
                    ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server")}
        versions.update(self.versions)
        release = '{release,{"gaoxy","0.12.2"},{erts,"16.4"},[' + ','.join(
            '{%s,"%s",permanent}' % item for item in versions.items()) + ']}.'
        files = {"releases/start_erl.data": b"16.4 0.12.2",
                 "releases/0.12.2/gaoxy.rel": release.encode()}
        for app, version in versions.items():
            deps = {"gaoxy_http": "kernel,http_core", "gaoxy_http3": "kernel,elixir_quic_http3"}.get(app, "kernel")
            files[f"lib/{app}-{version}/ebin/{app}.app"] = (
                '{application,%s,[{vsn,"%s"},{applications,[%s]}]}.' % (app, version, deps)).encode()
        if change:
            change(files)
        with tarfile.open(self.path, "w:gz") as archive:
            for name, data in files.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
        return verifier.check_standalone(self.path, self.versions)

    def test_exact_source_dependencies(self):
        self.assertEqual(verifier.expected_runtime_versions(SHA), self.versions)

    def test_valid_standalone(self):
        result = self.archive()
        self.assertTrue(result["hpax_absent"])
        self.assertEqual(len(result["dependencies"]), 7)
        self.assertEqual(result["runtime_application_metadata_count"], 12)

    def test_reject_hpax_directory(self):
        with self.assertRaisesRegex(ValueError, "HPAX runtime directory"):
            self.archive(lambda files: files.update({"lib/hpax-1.1.0/ebin/extra.beam": b"payload"}))

    def test_reject_hpax_in_other_application_metadata(self):
        with self.assertRaisesRegex(ValueError, "HPAX remains"):
            self.archive(lambda files: files.update({"lib/other-1.0/ebin/other.app": b"{applications,[hpax]}."}))

    def test_reject_hpax_in_release_metadata(self):
        def change(files):
            files["releases/0.12.2/gaoxy.rel"] += b' {hpax,"1.1.0",permanent}.'
        with self.assertRaisesRegex(ValueError, "HPAX remains"):
            self.archive(change)

    def test_reject_missing_quic_runtime(self):
        with self.assertRaisesRegex(ValueError, "missing regular archive member"):
            self.archive(lambda files: files.pop("lib/elixir_quic-0.21.16/ebin/elixir_quic.app"))

    def test_reject_stale_core_runtime(self):
        def change(files):
            files["lib/http_core-0.21.16/ebin/http_core.app"] = b'{vsn,"0.21.14"}.'
        with self.assertRaisesRegex(ValueError, "dependency .app version differs"):
            self.archive(change)

    def test_reject_http_missing_direct_core_dependency(self):
        def change(files):
            path = "lib/gaoxy_http-0.12.2/ebin/gaoxy_http.app"
            files[path] = files[path].replace(b"kernel,http_core", b"kernel")
        with self.assertRaisesRegex(ValueError, "lacks runtime dependency"):
            self.archive(change)

    def test_valid_hex_floor(self):
        metadata = {"requirements": {"http_core": {"app": "http_core", "optional": False,
                    "requirement": verifier.HTTP_CORE_REQUIREMENT}}}
        self.assertEqual(verifier.check_hex_requirements(metadata, "gaoxy_http"), metadata["requirements"])

    def test_reject_hex_without_floor(self):
        metadata = {"requirements": {"http_core": {"app": "http_core", "optional": False,
                    "requirement": "~> 0.21"}}}
        with self.assertRaisesRegex(ValueError, "wrong required http_core floor"):
            verifier.check_hex_requirements(metadata, "gaoxy_http")

    def test_reject_hpax_in_any_package_requirements(self):
        with self.assertRaisesRegex(ValueError, "HPAX remains"):
            verifier.check_hex_requirements({"requirements": {"hpax": {}}}, "gaoxy_proxy")

    def test_reject_hpax_manifest(self):
        with self.assertRaisesRegex(ValueError, "HPAX remains"):
            verifier.require_no_hpax('deps: [{:hpax, "~> 1.1"}]', "manifest")


if __name__ == "__main__":
    unittest.main(verbosity=2)
