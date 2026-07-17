#!/usr/bin/env python3
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CREATOR = ROOT / "scripts" / "create-candidate-set-manifest.py"
sys.path.insert(0, str(ROOT / "scripts"))
from candidate_set_identity import derive_build_version, derive_candidate_set_id, expected_fingerprint  # noqa: E402

COMMIT = "c" * 40
RUN_ID = "9001"
RUN_NUMBER = "28"
RUN_ATTEMPT = "2"
VERSION = "1.0"
BUILD = derive_build_version(RUN_NUMBER, RUN_ATTEMPT)
MAIN_BUNDLE = "com.juyang.CangJie"
PROBE_BUNDLE = "com.juyang.CangJie.KeychainIsolationProbe"
CANDIDATE = derive_candidate_set_id(
    commit=COMMIT,
    run_id=RUN_ID,
    run_attempt=RUN_ATTEMPT,
    run_number=RUN_NUMBER,
    version=VERSION,
    build=BUILD,
    main_bundle_id=MAIN_BUNDLE,
    probe_bundle_id=PROBE_BUNDLE,
)


class CreateCandidateSetManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.output = self.root / "candidate-set-manifest.json"
        self.main = self._artifact("main", MAIN_BUNDLE, "CangJie")
        self.probe = self._artifact(
            "keychainIsolationProbe",
            PROBE_BUNDLE,
            "CangJieKeychainIsolationProbe",
        )

    def tearDown(self):
        self.temp.cleanup()

    def _artifact(self, role, bundle, product):
        identity = {
            "schemaVersion": 1,
            "role": role,
            "bundleIdentifier": bundle,
            "version": VERSION,
            "build": BUILD,
            "commit": COMMIT,
            "visibleCommit": COMMIT[:12],
            "fingerprint": expected_fingerprint(role, bundle, VERSION, BUILD, COMMIT, CANDIDATE),
            "candidateSetID": CANDIDATE,
        }
        path = self.root / f"{role}.json"
        path.write_text(
            json.dumps(
                {
                    "role": role,
                    "bundleIdentifier": bundle,
                    "productName": product,
                    "executable": product,
                    "compiledIdentity": identity,
                }
            ),
            encoding="utf-8",
        )
        return path

    def run_creator(self, *, candidate=CANDIDATE, build=BUILD):
        return subprocess.run(
            [
                sys.executable,
                str(CREATOR),
                "--output",
                str(self.output),
                "--candidate-set-id",
                candidate,
                "--commit",
                COMMIT,
                "--version",
                VERSION,
                "--build",
                build,
                "--run-id",
                RUN_ID,
                "--run-attempt",
                RUN_ATTEMPT,
                "--run-number",
                RUN_NUMBER,
                "--artifact",
                str(self.main),
                "--artifact",
                str(self.probe),
            ],
            text=True,
            capture_output=True,
        )

    def test_writes_manifest_only_for_shared_derived_identity(self):
        result = self.run_creator()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(self.output.read_text(encoding="utf-8"))
        self.assertEqual(manifest["candidateSetID"], CANDIDATE)
        self.assertEqual(manifest["version"], VERSION)
        self.assertEqual(manifest["build"], BUILD)

    def test_rejects_candidate_set_not_derived_from_run_bindings(self):
        result = self.run_creator(candidate="d" * 64)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("candidate set derivation mismatch", result.stderr)
        self.assertFalse(self.output.exists())

    def test_rejects_old_run_number_only_build(self):
        result = self.run_creator(build=RUN_NUMBER)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("build", result.stderr)
        self.assertFalse(self.output.exists())

    def test_rejects_product_identity_drift(self):
        value = json.loads(self.probe.read_text(encoding="utf-8"))
        value["productName"] = "CangJie"
        self.probe.write_text(json.dumps(value), encoding="utf-8")
        result = self.run_creator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("artifact productName mismatch", result.stderr)
        self.assertFalse(self.output.exists())

    def test_rejects_mixed_artifact_marketing_versions(self):
        value = json.loads(self.probe.read_text(encoding="utf-8"))
        value["compiledIdentity"]["version"] = "1.1"
        self.probe.write_text(json.dumps(value), encoding="utf-8")
        result = self.run_creator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("compiled identity version mismatch", result.stderr)
        self.assertFalse(self.output.exists())

    def test_rejects_duplicate_artifact_metadata_keys(self):
        encoded = self.main.read_text(encoding="utf-8")
        self.main.write_text('{"role":"main",' + encoded[1:], encoding="utf-8")
        result = self.run_creator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate JSON key", result.stderr)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
