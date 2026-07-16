import hashlib
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "scripts" / "verify-build-artifacts.py"


class VerifyBuildArtifactsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.ipa = self.root / "CangJie-M0.ipa"
        self.ipa.write_bytes(b"candidate ipa")
        self.ipa_sha = hashlib.sha256(self.ipa.read_bytes()).hexdigest()
        (self.root / "CangJie-M0.sha256").write_text(
            f"{self.ipa_sha}  CangJie-M0.ipa\n", encoding="utf-8"
        )
        self.entitlements = self.root / "CangJie.entitlements"
        self.entitlements.write_bytes(
            plistlib.dumps(
                {
                    "application-identifier": "com.juyang.CangJie",
                    "keychain-access-groups": ["com.juyang.CangJie"],
                }
            )
        )
        self.entitlements_sha = hashlib.sha256(self.entitlements.read_bytes()).hexdigest()
        self.manifest = {
            "schemaVersion": 4,
            "artifact": "CangJie-M0.ipa",
            "sha256": self.ipa_sha,
            "bundleIdentifier": "com.juyang.CangJie",
            "signing": {
                "type": "trollstore-fakesign",
                "signer": "ldid",
                "ldid": {
                    "tag": "v2.1.5-procursus7",
                    "asset": "ldid_macosx_arm64",
                    "sha256": "5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50",
                    "architecture": "arm64",
                },
                "unsignedExecutableSHA256": "1" * 64,
                "signedExecutableSHA256": "2" * 64,
                "entitlementContractSHA256": self.entitlements_sha,
                "appleDeveloperCertificate": False,
                "provisioningProfile": False,
                "appleTeamIdentifier": None,
                "contract": "trollstore-prefixless-bundle-id",
                "entitlements": {
                    "application-identifier": "com.juyang.CangJie",
                    "keychain-access-groups": ["com.juyang.CangJie"],
                },
            },
            "acceptance": {
                "status": "blocked-pending-trollstore-device-keychain-validation",
                "failClosed": True,
            },
        }
        self.write_manifest()

    def tearDown(self):
        self.temp.cleanup()

    def write_manifest(self):
        (self.root / "build-manifest.json").write_text(
            json.dumps(self.manifest), encoding="utf-8"
        )

    def run_verifier(self):
        return subprocess.run(
            [sys.executable, str(VERIFIER), str(self.root), str(self.entitlements)],
            text=True,
            capture_output=True,
        )

    def test_accepts_complete_consistent_artifacts(self):
        result = self.run_verifier()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_rejects_manifest_ipa_hash_mismatch(self):
        self.manifest["sha256"] = "0" * 64
        self.write_manifest()
        result = self.run_verifier()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("manifest IPA SHA-256 mismatch", result.stderr)

    def test_rejects_empty_ldid_metadata(self):
        self.manifest["signing"]["ldid"]["asset"] = ""
        self.write_manifest()
        result = self.run_verifier()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ldid metadata mismatch", result.stderr)

    def test_rejects_non_fail_closed_acceptance(self):
        self.manifest["acceptance"]["failClosed"] = False
        self.write_manifest()
        result = self.run_verifier()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("acceptance gate mismatch", result.stderr)


if __name__ == "__main__":
    unittest.main()
