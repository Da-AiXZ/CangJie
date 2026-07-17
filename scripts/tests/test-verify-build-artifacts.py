#!/usr/bin/env python3
import hashlib
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "scripts" / "verify-build-artifacts.py"
MAIN_BUNDLE = "com.juyang.CangJie"
PROBE_BUNDLE = "com.juyang.CangJie.KeychainIsolationProbe"
CANDIDATE_ID = "a" * 64
COMMIT = "b" * 40


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class VerifyBuildArtifactsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.artifacts = []
        self._add_artifact("main", "CangJie-M0", "CangJie", MAIN_BUNDLE)
        self._add_artifact(
            "keychainIsolationProbe",
            "CangJie-Keychain-Isolation-Probe",
            "CangJieKeychainIsolationProbe",
            PROBE_BUNDLE,
        )
        self.manifest = {
            "schemaVersion": 5,
            "candidateSetID": CANDIDATE_ID,
            "commit": COMMIT,
            "build": "28",
            "runId": "123456",
            "runAttempt": "2",
            "runNumber": "28",
            "artifacts": self.artifacts,
            "acceptance": {
                "status": "blocked-pending-trollstore-device-keychain-isolation-validation",
                "failClosed": True,
            },
        }
        self.write_manifest()

    def tearDown(self):
        self.temp.cleanup()

    def _add_artifact(self, role, stem, executable, bundle_id):
        ipa = self.root / f"{stem}.ipa"
        info = {
            "CFBundleExecutable": executable,
            "CFBundleIdentifier": bundle_id,
            "CFBundleVersion": "28",
            "CFBundleShortVersionString": "1.0",
            "CangJieGitCommit": COMMIT[:12],
            "CangJieExecutableFingerprint": hashlib.sha256(
                f"cangjie-executable-v1|{role}|{bundle_id}|1.0|28|{COMMIT}|{CANDIDATE_ID}".encode()
            ).hexdigest(),
            "CangJieCandidateSetID": CANDIDATE_ID,
        }
        with zipfile.ZipFile(ipa, "w") as archive:
            archive.writestr(f"Payload/{executable}.app/Info.plist", plistlib.dumps(info))
            archive.writestr(f"Payload/{executable}.app/{executable}", b"mock executable")
        checksum = self.root / f"{stem}.sha256"
        checksum.write_text(f"{sha256(ipa)}  {ipa.name}\n", encoding="utf-8")
        contract = self.root / f"{stem}.entitlements"
        entitlements = {
            "application-identifier": bundle_id,
            "keychain-access-groups": [bundle_id],
        }
        contract.write_bytes(plistlib.dumps(entitlements))
        signed = self.root / f"{stem}.signed-entitlements.plist"
        signed.write_bytes(plistlib.dumps(entitlements))
        self.artifacts.append(
            {
                "role": role,
                "file": ipa.name,
                "sha256": sha256(ipa),
                "checksumFile": checksum.name,
                "bundleIdentifier": bundle_id,
                "productName": executable,
                "executable": executable,
                "compiledIdentity": {
                    "version": "1.0",
                    "build": "28",
                    "commit": COMMIT,
                    "fingerprint": info["CangJieExecutableFingerprint"],
                    "candidateSetID": CANDIDATE_ID,
                },
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
                    "signedExecutableSHA256": hashlib.sha256(b"mock executable").hexdigest(),
                    "entitlementContractFile": contract.name,
                    "entitlementContractSHA256": sha256(contract),
                    "signedEntitlementsFile": signed.name,
                    "signedEntitlementsSHA256": sha256(signed),
                    "appleDeveloperCertificate": False,
                    "provisioningProfile": False,
                    "appleTeamIdentifier": None,
                    "contract": "trollstore-prefixless-bundle-id",
                    "entitlements": entitlements,
                },
            }
        )

    def write_manifest(self):
        (self.root / "candidate-set-manifest.json").write_text(
            json.dumps(self.manifest), encoding="utf-8"
        )

    def run_verifier(self):
        return subprocess.run(
            [sys.executable, str(VERIFIER), str(self.root), "--metadata-only"],
            text=True,
            capture_output=True,
        )

    def assert_rejected(self, message):
        self.write_manifest()
        result = self.run_verifier()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)

    def test_accepts_complete_consistent_candidate_set(self):
        result = self.run_verifier()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_rejects_schema_four(self):
        self.manifest["schemaVersion"] = 4
        self.assert_rejected("manifest schema mismatch")

    def test_rejects_missing_probe(self):
        self.manifest["artifacts"] = self.artifacts[:1]
        self.assert_rejected("artifact roles mismatch")

    def test_rejects_shared_keychain_group(self):
        self.artifacts[1]["signing"]["entitlements"]["keychain-access-groups"] = [MAIN_BUNDLE]
        self.assert_rejected("entitlement isolation mismatch")

    def test_rejects_candidate_id_mismatch(self):
        self.artifacts[1]["compiledIdentity"]["candidateSetID"] = "c" * 64
        self.assert_rejected("candidate set binding mismatch")

    def test_rejects_run_build_binding_mismatch(self):
        self.artifacts[1]["compiledIdentity"]["build"] = "29"
        self.assert_rejected("build binding mismatch")

    def test_rejects_embedded_profile(self):
        probe = self.root / self.artifacts[1]["file"]
        with zipfile.ZipFile(probe, "a") as archive:
            archive.writestr(
                "Payload/CangJieKeychainIsolationProbe.app/embedded.mobileprovision",
                b"forbidden",
            )
        self.artifacts[1]["sha256"] = sha256(probe)
        (self.root / self.artifacts[1]["checksumFile"]).write_text(
            f"{sha256(probe)}  {probe.name}\n", encoding="utf-8"
        )
        self.assert_rejected("embedded provisioning profile")

    def test_rejects_signed_entitlements_not_exact(self):
        signed = self.root / self.artifacts[1]["signing"]["signedEntitlementsFile"]
        signed.write_bytes(plistlib.dumps({"application-identifier": PROBE_BUNDLE}))
        self.artifacts[1]["signing"]["signedEntitlementsSHA256"] = sha256(signed)
        self.assert_rejected("signed entitlement mismatch")

    def test_rejects_non_fail_closed_acceptance(self):
        self.manifest["acceptance"]["failClosed"] = False
        self.assert_rejected("acceptance gate mismatch")


if __name__ == "__main__":
    unittest.main()
