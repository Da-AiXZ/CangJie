#!/bin/bash
set -euo pipefail

readonly EXPECTED_BUNDLE_ID="com.juyang.CangJie"
readonly EXPECTED_DEPLOYMENT_TARGET="16.6"
readonly EXPECTED_DEVICE_FAMILY="2"
readonly EXPECTED_GRDB_VERSION="6.29.3"
readonly EXPECTED_GRDB_REVISION="2cf6c756e1e5ef6901ebae16576a7e4e4b834622"
readonly EXPECTED_GRDB_BUNDLE_NAME="GRDB_GRDB.bundle"
readonly EXPECTED_GRDB_URL="https://github.com/groue/GRDB.swift.git"
readonly EXPECTED_GRDB_PRIVACY_SHA256="17784da62e51f74c5859df32fe402e01e25cdf6f797a4add06e2a3ce15c911f4"
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly OUT="${ROOT}/.build-ipa"
readonly DERIVED="${OUT}/DerivedData"
readonly SOURCE_PACKAGES="${OUT}/SourcePackages"
readonly PAYLOAD="${OUT}/Payload"
readonly IPA_NAME="CangJie-M0.ipa"
readonly ENTITLEMENTS_CONTRACT="${ROOT}/App/Config/CangJie.entitlements"
readonly PACKAGE_RESOLVED="${ROOT}/CangJie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly SIGNED_ENTITLEMENTS="${OUT}/signed-entitlements.plist"

fail() { echo "$*" >&2; exit 1; }
require_tool() { command -v "$1" >/dev/null || fail "Required tool is missing: $1"; }
verify_dependency_contract() {
  require_tool python3
  python3 - "${ROOT}/App/Config/SwiftPMPins.json" "${ROOT}/project.yml" <<'PY'
import json
import re
import sys
contract_path, project_path = sys.argv[1:]
revision = "2cf6c756e1e5ef6901ebae16576a7e4e4b834622"
url = "https://github.com/groue/GRDB.swift.git"
contract = json.loads(open(contract_path, encoding="utf-8").read())
expected = {"schemaVersion": 1, "packages": [{"identity": "grdb.swift", "repositoryURL": url, "tag": "v6.29.3", "version": "6.29.3", "revision": revision, "resourceBundle": {"name": "GRDB_GRDB.bundle", "privacyManifestSHA256": "17784da62e51f74c5859df32fe402e01e25cdf6f797a4add06e2a3ce15c911f4"}}]}
if contract != expected:
    raise SystemExit("SwiftPM contract mismatch")
project = open(project_path, encoding="utf-8").read()
match = re.search(r"(?ms)^  GRDB:\n((?:    [^\n]*\n)+)", project)
if not match:
    raise SystemExit("project.yml is missing GRDB")
settings = {}
for line in match.group(1).splitlines():
    key, value = line.strip().split(":", 1)
    settings[key] = value.strip().strip("\"'")
if settings != {"url": url, "revision": revision}:
    raise SystemExit(f"Unexpected GRDB project pin: {settings!r}")
PY
}

verify_resolved_packages() {
  require_tool python3
  local resolved_path="${1:-}"
  [[ -f "${resolved_path}" && ! -L "${resolved_path}" ]] || fail "Package.resolved is missing or unsafe: ${resolved_path}"
  python3 - "${resolved_path}" <<'PY'
import json
import sys
path = sys.argv[1]
resolved = json.loads(open(path, encoding="utf-8").read())
pins = resolved.get("pins") or resolved.get("object", {}).get("pins")
if not isinstance(pins, list) or len(pins) != 1:
    raise SystemExit(f"Expected one SwiftPM pin, found {pins!r}")
pin = pins[0]
state = pin.get("state", {})
if (pin.get("identity") or pin.get("package")) != "grdb.swift":
    raise SystemExit("Unexpected SwiftPM identity")
if (pin.get("location") or pin.get("repositoryURL")) != "https://github.com/groue/GRDB.swift.git":
    raise SystemExit("Unexpected SwiftPM URL")
if state.get("revision") != "2cf6c756e1e5ef6901ebae16576a7e4e4b834622" or state.get("branch") not in (None, ""):
    raise SystemExit(f"Unexpected SwiftPM state: {state!r}")
PY
}
verify_entitlements() { require_tool python3; local path="$1"; [[ -f "${path}" && ! -L "${path}" ]] || fail "Entitlements file is missing or unsafe: ${path}"; python3 - "${path}" "${EXPECTED_BUNDLE_ID}" <<'PY'
import plistlib
import sys
path, bundle_identifier = sys.argv[1:]
entitlements = plistlib.loads(open(path, "rb").read())
expected = {"application-identifier": bundle_identifier, "keychain-access-groups": [bundle_identifier]}
if entitlements != expected:
    raise SystemExit(f"Entitlement contract mismatch: {entitlements!r}")
PY
}
verify_grdb_privacy_manifest() {
  require_tool python3
  local privacy_path="$1"
  [[ -f "${privacy_path}" && ! -L "${privacy_path}" ]] || fail "GRDB privacy manifest is missing or unsafe: ${privacy_path}"
  python3 - "${privacy_path}" "${EXPECTED_GRDB_PRIVACY_SHA256}" <<'PY'
import hashlib
import plistlib
import sys
from pathlib import Path

privacy_path = Path(sys.argv[1])
expected_hash = sys.argv[2]
actual_hash = hashlib.sha256(privacy_path.read_bytes()).hexdigest()
if actual_hash != expected_hash:
    raise SystemExit(f"GRDB privacy manifest hash mismatch: expected {expected_hash}, found {actual_hash}")
with privacy_path.open("rb") as source:
    privacy = plistlib.load(source)
expected_privacy = {"NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": [], "NSPrivacyTrackingDomains": [], "NSPrivacyAccessedAPITypes": []}
if privacy != expected_privacy:
    raise SystemExit(f"Unexpected GRDB privacy manifest semantics: {privacy!r}")
PY
}
verify_grdb_resource_bundle() {
  require_tool python3
  local bundle_path="$1"
  [[ -d "${bundle_path}" && ! -L "${bundle_path}" ]] || fail "Required GRDB resource bundle is missing or unsafe: ${bundle_path}"
  verify_grdb_privacy_manifest "${bundle_path}/PrivacyInfo.xcprivacy"
  python3 - "${bundle_path}" <<'PY'
import os
import plistlib
import re
import sys
from pathlib import Path
bundle = Path(sys.argv[1])
required = {"Info.plist", "PrivacyInfo.xcprivacy"}
allowed = required | {"PkgInfo"}
seen = set()
for root, directories, files in os.walk(bundle, followlinks=False):
    current = Path(root)
    for name in directories:
        path = current / name
        if path.is_symlink():
            raise SystemExit(f"GRDB resource bundle contains a symbolic link: {path}")
        raise SystemExit(f"GRDB resource bundle contains an unexpected directory: {path}")
    for name in files:
        path = current / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f"GRDB resource bundle contains an unsafe entry: {path}")
        seen.add(path.relative_to(bundle).as_posix())
if not required.issubset(seen) or not seen.issubset(allowed):
    raise SystemExit(f"Unexpected GRDB resource bundle contents: {sorted(seen)!r}")
with (bundle / "Info.plist").open("rb") as source:
    info = plistlib.load(source)
identifier = info.get("CFBundleIdentifier")
if not isinstance(identifier, str) or not re.fullmatch(r"(?:org\.swift\.swiftpm\.)?GRDB\.GRDB\.resources", identifier):
    raise SystemExit(f"Unexpected GRDB resource bundle identifier: {identifier!r}")
if info.get("CFBundlePackageType") != "BNDL" or "CFBundleExecutable" in info:
    raise SystemExit("GRDB resource bundle has an invalid package type or executable")
pkg_info = bundle / "PkgInfo"
if pkg_info.exists() and pkg_info.read_bytes() != b"BNDL????":
    raise SystemExit("Unexpected GRDB resource bundle PkgInfo contents")
PY
}
case "${1:-}" in
  --verify-dependency-contract)
    [[ "$#" == "1" ]] || fail "--verify-dependency-contract does not accept additional arguments"
    verify_dependency_contract
    exit 0
    ;;
  --verify-resolved-packages)
    [[ "$#" == "2" && -n "${2:-}" ]] || fail "Usage: $0 --verify-resolved-packages <Package.resolved>"
    verify_resolved_packages "$2"
    exit 0
    ;;
  --verify-grdb-privacy-manifest)
    [[ "$#" == "2" && -n "${2:-}" ]] || fail "Usage: $0 --verify-grdb-privacy-manifest <PrivacyInfo.xcprivacy>"
    verify_grdb_privacy_manifest "$2"
    exit 0
    ;;
  "")
    [[ "$#" == "0" ]] || fail "Unexpected empty build argument"
    ;;
  *)
    fail "Unknown build-ipa option: $1"
    ;;
esac

[[ "${ROOT}" != "/" && "${OUT}" == "${ROOT}/.build-ipa" ]] || fail "Refusing to clean an unexpected output path: ${OUT}"
for tool in xcodegen xcodebuild xcrun lipo codesign file git python3 zip unzip shasum; do
  require_tool "${tool}"
done
verify_dependency_contract
verify_entitlements "${ENTITLEMENTS_CONTRACT}"

rm -rf "${OUT}"
mkdir -p "${PAYLOAD}"
cd "${ROOT}"

xcodegen generate --spec project.yml
xcodebuild -resolvePackageDependencies \
  -project CangJie.xcodeproj \
  -scheme CangJie \
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES}"
verify_resolved_packages "${PACKAGE_RESOLVED}"

readonly GRDB_CHECKOUT="${SOURCE_PACKAGES}/checkouts/GRDB.swift"
[[ -d "${GRDB_CHECKOUT}/.git" && ! -L "${GRDB_CHECKOUT}" ]] || fail "Auditable GRDB checkout is missing: ${GRDB_CHECKOUT}"
readonly CHECKOUT_COUNT="$(find "${SOURCE_PACKAGES}/checkouts" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"
[[ "${CHECKOUT_COUNT}" == "1" ]] || fail "Expected exactly one remote SwiftPM checkout, found ${CHECKOUT_COUNT}"
readonly CHECKOUT_REVISION="$(git -C "${GRDB_CHECKOUT}" rev-parse HEAD)"
[[ "${CHECKOUT_REVISION}" == "${EXPECTED_GRDB_REVISION}" ]] || fail "GRDB checkout revision mismatch: ${CHECKOUT_REVISION}"
readonly CHECKOUT_REMOTE="$(git -C "${GRDB_CHECKOUT}" remote get-url origin)"
if [[ "${CHECKOUT_REMOTE}" == "${EXPECTED_GRDB_URL}" || "${CHECKOUT_REMOTE}" == "${EXPECTED_GRDB_URL%.git}" ]]; then
  readonly AUDITED_GRDB_REMOTE="${CHECKOUT_REMOTE}"
  readonly GRDB_GIT_DIRECTORY="${GRDB_CHECKOUT}/.git"
else
  readonly REPOSITORY_CACHE_ROOT="${SOURCE_PACKAGES}/repositories"
  readonly GRDB_REPOSITORY_CACHE="$(python3 - "${CHECKOUT_REMOTE}" "${REPOSITORY_CACHE_ROOT}" <<'PY'
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

remote, cache_root = sys.argv[1:]
if remote.startswith("file://"):
    parsed = urlparse(remote)
    if parsed.netloc not in ("", "localhost"):
        raise SystemExit(f"Unsupported local SwiftPM cache authority: {parsed.netloc!r}")
    remote = unquote(parsed.path)

candidate = Path(remote)
if not candidate.is_absolute():
    raise SystemExit(f"SwiftPM checkout origin is neither HTTPS nor an absolute cache path: {remote!r}")
root_candidate = Path(cache_root)
if root_candidate.is_symlink():
    raise SystemExit(f"SwiftPM repository cache root is a symlink: {root_candidate}")
root = root_candidate.resolve(strict=True)
resolved = candidate.resolve(strict=True)
if resolved == root or root not in resolved.parents:
    raise SystemExit(f"SwiftPM repository cache escapes the expected root: {resolved}")
if candidate.is_symlink() or not resolved.is_dir():
    raise SystemExit(f"SwiftPM repository cache is unsafe: {candidate}")
print(resolved)
PY
)"
  [[ "$(git --git-dir="${GRDB_REPOSITORY_CACHE}" rev-parse --is-bare-repository)" == "true" ]] || fail "SwiftPM GRDB repository cache is not bare: ${GRDB_REPOSITORY_CACHE}"
  readonly AUDITED_GRDB_REMOTE="$(git --git-dir="${GRDB_REPOSITORY_CACHE}" remote get-url origin)"
  readonly GRDB_GIT_DIRECTORY="${GRDB_REPOSITORY_CACHE}"
fi
[[ "${AUDITED_GRDB_REMOTE}" == "${EXPECTED_GRDB_URL}" || "${AUDITED_GRDB_REMOTE}" == "${EXPECTED_GRDB_URL%.git}" ]] || fail "GRDB repository origin mismatch: ${AUDITED_GRDB_REMOTE}"
readonly AUDITED_GRDB_REVISION="$(git --git-dir="${GRDB_GIT_DIRECTORY}" rev-parse "${EXPECTED_GRDB_REVISION}^{commit}")"
[[ "${AUDITED_GRDB_REVISION}" == "${EXPECTED_GRDB_REVISION}" ]] || fail "GRDB repository cache is missing the pinned revision: ${AUDITED_GRDB_REVISION}"
[[ -z "$(git -C "${GRDB_CHECKOUT}" status --porcelain --untracked-files=all)" ]] || fail "GRDB checkout is not clean"
verify_grdb_privacy_manifest "${GRDB_CHECKOUT}/GRDB/PrivacyInfo.xcprivacy"

xcodebuild build \
  -project CangJie.xcodeproj \
  -scheme CangJie \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${DERIVED}" \
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES}" \
  -disableAutomaticPackageResolution \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

readonly APP="${DERIVED}/Build/Products/Release-iphoneos/CangJie.app"
readonly INFO_PLIST="${APP}/Info.plist"
[[ -d "${APP}" && ! -L "${APP}" ]] || fail "Built app not found: ${APP}"
[[ -f "${INFO_PLIST}" && ! -L "${INFO_PLIST}" ]] || fail "Info.plist is missing or unsafe"

if find "${APP}" -type l -print -quit | grep -q .; then
  fail "The app bundle contains a symbolic link"
fi

if find "${APP}" -mindepth 1 \
  \( -type d \( -name '*.app' -o -name '*.framework' -o -name '*.appex' -o -name '*.xpc' \) \
     -o -type f -name '*.dylib' \) \
  -print -quit | grep -q .; then
  fail "The M0 app contains a forbidden nested app, framework, extension, XPC service, or dylib"
fi

readonly GRDB_RESOURCE_BUNDLE="${APP}/${EXPECTED_GRDB_BUNDLE_NAME}"
readonly BUNDLE_COUNT="$(find "${APP}" -mindepth 1 -type d -name '*.bundle' | wc -l | tr -d '[:space:]')"
[[ "${BUNDLE_COUNT}" == "1" ]] || fail "Expected exactly one resource bundle (${EXPECTED_GRDB_BUNDLE_NAME}), found ${BUNDLE_COUNT}"
while IFS= read -r -d '' candidate; do
  [[ "${candidate}" == "${GRDB_RESOURCE_BUNDLE}" ]] || fail "Unknown nested resource bundle: ${candidate}"
done < <(find "${APP}" -mindepth 1 -type d -name '*.bundle' -print0)
verify_grdb_resource_bundle "${GRDB_RESOURCE_BUNDLE}"

if find "${APP}" -name 'embedded.mobileprovision' -print -quit | grep -q .; then
  fail "Unexpected provisioning profile in app bundle"
fi

readonly EXECUTABLE_NAME="$(python3 - "${INFO_PLIST}" "${EXPECTED_BUNDLE_ID}" "${EXPECTED_DEPLOYMENT_TARGET}" "${EXPECTED_DEVICE_FAMILY}" <<'PY'
import plistlib
import sys

path, expected_bundle_id, expected_target, expected_family = sys.argv[1:5]
with open(path, "rb") as source:
    info = plistlib.load(source)
checks = {
    "CFBundleIdentifier": expected_bundle_id,
    "MinimumOSVersion": expected_target,
}
for key, expected in checks.items():
    actual = info.get(key)
    if actual != expected:
        raise SystemExit(f"Unexpected {key}: {actual!r}; expected {expected!r}")
families = info.get("UIDeviceFamily")
if families != [int(expected_family)]:
    raise SystemExit(f"Unexpected UIDeviceFamily: {families!r}; expected [{expected_family}]")
executable = info.get("CFBundleExecutable")
if not isinstance(executable, str) or not executable or executable in (".", "..") or "/" in executable or "\\" in executable:
    raise SystemExit(f"Unsafe CFBundleExecutable: {executable!r}")
print(executable)
PY
)"
readonly EXECUTABLE="${APP}/${EXECUTABLE_NAME}"
[[ -f "${EXECUTABLE}" && ! -L "${EXECUTABLE}" ]] || fail "Main executable is missing or unsafe"

readonly ARCHS="$(lipo -archs "${EXECUTABLE}" | xargs)"
[[ "${ARCHS}" == "arm64" ]] || fail "Expected only arm64, found: ${ARCHS}"

while IFS= read -r -d '' candidate; do
  if file -b "${candidate}" | grep -q 'Mach-O'; then
    [[ "${candidate}" == "${EXECUTABLE}" ]] || fail "Unexpected Mach-O code object: ${candidate}"
  fi
done < <(find "${APP}" -type f -print0)

codesign \
  --force \
  --sign - \
  --timestamp=none \
  --entitlements "${ENTITLEMENTS_CONTRACT}" \
  --generate-entitlement-der \
  "${APP}"
codesign --verify --strict --verbose=2 "${APP}"

readonly CODESIGN_DETAILS="$(codesign -dvv "${APP}" 2>&1)"
grep -q '^Signature=adhoc$' <<< "${CODESIGN_DETAILS}" || fail "The app is not ad-hoc signed"
if grep -q '^Authority=' <<< "${CODESIGN_DETAILS}"; then
  fail "Unexpected certificate authority in ad-hoc signature"
fi

codesign -d --entitlements :- "${APP}" > "${SIGNED_ENTITLEMENTS}" 2>/dev/null
verify_entitlements "${SIGNED_ENTITLEMENTS}"

cp -R "${APP}" "${PAYLOAD}/CangJie.app"
cd "${OUT}"
zip -qry "${IPA_NAME}" Payload
unzip -tq "${IPA_NAME}"

python3 - "${IPA_NAME}" <<'PY'
import stat
import sys
import zipfile
from pathlib import PurePosixPath

archive = sys.argv[1]
root_app = "Payload/CangJie.app/"
with zipfile.ZipFile(archive) as package:
    entries = package.infolist()
    if not entries:
        raise SystemExit("IPA is empty")
    for entry in entries:
        name = entry.filename
        path = PurePosixPath(name)
        if "\\" in name or path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
            raise SystemExit(f"Unsafe IPA entry: {name!r}")
        mode = (entry.external_attr >> 16) & 0xFFFF
        if stat.S_IFMT(mode) == stat.S_IFLNK:
            raise SystemExit(f"IPA contains a symbolic link: {name!r}")
        if name not in ("Payload/", "Payload/CangJie.app/") and not name.startswith(root_app):
            raise SystemExit(f"Unexpected IPA entry outside the root app: {name!r}")
    root_apps = {
        name.split("/", 2)[1]
        for name in (entry.filename for entry in entries)
        if name.startswith("Payload/") and ".app/" in name
    }
    if root_apps != {"CangJie.app"}:
        raise SystemExit(f"IPA must contain exactly Payload/CangJie.app, found: {sorted(root_apps)!r}")
PY

readonly SHA256="$(shasum -a 256 "${IPA_NAME}" | awk '{print $1}')"
printf '%s  %s\n' "${SHA256}" "${IPA_NAME}" > CangJie-M0.sha256
shasum -a 256 --check --strict CangJie-M0.sha256

readonly XCODE_DESCRIPTION="$(xcodebuild -version | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/ $//')"
readonly SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
readonly COMMIT="$(git -C "${ROOT}" rev-parse HEAD 2>/dev/null || printf 'unknown')"

python3 - \
  build-manifest.json \
  "${IPA_NAME}" \
  "${SHA256}" \
  "${EXPECTED_BUNDLE_ID}" \
  "${COMMIT}" \
  "${XCODE_DESCRIPTION}" \
  "${SDK_VERSION}" \
  "${ARCHS}" \
  "${EXPECTED_DEPLOYMENT_TARGET}" \
  "${EXPECTED_DEVICE_FAMILY}" \
  "${EXPECTED_GRDB_VERSION}" \
  "${EXPECTED_GRDB_REVISION}" \
  "${EXPECTED_GRDB_BUNDLE_NAME}" \
  "${EXPECTED_GRDB_PRIVACY_SHA256}" \
  "${GITHUB_REPOSITORY:-unknown}" \
  "${GITHUB_REF:-unknown}" \
  "${GITHUB_RUN_ID:-unknown}" \
  "${GITHUB_RUN_NUMBER:-unknown}" \
  "${GITHUB_WORKFLOW:-unknown}" \
  "${BUILD_REASON:-unspecified}" <<'PY'
import datetime
import json
import sys

(
    output,
    artifact,
    sha256,
    bundle_identifier,
    commit,
    xcode,
    sdk_version,
    architectures,
    deployment_target,
    device_family,
    grdb_version,
    grdb_revision,
    grdb_bundle,
    grdb_privacy_sha256,
    repository,
    git_ref,
    run_id,
    run_number,
    workflow,
    reason,
) = sys.argv[1:]

entitlements = {
    "application-identifier": bundle_identifier,
    "keychain-access-groups": [bundle_identifier],
}
manifest = {
    "schemaVersion": 2,
    "artifact": artifact,
    "sha256": sha256,
    "bundleIdentifier": bundle_identifier,
    "commit": commit,
    "repository": repository,
    "ref": git_ref,
    "workflow": workflow,
    "runId": run_id,
    "runNumber": run_number,
    "reason": reason,
    "builtAtUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "xcode": xcode,
    "iPhoneOSSDK": sdk_version,
    "architectures": architectures.split(),
    "deploymentTarget": deployment_target,
    "deviceFamily": [int(device_family)],
    "dependencies": [
        {
            "identity": "grdb.swift",
            "version": grdb_version,
            "revision": grdb_revision,
            "resourceBundle": grdb_bundle,
            "privacyManifestSHA256": grdb_privacy_sha256,
        }
    ],
    "signing": {
        "type": "ad-hoc",
        "appleDeveloperCertificate": False,
        "provisioningProfile": False,
        "appleTeamIdentifier": None,
        "contract": "trollstore-prefixless-bundle-id",
        "entitlements": entitlements,
    },
    "acceptance": {
        "status": "blocked-pending-trollstore-device-keychain-validation",
        "failClosed": True,
        "requiredChecks": [
            "Install this exact SHA-256 IPA with TrollStore on the target device",
            "Confirm the installed application-identifier is the prefixless bundle identifier",
            "Confirm keychain create, read, update, delete, reinstall persistence, and isolation",
        ],
        "reason": "No Apple Team ID exists in this ad-hoc contract; device keychain behavior cannot be proven by macOS CI.",
    },
}
with open(output, "w", encoding="utf-8", newline="\n") as destination:
    json.dump(manifest, destination, ensure_ascii=False, indent=2, sort_keys=True)
    destination.write("\n")
PY

python3 -m json.tool build-manifest.json >/dev/null
printf 'Built %s (%s); device keychain acceptance remains fail-closed\n' "${IPA_NAME}" "${SHA256}"
