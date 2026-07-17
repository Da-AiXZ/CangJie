#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import plistlib
import re
import stat
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

MAIN_BUNDLE = "com.juyang.CangJie"
PROBE_BUNDLE = "com.juyang.CangJie.KeychainIsolationProbe"
EXPECTED_ROLES = {"main", "keychainIsolationProbe"}
ACCEPTANCE = "blocked-pending-trollstore-device-keychain-isolation-validation"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
LDID_VARIANTS = {
    "arm64": ("ldid_macosx_arm64", "5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50"),
    "x86_64": ("ldid_macosx_x86_64", "9d46e0feedf96e399edfca09872802ba21e729f79c01927ad25ea2b0a35bca23"),
}


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_file(root: Path, name: object, label: str) -> Path:
    if not isinstance(name, str) or not name or Path(name).name != name or "/" in name or "\\" in name:
        fail(f"unsafe {label} filename")
    path = root / name
    if not path.is_file() or path.is_symlink():
        fail(f"{label} file is missing or unsafe")
    return path


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"invalid candidate set manifest: {error}")


def load_plist(path: Path, label: str):
    try:
        with path.open("rb") as source:
            value = plistlib.load(source)
    except (OSError, ValueError, TypeError, plistlib.InvalidFileException):
        fail(f"invalid {label} plist")
    if not isinstance(value, dict):
        fail(f"invalid {label} plist root")
    return value


def inspect_ipa(path: Path):
    try:
        with zipfile.ZipFile(path) as package:
            entries = package.infolist()
            if not entries:
                fail("IPA is empty")
            app_roots = set()
            info_entry = None
            executable_entry = None
            for entry in entries:
                name = entry.filename
                pure = PurePosixPath(name)
                mode = (entry.external_attr >> 16) & 0xFFFF
                if "\\" in name or pure.is_absolute() or any(part in ("", ".", "..") for part in pure.parts):
                    fail(f"unsafe IPA entry: {name!r}")
                if stat.S_IFMT(mode) == stat.S_IFLNK:
                    fail("IPA contains a symbolic link")
                if "embedded.mobileprovision" in pure.parts:
                    fail("embedded provisioning profile is forbidden")
                if len(pure.parts) >= 2 and pure.parts[0] == "Payload" and pure.parts[1].endswith(".app"):
                    app_roots.add("/".join(pure.parts[:2]))
            if len(app_roots) != 1:
                fail("IPA must contain exactly one root app")
            app_root = next(iter(app_roots))
            expected_prefix = app_root + "/"
            for entry in entries:
                if entry.filename == expected_prefix + "Info.plist":
                    info_entry = entry
            if info_entry is None:
                fail("IPA Info.plist is missing")
            info = plistlib.loads(package.read(info_entry))
            if not isinstance(info, dict):
                fail("IPA Info.plist root is invalid")
            executable = info.get("CFBundleExecutable")
            if not isinstance(executable, str) or not executable or "/" in executable or "\\" in executable:
                fail("IPA executable name is unsafe")
            executable_name = expected_prefix + executable
            for entry in entries:
                if entry.filename == executable_name:
                    executable_entry = entry
            if executable_entry is None:
                fail("IPA executable is missing")
            executable_data = package.read(executable_entry)
            return info, app_root, executable, executable_data
    except zipfile.BadZipFile:
        fail("invalid IPA archive")


def extract_and_read_codesign_entitlements(ipa: Path, app_root: str, executable: str):
    if not Path("/usr/bin/codesign").is_file():
        fail("codesign is required for strict signed entitlement verification")
    with tempfile.TemporaryDirectory() as directory:
        destination = Path(directory)
        with zipfile.ZipFile(ipa) as package:
            package.extractall(destination)
        app_path = destination / app_root
        executable_path = app_path / executable
        for target, label in ((app_path, "app"), (executable_path, "executable")):
            verified = subprocess.run(
                ["/usr/bin/codesign", "--verify", "--strict", "--verbose=2", str(target)],
                text=True, capture_output=True,
            )
            if verified.returncode != 0:
                fail(f"strict codesign verification failed for {label}: {verified.stderr.strip()}")
        extracted = subprocess.run(
            ["/usr/bin/codesign", "--display", "--entitlements", "-", "--xml", str(executable_path)],
            capture_output=True,
        )
        if extracted.returncode != 0 or not extracted.stdout:
            fail("failed to extract signed executable entitlements")
        try:
            entitlements = plistlib.loads(extracted.stdout)
        except (ValueError, TypeError, plistlib.InvalidFileException):
            fail("signed executable entitlements are not a valid plist")
        if not isinstance(entitlements, dict):
            fail("signed executable entitlements root is invalid")
        return entitlements


def expected_fingerprint(role: str, bundle: str, version: str, build: str, commit: str, candidate: str) -> str:
    canonical = "|".join(["cangjie-executable-v1", role, bundle, version, build, commit, candidate])
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def verify_artifact(root: Path, artifact: dict, manifest: dict, metadata_only: bool):
    role = artifact.get("role")
    expected_bundle = MAIN_BUNDLE if role == "main" else PROBE_BUNDLE
    ipa = safe_file(root, artifact.get("file"), f"{role} IPA")
    checksum = safe_file(root, artifact.get("checksumFile"), f"{role} checksum")
    actual_ipa_sha = sha256(ipa)
    if artifact.get("sha256") != actual_ipa_sha:
        fail(f"{role} manifest IPA SHA-256 mismatch")
    if checksum.read_text(encoding="utf-8").strip() != f"{actual_ipa_sha}  {ipa.name}":
        fail(f"{role} checksum file mismatch")
    if artifact.get("bundleIdentifier") != expected_bundle:
        fail(f"{role} bundle identifier mismatch")

    info, app_root, executable, executable_data = inspect_ipa(ipa)
    if artifact.get("executable") != executable:
        fail(f"{role} executable binding mismatch")
    if info.get("CFBundleIdentifier") != expected_bundle:
        fail(f"{role} IPA bundle identifier mismatch")

    identity = artifact.get("compiledIdentity")
    if not isinstance(identity, dict):
        fail(f"{role} compiled identity is missing")
    candidate = manifest["candidateSetID"]
    commit = manifest["commit"]
    build = manifest["build"]
    version = identity.get("version")
    if identity.get("candidateSetID") != candidate or info.get("CangJieCandidateSetID") != candidate:
        fail("candidate set binding mismatch")
    if identity.get("commit") != commit or info.get("CangJieGitCommit") != commit[:12]:
        fail("commit binding mismatch")
    if identity.get("build") != build or info.get("CFBundleVersion") != build:
        fail("build binding mismatch")
    if info.get("CFBundleShortVersionString") != version:
        fail("version binding mismatch")
    fingerprint = expected_fingerprint(role, expected_bundle, version, build, commit, candidate)
    if identity.get("fingerprint") != fingerprint or info.get("CangJieExecutableFingerprint") != fingerprint:
        fail("compiled identity fingerprint mismatch")

    signing = artifact.get("signing")
    if not isinstance(signing, dict):
        fail(f"{role} signing manifest is missing")
    if signing.get("type") != "trollstore-fakesign" or signing.get("signer") != "ldid":
        fail("signing type mismatch")
    ldid = signing.get("ldid")
    if not isinstance(ldid, dict) or ldid.get("tag") != "v2.1.5-procursus7":
        fail("ldid metadata mismatch")
    expected_ldid = LDID_VARIANTS.get(ldid.get("architecture"))
    if expected_ldid is None or (ldid.get("asset"), ldid.get("sha256")) != expected_ldid:
        fail("ldid metadata mismatch")
    unsigned_hash = signing.get("unsignedExecutableSHA256")
    signed_hash = signing.get("signedExecutableSHA256")
    if not isinstance(unsigned_hash, str) or not HEX64.fullmatch(unsigned_hash):
        fail("unsigned executable SHA-256 mismatch")
    if not isinstance(signed_hash, str) or not HEX64.fullmatch(signed_hash) or signed_hash == unsigned_hash:
        fail("signed executable SHA-256 mismatch")
    if sha256_bytes(executable_data) != signed_hash:
        fail("archived executable SHA-256 mismatch")

    expected_entitlements = {
        "application-identifier": expected_bundle,
        "keychain-access-groups": [expected_bundle],
    }
    contract = safe_file(root, signing.get("entitlementContractFile"), f"{role} entitlement contract")
    signed_file = safe_file(root, signing.get("signedEntitlementsFile"), f"{role} signed entitlements")
    if signing.get("entitlementContractSHA256") != sha256(contract):
        fail("entitlement contract SHA-256 mismatch")
    if signing.get("signedEntitlementsSHA256") != sha256(signed_file):
        fail("signed entitlement SHA-256 mismatch")
    if load_plist(contract, "entitlement contract") != expected_entitlements:
        fail("entitlement contract mismatch")
    if load_plist(signed_file, "signed entitlement") != expected_entitlements:
        fail("signed entitlement mismatch")
    manifest_entitlements = signing.get("entitlements")
    if isinstance(manifest_entitlements, dict) and manifest_entitlements.get("keychain-access-groups") != [expected_bundle]:
        fail("entitlement isolation mismatch")
    if manifest_entitlements != expected_entitlements:
        fail("manifest entitlement mismatch")
    if not metadata_only and extract_and_read_codesign_entitlements(ipa, app_root, executable) != expected_entitlements:
        fail("signed executable entitlement mismatch")
    if signing.get("appleDeveloperCertificate") is not False or signing.get("provisioningProfile") is not False:
        fail("certificate or provisioning profile flag mismatch")
    if signing.get("appleTeamIdentifier") is not None:
        fail("Apple team identifier must be null")
    if signing.get("contract") != "trollstore-prefixless-bundle-id":
        fail("signing contract mismatch")
    return expected_entitlements["keychain-access-groups"][0]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact_directory")
    parser.add_argument("--metadata-only", action="store_true", help="skip macOS codesign extraction; for hermetic script tests only")
    args = parser.parse_args()
    root = Path(args.artifact_directory).resolve()
    if not root.is_dir() or root.is_symlink():
        fail("artifact directory is missing or unsafe")
    manifest_path = root / "candidate-set-manifest.json"
    if not manifest_path.is_file() or manifest_path.is_symlink():
        fail("manifest file is missing or unsafe")
    manifest = load_json(manifest_path)
    if manifest.get("schemaVersion") != 5:
        fail("manifest schema mismatch")
    candidate = manifest.get("candidateSetID")
    commit = manifest.get("commit")
    build = manifest.get("build")
    if not isinstance(candidate, str) or not HEX64.fullmatch(candidate):
        fail("candidate set ID mismatch")
    if not isinstance(commit, str) or not HEX40.fullmatch(commit):
        fail("commit binding mismatch")
    if not isinstance(build, str) or not build.isdigit() or int(build) < 1:
        fail("build binding mismatch")
    for field in ("runId", "runAttempt", "runNumber"):
        value = manifest.get(field)
        if not isinstance(value, str) or not value.isdigit() or int(value) < 1:
            fail(f"{field} binding mismatch")
    if manifest["runNumber"] != build:
        fail("run/build binding mismatch")

    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or len(artifacts) != 2:
        fail("artifact roles mismatch")
    by_role = {artifact.get("role"): artifact for artifact in artifacts if isinstance(artifact, dict)}
    if set(by_role) != EXPECTED_ROLES:
        fail("artifact roles mismatch")
    groups = [verify_artifact(root, by_role[role], manifest, args.metadata_only) for role in sorted(EXPECTED_ROLES)]
    if len(set(groups)) != 2 or set(groups) != {MAIN_BUNDLE, PROBE_BUNDLE}:
        fail("entitlement isolation mismatch")

    acceptance = manifest.get("acceptance")
    if not isinstance(acceptance, dict) or acceptance.get("status") != ACCEPTANCE or acceptance.get("failClosed") is not True:
        fail("acceptance gate mismatch")


if __name__ == "__main__":
    main()
