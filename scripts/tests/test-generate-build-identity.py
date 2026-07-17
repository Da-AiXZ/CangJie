#!/usr/bin/env python3
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "scripts" / "generate-build-identity.py"
COMMIT = "0123456789abcdef0123456789abcdef01234567"
CANDIDATE = "abcdef" * 10 + "abcd"


class GenerateBuildIdentityTests(unittest.TestCase):
    def run_generator(self, root: Path, **overrides):
        values = {
            "role": "main",
            "bundle_id": "com.juyang.CangJie",
            "version": "1.0",
            "build": "28",
            "commit": COMMIT,
            "candidate_set_id": CANDIDATE,
            "swift_output": str(root / "GeneratedBuildIdentity.swift"),
            "c_output": str(root / "GeneratedBuildIdentityMarker.c"),
            "metadata_output": str(root / "identity.json"),
        }
        values.update(overrides)
        args = [sys.executable, str(GENERATOR)]
        for key, value in values.items():
            args += ["--" + key.replace("_", "-"), value]
        return subprocess.run(args, text=True, capture_output=True)

    def test_generates_deterministic_swift_and_metadata_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.run_generator(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            swift = (root / "GeneratedBuildIdentity.swift").read_text(encoding="utf-8")
            metadata_bytes = (root / "identity.json").read_bytes()
            metadata = json.loads(metadata_bytes)
            c_source = (root / "GeneratedBuildIdentityMarker.c").read_text(encoding="utf-8")
            expected = hashlib.sha256(
                f"cangjie-executable-v1|main|com.juyang.CangJie|1.0|28|{COMMIT}|{CANDIDATE}".encode()
            ).hexdigest()
            self.assertIn('static let build = "28"', swift)
            self.assertIn(f'static let commit = "{COMMIT[:12]}"', swift)
            self.assertIn(f'static let fingerprint = "{expected}"', swift)
            self.assertIn(f'static let candidateSetID = "{CANDIDATE}"', swift)
            self.assertEqual(metadata["fingerprint"], expected)
            import base64
            canonical = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
            encoded = base64.urlsafe_b64encode(canonical).decode("ascii").rstrip("=")
            self.assertIn("__TEXT,__cjidentity", c_source)
            self.assertIn(f"CANGJIE_IDENTITY_V1:{encoded}", c_source)
            before = (root / "GeneratedBuildIdentity.swift").read_bytes()
            c_before = (root / "GeneratedBuildIdentityMarker.c").read_bytes()
            result = self.run_generator(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "GeneratedBuildIdentity.swift").read_bytes(), before)
            self.assertEqual((root / "GeneratedBuildIdentityMarker.c").read_bytes(), c_before)
            self.assertFalse(list(root.glob("*.tmp")))

    def test_rejects_invalid_commit_without_touching_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "GeneratedBuildIdentity.swift"
            output.write_text("sentinel", encoding="utf-8")
            result = self.run_generator(root, commit="bad")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("commit", result.stderr.lower())
            self.assertEqual(output.read_text(encoding="utf-8"), "sentinel")

    def test_rejects_invalid_build(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_generator(Path(directory), build="0")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("build", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
