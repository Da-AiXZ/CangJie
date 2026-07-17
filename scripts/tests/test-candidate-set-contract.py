#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
build = (ROOT / "scripts/build-candidate-set.sh").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/build-ipa.yml").read_text(encoding="utf-8")
ios = (ROOT / ".github/workflows/ios-ci.yml").read_text(encoding="utf-8")

required_build = [
    'generate-build-identity.py',
    'before xcodegen and xcodebuild',
    'CangJie-Keychain-Isolation-Probe.ipa',
    'candidate-set-manifest.json',
    'GITHUB_RUN_ATTEMPT',
    'CangJieIsolationProbe.entitlements',
    'com.juyang.CangJie.KeychainIsolationProbe',
]
for contract in required_build:
    assert contract in build, contract
assert build.index('generate-build-identity.py') < build.index('xcodegen generate')
assert build.index('generate-build-identity.py') < build.index('xcodebuild')

for contract in [
    'scripts/tests/test-generate-build-identity.py',
    'scripts/build-candidate-set.sh',
    '.build-ipa/CangJie-Keychain-Isolation-Probe.ipa',
    '.build-ipa/CangJie-Keychain-Isolation-Probe.sha256',
    '.build-ipa/candidate-set-manifest.json',
]:
    assert contract in workflow, contract

assert 'generate-build-identity.py' in ios
assert ios.index('generate-build-identity.py') < ios.index('xcodegen generate')

# The legacy single-IPA entry point must fail closed instead of producing schema 4 output.
assert 'Use scripts/build-candidate-set.sh' in (ROOT / 'scripts/build-ipa.sh').read_text(encoding='utf-8')
assert 'local bundle_identifier="${6:-${EXPECTED_BUNDLE_ID}}"' in (ROOT / 'scripts/build-ipa.sh').read_text(encoding='utf-8')

print("candidate set build contract: ok")
