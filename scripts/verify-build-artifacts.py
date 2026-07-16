#!/usr/bin/env python3
import hashlib
import json
import re
import sys
from pathlib import Path

BUNDLE_ID = "com.juyang.CangJie"
ARTIFACT = "CangJie-M0.ipa"
ACCEPTANCE = "blocked-pending-trollstore-device-keychain-validation"
LDID_VARIANTS = {
    "arm64": (
        "ldid_macosx_arm64",
        "5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50",
    ),
    "x86_64": (
        "ldid_macosx_x86_64",
        "9d46e0feedf96e399edfca09872802ba21e729f79c01927ad25ea2b0a35bca23",
    ),
}
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"invalid build manifest: {error}")


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: verify-build-artifacts.py <artifact-directory> <entitlements.plist>")
    root = Path(sys.argv[1]).resolve()
    entitlements_path = Path(sys.argv[2]).resolve()
    if not root.is_dir() or root.is_symlink():
        fail("artifact directory is missing or unsafe")
    required = {
        "manifest": root / "build-manifest.json",
        "ipa": root / ARTIFACT,
        "checksum": root / "CangJie-M0.sha256",
    }
    for label, path in required.items():
        if not path.is_file() or path.is_symlink():
            fail(f"{label} file is missing or unsafe")
    if not entitlements_path.is_file() or entitlements_path.is_symlink():
        fail("entitlements contract is missing or unsafe")

    manifest = load_json(required["manifest"])
    if manifest.get("schemaVersion") != 4 or manifest.get("artifact") != ARTIFACT:
        fail("manifest schema or artifact mismatch")
    if manifest.get("bundleIdentifier") != BUNDLE_ID:
        fail("manifest bundle identifier mismatch")

    actual_ipa_sha = sha256(required["ipa"])
    if manifest.get("sha256") != actual_ipa_sha:
        fail("manifest IPA SHA-256 mismatch")
    checksum_line = required["checksum"].read_text(encoding="utf-8").strip()
    if checksum_line != f"{actual_ipa_sha}  {ARTIFACT}":
        fail("checksum file mismatch")

    signing = manifest.get("signing")
    if not isinstance(signing, dict):
        fail("signing manifest is missing")
    if signing.get("type") != "trollstore-fakesign" or signing.get("signer") != "ldid":
        fail("signing type mismatch")
    ldid = signing.get("ldid")
    if not isinstance(ldid, dict) or ldid.get("tag") != "v2.1.5-procursus7":
        fail("ldid metadata mismatch")
    architecture = ldid.get("architecture")
    expected = LDID_VARIANTS.get(architecture)
    if expected is None or (ldid.get("asset"), ldid.get("sha256")) != expected:
        fail("ldid metadata mismatch")

    unsigned_hash = signing.get("unsignedExecutableSHA256")
    signed_hash = signing.get("signedExecutableSHA256")
    if not isinstance(unsigned_hash, str) or not HEX64.fullmatch(unsigned_hash):
        fail("unsigned executable SHA-256 mismatch")
    if not isinstance(signed_hash, str) or not HEX64.fullmatch(signed_hash):
        fail("signed executable SHA-256 mismatch")
    if unsigned_hash == signed_hash:
        fail("signed executable SHA-256 did not change")
    if signing.get("entitlementContractSHA256") != sha256(entitlements_path):
        fail("entitlement contract SHA-256 mismatch")

    expected_entitlements = {
        "application-identifier": BUNDLE_ID,
        "keychain-access-groups": [BUNDLE_ID],
    }
    if signing.get("entitlements") != expected_entitlements:
        fail("manifest entitlement mismatch")
    if signing.get("appleDeveloperCertificate") is not False:
        fail("Apple developer certificate flag mismatch")
    if signing.get("provisioningProfile") is not False:
        fail("provisioning profile flag mismatch")
    if signing.get("appleTeamIdentifier") is not None:
        fail("Apple team identifier must be null")
    if signing.get("contract") != "trollstore-prefixless-bundle-id":
        fail("signing contract mismatch")

    acceptance = manifest.get("acceptance")
    if not isinstance(acceptance, dict) or acceptance.get("status") != ACCEPTANCE or acceptance.get("failClosed") is not True:
        fail("acceptance gate mismatch")


if __name__ == "__main__":
    main()
