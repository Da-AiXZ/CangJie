#!/usr/bin/env python3
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAMPER = ROOT / "scripts/stamp-build-identity.py"

with (ROOT / "App/Config/Info.plist").open("rb") as source:
    info = plistlib.load(source)

assert info.get("CangJieGitCommit") == "$(CANGJIE_GIT_COMMIT)"

project = (ROOT / "project.yml").read_text(encoding="utf-8")
assert "CANGJIE_GIT_COMMIT: local" in project
assert "CURRENT_PROJECT_VERSION: 1" in project

build = (ROOT / "scripts/build-ipa.sh").read_text(encoding="utf-8")
required = [
    'APP_GIT_COMMIT="$(git -C "${ROOT}" rev-parse --short=12 HEAD',
    'CANGJIE_GIT_COMMIT="${APP_GIT_COMMIT}"',
    'CURRENT_PROJECT_VERSION="${APP_BUILD_NUMBER}"',
    'python3 "${ROOT}/scripts/stamp-build-identity.py"',
    '"${EXPECTED_UNSTAMPED_BUILD_NUMBER}"',
    'if ! EXECUTABLE_NAME="$(python3 -',
    'readonly EXECUTABLE_NAME',
    '"CangJieGitCommit": expected_commit',
    '"CFBundleVersion": expected_build',
]
for contract in required:
    assert contract in build, contract
assert 'readonly EXECUTABLE_NAME="$(python3 -' not in build


def write_fixture(path: Path, commit_marker=None, build="23") -> bytes:
    fixture = {
        "CFBundleExecutable": "CangJie",
        "CFBundleIdentifier": "com.juyang.CangJie",
        "CFBundleVersion": build,
    }
    if commit_marker is not None:
        fixture["CangJieGitCommit"] = commit_marker
    with path.open("wb") as destination:
        plistlib.dump(fixture, destination, fmt=plistlib.FMT_BINARY, sort_keys=True)
    return path.read_bytes()


with tempfile.TemporaryDirectory() as directory:
    plist_path = Path(directory) / "Info.plist"
    write_fixture(plist_path, build="1")
    subprocess.run(
        [sys.executable, str(STAMPER), str(plist_path), "f979807f7b9f", "23", "1"],
        check=True,
    )
    stamped = plistlib.loads(plist_path.read_bytes())
    assert stamped["CangJieGitCommit"] == "f979807f7b9f"
    assert stamped["CFBundleVersion"] == "23"
    assert stamped["CFBundleExecutable"] == "CangJie"

with tempfile.TemporaryDirectory() as directory:
    plist_path = Path(directory) / "Info.plist"
    original = write_fixture(plist_path, commit_marker="unexpected")
    rejected = subprocess.run(
        [sys.executable, str(STAMPER), str(plist_path), "f979807f7b9f", "23", "1"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert rejected.returncode != 0
    assert "Refusing to replace unexpected" in rejected.stderr
    assert plist_path.read_bytes() == original

with tempfile.TemporaryDirectory() as directory:
    plist_path = Path(directory) / "Info.plist"
    original = write_fixture(plist_path, build="22")
    rejected = subprocess.run(
        [sys.executable, str(STAMPER), str(plist_path), "f979807f7b9f", "23", "1"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert rejected.returncode != 0
    assert "Refusing to replace unexpected CFBundleVersion" in rejected.stderr
    assert plist_path.read_bytes() == original

print("build identity contract: ok")
