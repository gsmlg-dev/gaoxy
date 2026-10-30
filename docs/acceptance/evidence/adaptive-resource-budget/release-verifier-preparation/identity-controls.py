"""CLI identity controls; help never performs network or runtime work."""
import subprocess
import sys
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent

class ExplicitIdentity(unittest.TestCase):
    def test_public_verifier_requires_explicit_version_and_sha(self):
        result = subprocess.run([sys.executable, '-B', str(HERE / 'verify-public-artifacts.py'), '--help'], capture_output=True, text=True, check=True)
        self.assertIn('--version VERSION', result.stdout)
        self.assertIn('--sha SHA', result.stdout)

    def test_runtime_requires_version_sha_and_reviewed_verifier_digest(self):
        result = subprocess.run([sys.executable, '-B', str(HERE / 'downloaded-runtime.py'), '--help'], capture_output=True, text=True, check=True)
        self.assertIn('--version VERSION', result.stdout)
        self.assertIn('--sha SHA', result.stdout)
        self.assertIn('--artifact-verifier-sha256 ARTIFACT_VERIFIER_SHA256', result.stdout)

    def test_missing_version_rejected_before_public_queries(self):
        result = subprocess.run([sys.executable, '-B', str(HERE / 'verify-public-artifacts.py'), '--sha', '0' * 40], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('required: --version', result.stderr)

    def test_missing_runtime_digest_rejected_before_loading_receipt(self):
        result = subprocess.run([sys.executable, '-B', str(HERE / 'downloaded-runtime.py'), '--version', '0.14.0', '--sha', '0' * 40, '--artifact-receipt', '/never-read'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('required: --artifact-verifier-sha256', result.stderr)

if __name__ == '__main__':
    unittest.main(verbosity=2)
