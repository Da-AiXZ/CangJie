#!/usr/bin/env python3
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

with (ROOT / "App/Config/Info.plist").open("rb") as source:
    info = plistlib.load(source)

assert info.get("CangJieGitCommit") == "$(CANGJIE_GIT_COMMIT)"

project = (ROOT / "project.yml").read_text(encoding="utf-8")
assert "CANGJIE_GIT_COMMIT: local" in project

build = (ROOT / "scripts/build-ipa.sh").read_text(encoding="utf-8")
required = [
    'APP_GIT_COMMIT="$(git -C "${ROOT}" rev-parse --short=12 HEAD',
    'CANGJIE_GIT_COMMIT="${APP_GIT_COMMIT}"',
    'CURRENT_PROJECT_VERSION="${APP_BUILD_NUMBER}"',
    '"CangJieGitCommit": expected_commit',
    '"CFBundleVersion": expected_build',
]
for contract in required:
    assert contract in build, contract

print("build identity contract: ok")
