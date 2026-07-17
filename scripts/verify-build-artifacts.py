#!/usr/bin/env python3
import argparse
import base64
import binascii
import hashlib
import json
import plistlib
import re
import stat
import subprocess
import tempfile
import unicodedata
import zipfile
from pathlib import Path, PurePosixPath

from candidate_set_identity import (
    CandidateIdentityError,
    derive_build_version,
    derive_candidate_set_id,
    validate_compiled_identity,
)

MAIN_BUNDLE = "com.juyang.CangJie"
PROBE_BUNDLE = "com.juyang.CangJie.KeychainIsolationProbe"
ARTIFACT_SPECS = {
    "main": {"bundleIdentifier": MAIN_BUNDLE, "productName": "CangJie", "executable": "CangJie"},
    "keychainIsolationProbe": {
        "bundleIdentifier": PROBE_BUNDLE,
        "productName": "CangJieKeychainIsolationProbe",
        "executable": "CangJieKeychainIsolationProbe",
    },
}
EXPECTED_ROLES = set(ARTIFACT_SPECS)
ACCEPTANCE = "blocked-pending-trollstore-device-keychain-isolation-validation"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
BASE64URL = re.compile(br"^[A-Za-z0-9_-]+$")
IDENTITY_MARKER_PREFIX = b"CANGJIE_IDENTITY_V1:"
MAX_IDENTITY_MARKER_PAYLOAD_BYTES = 4096
MAX_IPA_BYTES = 512 * 1024 * 1024
MAX_IPA_ENTRIES = 16384
MAX_IPA_ENTRY_BYTES = 256 * 1024 * 1024
MAX_IPA_UNCOMPRESSED_BYTES = 1024 * 1024 * 1024
MAX_IPA_COMPRESSION_RATIO = 200.0
MIN_RATIO_CHECK_BYTES = 64 * 1024
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
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_json_keys,
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
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


def _archive_equivalence_keys(name: str):
    nfc = unicodedata.normalize("NFC", name)
    nfd = unicodedata.normalize("NFD", name)
    return {name.casefold(), nfc, nfd, nfc.casefold(), nfd.casefold()}


def _contains_unreviewed_nested_code(pure: PurePosixPath, expected_product: str) -> bool:
    app_parts = ("Payload", f"{expected_product}.app")
    if pure.parts[:2] != app_parts:
        return False
    relative = pure.parts[2:]
    if not relative:
        return False
    if relative[0] in {"PlugIns", "Watch", "XPCServices"}:
        return True
    if relative[0] == "Frameworks":
        return any(part.endswith(".framework") for part in relative[1:]) or relative[-1].endswith(".dylib")
    return False


def validate_archive_limits(path: Path, entries) -> None:
    try:
        archive_size = path.stat().st_size
    except OSError:
        fail("IPA size could not be read")
    if archive_size <= 0 or archive_size > MAX_IPA_BYTES:
        fail("IPA compressed size limit exceeded")
    if len(entries) > MAX_IPA_ENTRIES:
        fail("IPA contains too many entries")

    total_uncompressed = 0
    for entry in entries:
        if entry.flag_bits & 0x1:
            fail("encrypted IPA entries are forbidden")
        if entry.file_size < 0 or entry.compress_size < 0:
            fail("IPA entry size is invalid")
        if entry.file_size > MAX_IPA_ENTRY_BYTES:
            fail("IPA entry size limit exceeded")
        total_uncompressed += entry.file_size
        if total_uncompressed > MAX_IPA_UNCOMPRESSED_BYTES:
            fail("IPA uncompressed size limit exceeded")

    for entry in entries:
        if entry.file_size < MIN_RATIO_CHECK_BYTES:
            continue
        if entry.compress_size == 0 or entry.file_size / entry.compress_size > MAX_IPA_COMPRESSION_RATIO:
            fail("IPA compression ratio limit exceeded")


def _marker_occurrences(data: bytes):
    offsets = []
    start = 0
    while True:
        offset = data.find(IDENTITY_MARKER_PREFIX, start)
        if offset < 0:
            return offsets
        offsets.append(offset)
        start = offset + len(IDENTITY_MARKER_PREFIX)


def _reject_duplicate_json_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def extract_identity_marker(executable_data: bytes):
    offsets = _marker_occurrences(executable_data)
    if len(offsets) != 1:
        fail("executable identity marker count mismatch")
    payload_start = offsets[0] + len(IDENTITY_MARKER_PREFIX)
    payload_end = executable_data.find(b"\0", payload_start)
    if payload_end < 0:
        fail("executable identity marker is not NUL terminated")
    payload = executable_data[payload_start:payload_end]
    if not payload or len(payload) > MAX_IDENTITY_MARKER_PAYLOAD_BYTES or not BASE64URL.fullmatch(payload):
        fail("executable identity marker payload is invalid")
    padding = b"=" * ((4 - len(payload) % 4) % 4)
    try:
        decoded = base64.b64decode(payload + padding, altchars=b"-_", validate=True)
    except (ValueError, binascii.Error):
        fail("executable identity marker payload is invalid")
    try:
        identity = json.loads(decoded.decode("utf-8"), object_pairs_hook=_reject_duplicate_json_keys)
    except (UnicodeError, json.JSONDecodeError, ValueError):
        fail("executable identity marker JSON is invalid")
    if not isinstance(identity, dict):
        fail("executable identity marker JSON root is invalid")
    canonical = json.dumps(identity, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    if canonical != decoded:
        fail("executable identity marker JSON is not canonical")
    return identity


def inspect_ipa(path: Path, expected_product: str):
    expected_app_root = f"Payload/{expected_product}.app"
    expected_prefix = expected_app_root + "/"
    try:
        with zipfile.ZipFile(path) as package:
            entries = package.infolist()
            if not entries:
                fail("IPA is empty")
            validate_archive_limits(path, entries)
            names = [entry.filename for entry in entries]
            if len(names) != len(set(names)):
                fail("duplicate IPA entry")
            equivalence_owners = {}
            for name in names:
                for key in _archive_equivalence_keys(name):
                    owner = equivalence_owners.get(key)
                    if owner is not None and owner != name:
                        fail("filesystem-equivalent IPA entry collision")
                    equivalence_owners[key] = name

            for entry in entries:
                name = entry.filename
                if not isinstance(name, str) or not name or "\0" in name or "\\" in name:
                    fail(f"unsafe IPA entry: {name!r}")
                pure = PurePosixPath(name)
                raw_parts = name.split("/")
                if raw_parts[-1] == "":
                    raw_parts = raw_parts[:-1]
                if (
                    pure.is_absolute()
                    or not raw_parts
                    or any(part in ("", ".", "..") for part in raw_parts)
                ):
                    fail(f"unsafe IPA entry: {name!r}")
                mode = (entry.external_attr >> 16) & 0xFFFF
                file_type = stat.S_IFMT(mode)
                if file_type == stat.S_IFLNK:
                    fail("IPA contains a symbolic link")
                if file_type not in (0, stat.S_IFREG, stat.S_IFDIR):
                    fail("IPA contains an unsupported filesystem entry")
                if "embedded.mobileprovision" in pure.parts:
                    fail("embedded provisioning profile is forbidden")
                if _contains_unreviewed_nested_code(pure, expected_product):
                    fail("IPA contains unreviewed nested code")
                if name in ("Payload", "Payload/", expected_app_root, expected_app_root + "/"):
                    continue
                if name.startswith(expected_prefix):
                    continue
                if len(pure.parts) >= 2 and pure.parts[0] == "Payload" and pure.parts[1].endswith(".app"):
                    fail("IPA app root mismatch")
                fail("unexpected IPA entry root")

            info_matches = [entry for entry in entries if entry.filename == expected_prefix + "Info.plist"]
            if len(info_matches) != 1:
                fail("IPA Info.plist is missing")
            try:
                info = plistlib.loads(package.read(info_matches[0]))
            except (KeyError, ValueError, TypeError, plistlib.InvalidFileException):
                fail("IPA Info.plist is invalid")
            if not isinstance(info, dict):
                fail("IPA Info.plist root is invalid")
            executable = info.get("CFBundleExecutable")
            if executable != expected_product:
                fail("IPA executable name mismatch")
            executable_matches = [entry for entry in entries if entry.filename == expected_prefix + expected_product]
            if len(executable_matches) != 1:
                fail("IPA executable is missing")
            executable_entry = executable_matches[0]
            executable_mode = (executable_entry.external_attr >> 16) & 0xFFFF
            if stat.S_IFMT(executable_mode) != stat.S_IFREG or not (executable_mode & 0o111):
                fail("IPA executable mode is invalid")
            executable_data = package.read(executable_entry)
            return info, expected_app_root, expected_product, executable_data
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


def verify_artifact(root: Path, artifact: dict, manifest: dict, metadata_only: bool):
    role = artifact.get("role")
    spec = ARTIFACT_SPECS[role]
    expected_bundle = spec["bundleIdentifier"]
    expected_product = spec["productName"]
    if artifact.get("bundleIdentifier") != expected_bundle:
        fail(f"{role} bundle identifier mismatch")
    if artifact.get("productName") != expected_product:
        fail(f"{role} product name mismatch")
    if artifact.get("executable") != spec["executable"]:
        fail(f"{role} executable binding mismatch")

    ipa = safe_file(root, artifact.get("file"), f"{role} IPA")
    checksum = safe_file(root, artifact.get("checksumFile"), f"{role} checksum")
    actual_ipa_sha = sha256(ipa)
    if artifact.get("sha256") != actual_ipa_sha:
        fail(f"{role} manifest IPA SHA-256 mismatch")
    if checksum.read_text(encoding="utf-8").strip() != f"{actual_ipa_sha}  {ipa.name}":
        fail(f"{role} checksum file mismatch")

    info, app_root, executable, executable_data = inspect_ipa(ipa, expected_product)
    if info.get("CFBundleIdentifier") != expected_bundle:
        fail(f"{role} IPA bundle identifier mismatch")

    identity = artifact.get("compiledIdentity")
    try:
        validate_compiled_identity(
            identity,
            role=role,
            bundle_identifier=expected_bundle,
            version=manifest["version"],
            build=manifest["build"],
            commit=manifest["commit"],
            candidate_set_id=manifest["candidateSetID"],
        )
    except CandidateIdentityError as error:
        fail(str(error))
    if extract_identity_marker(executable_data) != identity:
        fail("executable identity marker mismatch")

    candidate = manifest["candidateSetID"]
    commit = manifest["commit"]
    build = manifest["build"]
    version = identity["version"]
    if info.get("CangJieCandidateSetID") != candidate:
        fail("candidate set binding mismatch")
    if info.get("CangJieGitCommit") != commit[:12]:
        fail("commit binding mismatch")
    if info.get("CFBundleVersion") != build:
        fail("build binding mismatch")
    if info.get("CFBundleShortVersionString") != version:
        fail("version binding mismatch")
    if info.get("CangJieExecutableFingerprint") != identity["fingerprint"]:
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
    supplied_root = Path(args.artifact_directory)
    if supplied_root.is_symlink():
        fail("artifact directory is missing or unsafe")
    try:
        root = supplied_root.resolve(strict=True)
    except OSError:
        fail("artifact directory is missing or unsafe")
    if not root.is_dir():
        fail("artifact directory is missing or unsafe")
    manifest_path = root / "candidate-set-manifest.json"
    if not manifest_path.is_file() or manifest_path.is_symlink():
        fail("manifest file is missing or unsafe")
    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 5:
        fail("manifest schema mismatch")
    candidate = manifest.get("candidateSetID")
    commit = manifest.get("commit")
    version = manifest.get("version")
    build = manifest.get("build")
    if not isinstance(candidate, str) or not HEX64.fullmatch(candidate):
        fail("candidate set ID mismatch")
    if not isinstance(commit, str) or not HEX40.fullmatch(commit):
        fail("commit binding mismatch")
    for field in ("runId", "runAttempt", "runNumber"):
        value = manifest.get(field)
        if not isinstance(value, str) or not value.isdigit() or int(value) < 1 or str(int(value)) != value:
            fail(f"{field} binding mismatch")
    try:
        expected_build = derive_build_version(manifest["runNumber"], manifest["runAttempt"])
    except CandidateIdentityError:
        fail("runAttempt binding mismatch")
    if build != expected_build:
        fail("run/build binding mismatch")
    try:
        expected_candidate = derive_candidate_set_id(
            commit=commit,
            run_id=manifest["runId"],
            run_attempt=manifest["runAttempt"],
            run_number=manifest["runNumber"],
            version=version,
            build=build,
            main_bundle_id=MAIN_BUNDLE,
            probe_bundle_id=PROBE_BUNDLE,
        )
    except CandidateIdentityError as error:
        fail(str(error))
    if candidate != expected_candidate:
        fail("candidate set derivation mismatch")

    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or len(artifacts) != 2 or not all(isinstance(item, dict) for item in artifacts):
        fail("artifact roles mismatch")
    by_role = {}
    for artifact in artifacts:
        role = artifact.get("role")
        if role in by_role or role not in EXPECTED_ROLES:
            fail("artifact roles mismatch")
        by_role[role] = artifact
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
