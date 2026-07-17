#!/usr/bin/env python3
import json
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAMPER = ROOT / "scripts/stamp-build-identity.py"
GENERATOR = ROOT / "scripts/generate-build-identity.py"
COMMIT = "f979807f7b9f5e1cf30fbc72a2d7e35b9cf2f13a"
CANDIDATE = "a" * 64


def write_fixture(path: Path, commit_marker=None, build="1") -> bytes:
    fixture = {
        "CFBundleExecutable": "CangJie",
        "CFBundleIdentifier": "com.juyang.CangJie",
        "CFBundleVersion": build,
    }
    if commit_marker is not None:
        fixture["CangJieGitCommit"] = commit_marker
    path.write_bytes(plistlib.dumps(fixture, fmt=plistlib.FMT_BINARY, sort_keys=True))
    return path.read_bytes()


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    swift = root / "GeneratedBuildIdentity.swift"
    identity = root / "identity.json"
    subprocess.run([
        sys.executable, str(GENERATOR), "--role", "main", "--bundle-id", "com.juyang.CangJie",
        "--version", "1.0", "--build", "23", "--commit", COMMIT,
        "--candidate-set-id", CANDIDATE, "--swift-output", str(swift),
        "--metadata-output", str(identity),
    ], check=True)
    plist_path = root / "Info.plist"
    write_fixture(plist_path)
    subprocess.run([
        sys.executable, str(STAMPER), "--identity-json", str(identity),
        "--unstamped-build", "1", str(plist_path),
    ], check=True)
    stamped = plistlib.loads(plist_path.read_bytes())
    generated = json.loads(identity.read_text(encoding="utf-8"))
    assert stamped["CangJieGitCommit"] == COMMIT[:12]
    assert stamped["CFBundleVersion"] == "23"
    assert stamped["CFBundleShortVersionString"] == "1.0"
    assert stamped["CangJieExecutableFingerprint"] == generated["fingerprint"]
    assert stamped["CangJieCandidateSetID"] == CANDIDATE

with tempfile.TemporaryDirectory() as directory:
    plist_path = Path(directory) / "Info.plist"
    original = write_fixture(plist_path, commit_marker="unexpected")
    rejected = subprocess.run(
        [sys.executable, str(STAMPER), str(plist_path), COMMIT[:12], "23", "1"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    assert rejected.returncode != 0
    assert "Refusing to replace unexpected CangJieGitCommit" in rejected.stderr
    assert plist_path.read_bytes() == original

build = (ROOT / "scripts/build-candidate-set.sh").read_text(encoding="utf-8")
assert build.index("generate-build-identity.py") < build.index("xcodegen generate")
assert build.index("generate-build-identity.py") < build.index("xcodebuild")
assert "CANGJIE_EXECUTABLE_FINGERPRINT" in build
assert "CANGJIE_CANDIDATE_SET_ID" in build
print("build identity contract: ok")
