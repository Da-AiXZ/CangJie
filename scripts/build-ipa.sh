#!/bin/bash
set -euo pipefail

readonly EXPECTED_BUNDLE_ID="com.juyang.CangJie"
readonly EXPECTED_DEPLOYMENT_TARGET="16.6"
readonly EXPECTED_DEVICE_FAMILY="2"
readonly EXPECTED_GRDB_VERSION="6.29.3"
readonly EXPECTED_GRDB_REVISION="2cf6c756e1e5ef6901ebae16576a7e4e4b834622"
readonly EXPECTED_GRDB_BUNDLE_NAME="GRDB_GRDB.bundle"
readonly EXPECTED_GRDB_BUNDLE_IDENTIFIER="grdb.swift.GRDB.resources"
readonly EXPECTED_GRDB_URL="https://github.com/groue/GRDB.swift.git"
readonly EXPECTED_GRDB_PRIVACY_SHA256="17784da62e51f74c5859df32fe402e01e25cdf6f797a4add06e2a3ce15c911f4"
readonly EXPECTED_LDID_TAG="v2.1.5-procursus7"
readonly EXPECTED_LDID_ARM64_ASSET="ldid_macosx_arm64"
readonly EXPECTED_LDID_ARM64_SHA256="5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50"
readonly EXPECTED_LDID_X86_64_ASSET="ldid_macosx_x86_64"
readonly EXPECTED_LDID_X86_64_SHA256="9d46e0feedf96e399edfca09872802ba21e729f79c01927ad25ea2b0a35bca23"
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly OUT="${ROOT}/.build-ipa"
readonly DERIVED="${OUT}/DerivedData"
readonly SOURCE_PACKAGES="${OUT}/SourcePackages"
readonly PAYLOAD="${OUT}/Payload"
readonly IPA_NAME="CangJie-M0.ipa"
readonly ENTITLEMENTS_CONTRACT="${ROOT}/App/Config/CangJie.entitlements"
readonly PACKAGE_RESOLVED="${ROOT}/CangJie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly SIGNED_ENTITLEMENTS="${OUT}/signed-entitlements.plist"
readonly SIGNING_ENTITLEMENTS="${OUT}/entitlements-contract.plist"

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
expected = {"schemaVersion": 2, "packages": [{"identity": "grdb.swift", "repositoryURL": url, "tag": "v6.29.3", "version": "6.29.3", "revision": revision, "resourceBundle": {"name": "GRDB_GRDB.bundle", "identifier": "grdb.swift.GRDB.resources", "privacyManifestSHA256": "17784da62e51f74c5859df32fe402e01e25cdf6f797a4add06e2a3ce15c911f4"}}]}
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
verify_entitlements() {
  require_tool python3
  local path="$1"
  [[ -f "${path}" && ! -L "${path}" ]] || fail "Entitlements file is missing or unsafe: ${path}"
  python3 - "${path}" "${EXPECTED_BUNDLE_ID}" <<'PY'
import plistlib
import sys

path, bundle_identifier = sys.argv[1:]
try:
    with open(path, "rb") as source:
        entitlements = plistlib.load(source)
except (OSError, ValueError, TypeError, plistlib.InvalidFileException):
    raise SystemExit("Entitlements file is not a valid plist") from None

expected = {
    "application-identifier": bundle_identifier,
    "keychain-access-groups": [bundle_identifier],
}
if entitlements != expected:
    raise SystemExit(f"Entitlement contract mismatch: {entitlements!r}")
PY
}

verify_entitlements_contract_unchanged() {
  local expected_sha256="$1"
  local actual_sha256
  actual_sha256="$(shasum -a 256 "${ENTITLEMENTS_CONTRACT}" | awk '{print $1}')"
  [[ "${actual_sha256}" == "${expected_sha256}" ]] || fail "Entitlements contract was modified during project generation or build: ${actual_sha256}"
  verify_entitlements "${ENTITLEMENTS_CONTRACT}"
}

verify_code_signature() {
  require_tool codesign
  local app_path="$1"
  local diagnostics_path="$2"
  [[ -d "${app_path}" && ! -L "${app_path}" ]] || fail "Signed app bundle is missing or unsafe: ${app_path}"
  rm -f "${diagnostics_path}"
  if ! codesign --verify --strict --verbose=2 "${app_path}" >/dev/null 2>"${diagnostics_path}"; then
    cat "${diagnostics_path}" >&2
    rm -f "${diagnostics_path}"
    fail "Signed app failed strict codesign verification"
  fi
  rm -f "${diagnostics_path}"
}

extract_and_verify_signed_entitlements() {
  require_tool codesign
  local app_path="$1"
  local output_path="$2"
  local diagnostics_path="$3"
  [[ -d "${app_path}" && ! -L "${app_path}" ]] || fail "Signed app bundle is missing or unsafe: ${app_path}"
  [[ "${output_path}" != "${diagnostics_path}" ]] || fail "Entitlement output and diagnostics paths must differ"
  rm -f "${output_path}" "${diagnostics_path}"

  if ! codesign --display --entitlements - --xml "${app_path}" >"${output_path}" 2>"${diagnostics_path}"; then
    cat "${diagnostics_path}" >&2
    rm -f "${output_path}" "${diagnostics_path}"
    fail "Failed to extract signed entitlements"
  fi
  if [[ ! -s "${output_path}" ]]; then
    rm -f "${output_path}" "${diagnostics_path}"
    fail "codesign returned no signed entitlements"
  fi
  if ! verify_entitlements "${output_path}"; then
    rm -f "${diagnostics_path}"
    return 1
  fi
  rm -f "${diagnostics_path}"
}

verify_executable_signature() {
  require_tool codesign
  local executable_path="$1"
  local diagnostics_path="$2"
  [[ -f "${executable_path}" && ! -L "${executable_path}" ]] || fail "Signed executable is missing or unsafe: ${executable_path}"
  rm -f "${diagnostics_path}"
  if ! codesign --verify --strict --verbose=2 "${executable_path}" >/dev/null 2>"${diagnostics_path}"; then
    cat "${diagnostics_path}" >&2
    rm -f "${diagnostics_path}"
    fail "Signed executable failed strict codesign verification"
  fi
  rm -f "${diagnostics_path}"
}

extract_and_verify_codesign_executable_entitlements() {
  require_tool codesign
  local executable_path="$1"
  local output_path="$2"
  local diagnostics_path="$3"
  [[ -f "${executable_path}" && ! -L "${executable_path}" ]] || fail "Signed executable is missing or unsafe: ${executable_path}"
  [[ "${output_path}" != "${diagnostics_path}" ]] || fail "Entitlement output and diagnostics paths must differ"
  rm -f "${output_path}" "${diagnostics_path}"

  if ! codesign --display --entitlements - --xml "${executable_path}" >"${output_path}" 2>"${diagnostics_path}"; then
    cat "${diagnostics_path}" >&2
    rm -f "${output_path}" "${diagnostics_path}"
    fail "Failed to extract executable entitlements with codesign"
  fi
  if [[ ! -s "${output_path}" ]]; then
    rm -f "${output_path}" "${diagnostics_path}"
    fail "codesign returned no executable entitlements"
  fi
  if ! verify_entitlements "${output_path}"; then
    rm -f "${diagnostics_path}"
    return 1
  fi
  rm -f "${diagnostics_path}"
}

extract_and_verify_ldid_entitlements() {
  local ldid_path="$1"
  local executable_path="$2"
  local output_path="$3"
  local diagnostics_path="$4"
  [[ -x "${ldid_path}" && -f "${ldid_path}" && ! -L "${ldid_path}" ]] || fail "ldid executable is missing or unsafe: ${ldid_path}"
  [[ -f "${executable_path}" && ! -L "${executable_path}" ]] || fail "Signed executable is missing or unsafe: ${executable_path}"
  [[ "${output_path}" != "${diagnostics_path}" ]] || fail "Entitlement output and diagnostics paths must differ"
  rm -f "${output_path}" "${diagnostics_path}"

  if ! "${ldid_path}" -e "${executable_path}" >"${output_path}" 2>"${diagnostics_path}"; then
    cat "${diagnostics_path}" >&2
    rm -f "${output_path}" "${diagnostics_path}"
    fail "Failed to extract ldid-signed entitlements"
  fi
  if [[ ! -s "${output_path}" ]]; then
    rm -f "${output_path}" "${diagnostics_path}"
    fail "ldid returned no signed entitlements"
  fi
  if ! verify_entitlements "${output_path}"; then
    rm -f "${diagnostics_path}"
    return 1
  fi
  rm -f "${diagnostics_path}"
}

compile_designated_requirement() {
  require_tool csreq
  local identifier="$1"
  local output_path="$2"
  local diagnostics_path="$3"
  [[ "${identifier}" =~ ^[A-Za-z0-9.-]+$ ]] || fail "Unsafe code-signing identifier: ${identifier}"
  [[ "${output_path}" != "${diagnostics_path}" ]] || fail "Requirement output and diagnostics paths must differ"
  rm -f "${output_path}" "${diagnostics_path}"
  local requirement_text="=designated => identifier \"${identifier}\""
  if ! csreq -r "${requirement_text}" -b "${output_path}" >/dev/null 2>"${diagnostics_path}"; then
    cat "${diagnostics_path}" >&2
    rm -f "${output_path}" "${diagnostics_path}"
    fail "Failed to compile the designated requirement"
  fi
  [[ -s "${output_path}" && -f "${output_path}" && ! -L "${output_path}" ]] || fail "Compiled designated requirement is missing or unsafe"
  rm -f "${diagnostics_path}"
}

sign_executable_with_ldid() {
  local ldid_path="$1"
  local entitlements_path="$2"
  local executable_path="$3"
  local diagnostics_root="$4"
  [[ -x "${ldid_path}" && -f "${ldid_path}" && ! -L "${ldid_path}" ]] || fail "ldid executable is missing or unsafe: ${ldid_path}"
  [[ -f "${entitlements_path}" && ! -L "${entitlements_path}" ]] || fail "Entitlements file is missing or unsafe: ${entitlements_path}"
  [[ -f "${executable_path}" && ! -L "${executable_path}" ]] || fail "Main executable is missing or unsafe: ${executable_path}"
  mkdir -p "${diagnostics_root}"
  local signing_diagnostics="${diagnostics_root}/ldid-sign.stderr"
  local extracted_entitlements="${diagnostics_root}/ldid-entitlements.plist"
  local extraction_diagnostics="${diagnostics_root}/ldid-entitlements.stderr"
  local codesign_diagnostics="${diagnostics_root}/codesign-executable-verify.stderr"
  local codesign_entitlements="${diagnostics_root}/codesign-executable-entitlements.plist"
  local codesign_entitlements_diagnostics="${diagnostics_root}/codesign-executable-entitlements.stderr"
  local requirements_path="${diagnostics_root}/designated-requirement.bin"
  local requirements_diagnostics="${diagnostics_root}/csreq.stderr"
  rm -f "${signing_diagnostics}" "${extracted_entitlements}" "${extraction_diagnostics}" "${codesign_diagnostics}" "${codesign_entitlements}" "${codesign_entitlements_diagnostics}" "${requirements_path}" "${requirements_diagnostics}"
  compile_designated_requirement "${EXPECTED_BUNDLE_ID}" "${requirements_path}" "${requirements_diagnostics}"

  if ! "${ldid_path}" -Cadhoc "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-S${entitlements_path}" "${executable_path}" >/dev/null 2>"${signing_diagnostics}"; then
    cat "${signing_diagnostics}" >&2
    rm -f "${signing_diagnostics}"
    fail "ldid failed to sign the main executable"
  fi
  rm -f "${signing_diagnostics}"
  verify_executable_signature "${executable_path}" "${codesign_diagnostics}"
  extract_and_verify_ldid_entitlements "${ldid_path}" "${executable_path}" "${extracted_entitlements}" "${extraction_diagnostics}"
  extract_and_verify_codesign_executable_entitlements "${executable_path}" "${codesign_entitlements}" "${codesign_entitlements_diagnostics}"
}


verify_code_resources() {
  local app_path="$1"
  local resources_path="${app_path}/_CodeSignature/CodeResources"
  [[ -f "${resources_path}" && ! -L "${resources_path}" && -s "${resources_path}" ]] || fail "Signed app CodeResources is missing, unsafe, or empty: ${resources_path}"
}

sign_app_with_ldid() {
  local ldid_path="$1"
  local entitlements_path="$2"
  local app_path="$3"
  local executable_path="$4"
  local diagnostics_root="$5"
  [[ -x "${ldid_path}" && -f "${ldid_path}" && ! -L "${ldid_path}" ]] || fail "ldid executable is missing or unsafe: ${ldid_path}"
  [[ -f "${entitlements_path}" && ! -L "${entitlements_path}" ]] || fail "Entitlements file is missing or unsafe: ${entitlements_path}"
  [[ -d "${app_path}" && ! -L "${app_path}" ]] || fail "App bundle is missing or unsafe: ${app_path}"
  [[ -f "${executable_path}" && ! -L "${executable_path}" ]] || fail "Main executable is missing or unsafe: ${executable_path}"
  [[ "${executable_path}" == "${app_path}/"* ]] || fail "Main executable is outside the app bundle: ${executable_path}"
  mkdir -p "${diagnostics_root}"
  local shallow_signing_diagnostics="${diagnostics_root}/ldid-app-shallow-sign.stderr"
  local executable_signing_diagnostics="${diagnostics_root}/ldid-app-executable-sign.stderr"
  local app_codesign_diagnostics="${diagnostics_root}/codesign-app-verify.stderr"
  local executable_codesign_diagnostics="${diagnostics_root}/codesign-executable-verify.stderr"
  local extracted_entitlements="${diagnostics_root}/ldid-entitlements.plist"
  local extraction_diagnostics="${diagnostics_root}/ldid-entitlements.stderr"
  local codesign_entitlements="${diagnostics_root}/codesign-executable-entitlements.plist"
  local codesign_entitlements_diagnostics="${diagnostics_root}/codesign-executable-entitlements.stderr"
  local requirements_path="${diagnostics_root}/designated-requirement.bin"
  local requirements_diagnostics="${diagnostics_root}/csreq.stderr"
  local info_path="${app_path}/Info.plist"
  local resources_path="${app_path}/_CodeSignature/CodeResources"
  local pre_sign_executable="${diagnostics_root}/pre-sign-executable"
  [[ -f "${info_path}" && ! -L "${info_path}" ]] || fail "App Info.plist is missing or unsafe: ${info_path}"
  rm -f "${shallow_signing_diagnostics}" "${executable_signing_diagnostics}" "${app_codesign_diagnostics}" "${executable_codesign_diagnostics}" "${extracted_entitlements}" "${extraction_diagnostics}" "${codesign_entitlements}" "${codesign_entitlements_diagnostics}" "${requirements_path}" "${requirements_diagnostics}"
  compile_designated_requirement "${EXPECTED_BUNDLE_ID}" "${requirements_path}" "${requirements_diagnostics}"

  if [[ "${LDID_DIAGNOSTICS:-0}" == "1" ]]; then
    cp -p "${executable_path}" "${pre_sign_executable}"
  else
    rm -f "${pre_sign_executable}"
  fi

  if [[ "${LDID_DIAGNOSTICS:-0}" == "1" ]]; then
    # Xcode may leave a linker-produced LC_CODE_SIGNATURE or entitlement blob
    # on the device executable. Capture its pre-ldid state so a future signing
    # failure distinguishes an input Mach-O problem from an ldid output problem.
    printf '%s\n' 'ldid pre-sign diagnostic: executable file' >&2
    file "${executable_path}" >&2 || true
    printf '%s\n' 'ldid pre-sign diagnostic: entitlement input' >&2
    wc -c "${entitlements_path}" >&2 || true
    shasum -a 256 "${entitlements_path}" >&2 || true
    plutil -p "${entitlements_path}" >&2 || true
    printf '%s\n' 'ldid pre-sign diagnostic: ldid entitlements' >&2
    "${ldid_path}" -e "${executable_path}" >&2 || true
    printf '%s\n' 'ldid pre-sign diagnostic: codesign details' >&2
    codesign -dvv "${executable_path}" >&2 || true
    printf '%s\n' 'ldid pre-sign diagnostic: codesign entitlements' >&2
    codesign --display --entitlements - --xml "${executable_path}" >&2 || true
    printf '%s\n' 'ldid pre-sign diagnostic: designated requirement' >&2
    codesign -d -r- "${executable_path}" >&2 || true
    if command -v otool >/dev/null 2>&1; then
      printf '%s\n' 'ldid pre-sign diagnostic: signature load command' >&2
      otool -l "${executable_path}" | awk '/cmd LC_CODE_SIGNATURE/{show=1; count=0} show{print; count++} count==8{show=0}' >&2 || true
    fi
  fi

  # Procursus ldid v2.1.5-procursus7 hard-codes flags=0 for the executable
  # when it is reached through bundle signing. Use that mode only to produce
  # the resource seal, then sign the executable directly with CS_ADHOC and
  # explicitly bind Info.plist and CodeResources as special slots.
  if ! "${ldid_path}" -w "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-S${entitlements_path}" "${app_path}" >/dev/null 2>"${shallow_signing_diagnostics}"; then
    cat "${shallow_signing_diagnostics}" >&2
    rm -f "${shallow_signing_diagnostics}"
    fail "ldid failed to shallow-sign the app bundle"
  fi
  rm -f "${shallow_signing_diagnostics}"
  verify_code_resources "${app_path}"

  if ! "${ldid_path}" -Cadhoc "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-E1:${info_path}" "-E3:${resources_path}" "-S${entitlements_path}" "${executable_path}" >/dev/null 2>"${executable_signing_diagnostics}"; then
    cat "${executable_signing_diagnostics}" >&2
    rm -f "${executable_signing_diagnostics}"
    fail "ldid failed to ad-hoc sign the app executable"
  fi
  rm -f "${executable_signing_diagnostics}"
  verify_code_signature "${app_path}" "${app_codesign_diagnostics}"
  verify_executable_signature "${executable_path}" "${executable_codesign_diagnostics}"
  if ! extract_and_verify_ldid_entitlements "${ldid_path}" "${executable_path}" "${extracted_entitlements}" "${extraction_diagnostics}"; then
    if [[ "${LDID_DIAGNOSTICS:-0}" == "1" && -f "${pre_sign_executable}" ]]; then
      printf '%s\n' 'ldid entitlement diagnostic: variant experiments' >&2
      copied_entitlements="${diagnostics_root}/variant-entitlements.plist"
      cp -p "${entitlements_path}" "${copied_entitlements}"
      for variant in minimal copied-entitlements no-special-slots merge-with-special-slots remove-then-sign; do
        variant_path="${diagnostics_root}/variant-${variant}"
        cp -p "${pre_sign_executable}" "${variant_path}"
        case "${variant}" in
          minimal)
            "${ldid_path}" -Cadhoc "-S${entitlements_path}" "${variant_path}" >/dev/null 2>"${diagnostics_root}/variant-${variant}.stderr" || true
            ;;
          copied-entitlements)
            "${ldid_path}" -Cadhoc "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-S${copied_entitlements}" "${variant_path}" >/dev/null 2>"${diagnostics_root}/variant-${variant}.stderr" || true
            ;;
          no-special-slots)
            "${ldid_path}" -Cadhoc "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-S${entitlements_path}" "${variant_path}" >/dev/null 2>"${diagnostics_root}/variant-${variant}.stderr" || true
            ;;
          merge-with-special-slots)
            "${ldid_path}" -Cadhoc -M "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-E1:${info_path}" "-E3:${resources_path}" "-S${entitlements_path}" "${variant_path}" >/dev/null 2>"${diagnostics_root}/variant-${variant}.stderr" || true
            ;;
          remove-then-sign)
            "${ldid_path}" -r "${variant_path}" >/dev/null 2>"${diagnostics_root}/variant-${variant}.stderr" || true
            "${ldid_path}" -Cadhoc "-I${EXPECTED_BUNDLE_ID}" "-Q${requirements_path}" "-E1:${info_path}" "-E3:${resources_path}" "-S${entitlements_path}" "${variant_path}" >>"${diagnostics_root}/variant-${variant}.stdout" 2>>"${diagnostics_root}/variant-${variant}.stderr" || true
            ;;
        esac
        printf 'variant=%s ldid-entitlements\n' "${variant}" >&2
        "${ldid_path}" -e "${variant_path}" >&2 || true
        printf 'variant=%s codesign-details\n' "${variant}" >&2
        codesign -dvv "${variant_path}" >&2 || true
        printf 'variant=%s codesign-entitlements\n' "${variant}" >&2
        codesign --display --entitlements - --xml "${variant_path}" >&2 || true
        cat "${diagnostics_root}/variant-${variant}.stderr" >&2 || true
      done
    fi
    printf '%s\n' 'ldid entitlement diagnostic: raw extraction' >&2
    cat "${extracted_entitlements}" >&2 || true
    printf '%s\n' 'ldid entitlement diagnostic: codesign details' >&2
    codesign -dvv "${executable_path}" >&2 || true
    fail "ldid entitlement verification failed for the app executable"
  fi
  if ! extract_and_verify_codesign_executable_entitlements "${executable_path}" "${codesign_entitlements}" "${codesign_entitlements_diagnostics}"; then
    printf '%s\n' 'codesign entitlement diagnostic: raw extraction' >&2
    cat "${codesign_entitlements}" >&2 || true
    printf '%s\n' 'codesign entitlement diagnostic: ldid extraction' >&2
    "${ldid_path}" -e "${executable_path}" >&2 || true
    fail "codesign entitlement verification failed for the app executable"
  fi
}

verify_final_executable() {
  require_tool shasum
  require_tool codesign
  local ldid_path="$1"
  local executable_path="$2"
  local expected_sha256="$3"
  local diagnostics_root="$4"
  [[ "${expected_sha256}" =~ ^[0-9a-f]{64}$ ]] || fail "Invalid expected executable SHA-256"
  [[ -f "${executable_path}" && ! -L "${executable_path}" && -x "${executable_path}" ]] || fail "Final executable is missing, unsafe, or not executable: ${executable_path}"
  local actual_sha256
  actual_sha256="$(shasum -a 256 "${executable_path}" | awk '{print $1}')"
  [[ "${actual_sha256}" == "${expected_sha256}" ]] || fail "Final executable SHA-256 mismatch: ${actual_sha256}"
  mkdir -p "${diagnostics_root}"
  verify_executable_signature "${executable_path}" "${diagnostics_root}/codesign-verify.stderr"
  extract_and_verify_ldid_entitlements "${ldid_path}" "${executable_path}" "${diagnostics_root}/ldid-entitlements.plist" "${diagnostics_root}/ldid-entitlements.stderr"
  extract_and_verify_codesign_executable_entitlements "${executable_path}" "${diagnostics_root}/codesign-entitlements.plist" "${diagnostics_root}/codesign-entitlements.stderr"
  local codesign_details
  codesign_details="$(codesign -dvv "${executable_path}" 2>&1)" || fail "Failed to inspect final executable signature"
  grep -q '^Signature=adhoc$' <<< "${codesign_details}" || fail "The final executable is not ad-hoc signed"
  if grep -q '^Authority=' <<< "${codesign_details}"; then
    fail "Unexpected certificate authority in final executable signature"
  fi
}

verify_pinned_ldid_tool() {
  require_tool file
  require_tool lipo
  require_tool shasum
  local ldid_path="$1"
  [[ -x "${ldid_path}" && -f "${ldid_path}" && ! -L "${ldid_path}" ]] || fail "ldid executable is missing or unsafe: ${ldid_path}"
  local host_arch expected_arch expected_asset expected_sha256
  host_arch="$(uname -m)"
  case "${host_arch}" in
    arm64|aarch64)
      expected_arch="arm64"
      expected_asset="${EXPECTED_LDID_ARM64_ASSET}"
      expected_sha256="${EXPECTED_LDID_ARM64_SHA256}"
      ;;
    x86_64|amd64)
      expected_arch="x86_64"
      expected_asset="${EXPECTED_LDID_X86_64_ASSET}"
      expected_sha256="${EXPECTED_LDID_X86_64_SHA256}"
      ;;
    *)
      fail "Unsupported macOS host architecture for ldid: ${host_arch}"
      ;;
  esac
  local actual_sha256 actual_archs
  actual_sha256="$(shasum -a 256 "${ldid_path}" | awk '{print $1}')"
  [[ "${actual_sha256}" == "${expected_sha256}" ]] || fail "Pinned ldid SHA-256 mismatch: ${actual_sha256}"
  actual_archs="$(lipo -archs "${ldid_path}" | xargs)"
  [[ "${actual_archs}" == "${expected_arch}" ]] || fail "Pinned ldid architecture mismatch: ${actual_archs}"
  file -b "${ldid_path}" | grep -q 'Mach-O' || fail "Pinned ldid is not a Mach-O executable"
  printf '%s %s %s\n' "${expected_asset}" "${expected_sha256}" "${expected_arch}"
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
  python3 - "${bundle_path}" "${EXPECTED_GRDB_BUNDLE_IDENTIFIER}" <<'PY'
import os
import plistlib
import sys
from pathlib import Path
bundle = Path(sys.argv[1])
expected_identifier = sys.argv[2]
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
if identifier != expected_identifier:
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
  --verify-grdb-resource-bundle)
    [[ "$#" == "2" && -n "${2:-}" ]] || fail "Usage: $0 --verify-grdb-resource-bundle <GRDB_GRDB.bundle>"
    verify_grdb_resource_bundle "$2"
    exit 0
    ;;
  --verify-entitlements)
    [[ "$#" == "2" && -n "${2:-}" ]] || fail "Usage: $0 --verify-entitlements <entitlements.plist>"
    verify_entitlements "$2"
    exit 0
    ;;
  --verify-signed-entitlements)
    [[ "$#" == "2" && -n "${2:-}" ]] || fail "Usage: $0 --verify-signed-entitlements <App.app>"
    verification_root="$(mktemp -d)"
    trap 'rm -rf "${verification_root}"' EXIT
    verify_code_signature "$2" "${verification_root}/codesign-verify.stderr"
    extract_and_verify_signed_entitlements "$2" "${verification_root}/signed-entitlements.plist" "${verification_root}/codesign-entitlements.stderr"
    exit 0
    ;;
  --sign-with-ldid)
    [[ "$#" == "4" && -n "${2:-}" && -n "${3:-}" && -n "${4:-}" ]] || fail "Usage: $0 --sign-with-ldid <ldid> <entitlements.plist> <executable>"
    verification_root="$(mktemp -d)"
    trap 'rm -rf "${verification_root}"' EXIT
    sign_executable_with_ldid "$2" "$3" "$4" "${verification_root}"
    exit 0
    ;;
  --sign-app-with-ldid)
    [[ "$#" == "5" && -n "${2:-}" && -n "${3:-}" && -n "${4:-}" && -n "${5:-}" ]] || fail "Usage: $0 --sign-app-with-ldid <ldid> <entitlements.plist> <App.app> <executable>"
    verification_root="$(mktemp -d)"
    trap 'rm -rf "${verification_root}"' EXIT
    sign_app_with_ldid "$2" "$3" "$4" "$5" "${verification_root}"
    exit 0
    ;;
  --verify-final-executable)
    [[ "$#" == "4" && -n "${2:-}" && -n "${3:-}" && -n "${4:-}" ]] || fail "Usage: $0 --verify-final-executable <ldid> <executable> <expected-sha256>"
    verification_root="$(mktemp -d)"
    trap 'rm -rf "${verification_root}"' EXIT
    verify_final_executable "$2" "$3" "$4" "${verification_root}"
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
for tool in xcodegen xcodebuild xcrun lipo codesign file git python3 zip unzip shasum cmp; do
  require_tool "${tool}"
done
verify_dependency_contract
verify_entitlements "${ENTITLEMENTS_CONTRACT}"
readonly ENTITLEMENTS_CONTRACT_SHA256="$(shasum -a 256 "${ENTITLEMENTS_CONTRACT}" | awk '{print $1}')"

rm -rf "${OUT}"
mkdir -p "${PAYLOAD}"
cp -p "${ENTITLEMENTS_CONTRACT}" "${SIGNING_ENTITLEMENTS}"
verify_entitlements "${SIGNING_ENTITLEMENTS}"
cd "${ROOT}"

xcodegen generate --spec project.yml
verify_entitlements_contract_unchanged "${ENTITLEMENTS_CONTRACT_SHA256}"
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

readonly APP_GIT_COMMIT="$(git -C "${ROOT}" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
readonly APP_BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
[[ "${APP_BUILD_NUMBER}" =~ ^[0-9]+$ ]] || fail "Build number must be numeric: ${APP_BUILD_NUMBER}"

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
  CODE_SIGN_IDENTITY="" \
  CANGJIE_GIT_COMMIT="${APP_GIT_COMMIT}" \
  CURRENT_PROJECT_VERSION="${APP_BUILD_NUMBER}"

verify_entitlements_contract_unchanged "${ENTITLEMENTS_CONTRACT_SHA256}"

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

readonly EXECUTABLE_NAME="$(python3 - "${INFO_PLIST}" "${EXPECTED_BUNDLE_ID}" "${EXPECTED_DEPLOYMENT_TARGET}" "${EXPECTED_DEVICE_FAMILY}" "${APP_GIT_COMMIT}" "${APP_BUILD_NUMBER}" <<'PY'
import plistlib
import sys

path, expected_bundle_id, expected_target, expected_family, expected_commit, expected_build = sys.argv[1:7]
with open(path, "rb") as source:
    info = plistlib.load(source)
checks = {
    "CFBundleIdentifier": expected_bundle_id,
    "MinimumOSVersion": expected_target,
    "CangJieGitCommit": expected_commit,
    "CFBundleVersion": expected_build,
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

readonly LDID_PATH="${LDID_PATH:-}"
[[ -n "${LDID_PATH}" ]] || fail "LDID_PATH must point to the pinned Procursus ldid executable"
if ! LDID_METADATA="$(verify_pinned_ldid_tool "${LDID_PATH}")"; then
  fail "Pinned ldid verification failed"
fi
readonly LDID_METADATA
read -r LDID_ASSET LDID_SHA256 LDID_ARCH LDID_EXTRA <<< "${LDID_METADATA}"
[[ -n "${LDID_ASSET}" && -n "${LDID_SHA256}" && -n "${LDID_ARCH}" && -z "${LDID_EXTRA}" ]] || fail "Invalid pinned ldid metadata"
readonly LDID_ASSET LDID_SHA256 LDID_ARCH
readonly UNSIGNED_EXECUTABLE_SHA256="$(shasum -a 256 "${EXECUTABLE}" | awk '{print $1}')"
sign_app_with_ldid "${LDID_PATH}" "${SIGNING_ENTITLEMENTS}" "${APP}" "${EXECUTABLE}" "${OUT}/signing"
readonly SIGNED_EXECUTABLE_SHA256="$(shasum -a 256 "${EXECUTABLE}" | awk '{print $1}')"
[[ "${SIGNED_EXECUTABLE_SHA256}" != "${UNSIGNED_EXECUTABLE_SHA256}" ]] || fail "ldid did not change the main executable signature"

readonly CODESIGN_DETAILS="$(codesign -dvv "${EXECUTABLE}" 2>&1)"
grep -q '^Signature=adhoc$' <<< "${CODESIGN_DETAILS}" || fail "The main executable is not ad-hoc signed"
if grep -q '^Authority=' <<< "${CODESIGN_DETAILS}"; then
  fail "Unexpected certificate authority in ad-hoc signature"
fi

cp "${OUT}/signing/ldid-entitlements.plist" "${SIGNED_ENTITLEMENTS}"

cp -R "${APP}" "${PAYLOAD}/CangJie.app"
readonly PAYLOAD_APP="${PAYLOAD}/CangJie.app"
readonly PAYLOAD_EXECUTABLE="${PAYLOAD_APP}/${EXECUTABLE_NAME}"
verify_code_resources "${PAYLOAD_APP}"
mkdir -p "${OUT}/payload-verification"
verify_code_signature "${PAYLOAD_APP}" "${OUT}/payload-verification/codesign-app-verify.stderr"
extract_and_verify_signed_entitlements "${PAYLOAD_APP}" "${OUT}/payload-verification/app-entitlements.plist" "${OUT}/payload-verification/app-entitlements.stderr"
verify_final_executable "${LDID_PATH}" "${PAYLOAD_EXECUTABLE}" "${SIGNED_EXECUTABLE_SHA256}" "${OUT}/payload-verification"
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

readonly IPA_VERIFICATION_ROOT="${OUT}/ipa-verification"
[[ "${IPA_VERIFICATION_ROOT}" == "${OUT}/ipa-verification" && "${IPA_VERIFICATION_ROOT}" != "/" ]] || fail "Unsafe IPA verification path"
rm -rf "${IPA_VERIFICATION_ROOT}"
mkdir -p "${IPA_VERIFICATION_ROOT}"
unzip -q "${IPA_NAME}" -d "${IPA_VERIFICATION_ROOT}"
readonly FINAL_APP="${IPA_VERIFICATION_ROOT}/Payload/CangJie.app"
readonly FINAL_INFO_PLIST="${FINAL_APP}/Info.plist"
readonly FINAL_EXECUTABLE="${FINAL_APP}/${EXECUTABLE_NAME}"
[[ -d "${FINAL_APP}" && ! -L "${FINAL_APP}" ]] || fail "Final IPA app is missing or unsafe"
if find "${FINAL_APP}" -type l -print -quit | grep -q .; then
  fail "Final IPA app contains a symbolic link"
fi
cmp -s "${INFO_PLIST}" "${FINAL_INFO_PLIST}" || fail "Final IPA Info.plist differs from the validated build"
verify_code_resources "${FINAL_APP}"
mkdir -p "${OUT}/ipa-executable-verification"
verify_code_signature "${FINAL_APP}" "${OUT}/ipa-executable-verification/codesign-app-verify.stderr"
extract_and_verify_signed_entitlements "${FINAL_APP}" "${OUT}/ipa-executable-verification/app-entitlements.plist" "${OUT}/ipa-executable-verification/app-entitlements.stderr"
verify_final_executable "${LDID_PATH}" "${FINAL_EXECUTABLE}" "${SIGNED_EXECUTABLE_SHA256}" "${OUT}/ipa-executable-verification"
readonly FINAL_ARCHS="$(lipo -archs "${FINAL_EXECUTABLE}" | xargs)"
[[ "${FINAL_ARCHS}" == "arm64" ]] || fail "Final IPA executable architecture mismatch: ${FINAL_ARCHS}"
if find "${FINAL_APP}" -name 'embedded.mobileprovision' -print -quit | grep -q .; then
  fail "Unexpected provisioning profile in final IPA"
fi

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
  "${EXPECTED_GRDB_BUNDLE_IDENTIFIER}" \
  "${EXPECTED_GRDB_PRIVACY_SHA256}" \
  "${EXPECTED_LDID_TAG}" \
  "${LDID_ASSET}" \
  "${LDID_SHA256}" \
  "${LDID_ARCH}" \
  "${UNSIGNED_EXECUTABLE_SHA256}" \
  "${SIGNED_EXECUTABLE_SHA256}" \
  "${ENTITLEMENTS_CONTRACT_SHA256}" \
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
    grdb_bundle_identifier,
    grdb_privacy_sha256,
    ldid_tag,
    ldid_asset,
    ldid_sha256,
    ldid_architecture,
    unsigned_executable_sha256,
    signed_executable_sha256,
    entitlement_contract_sha256,
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
    "schemaVersion": 4,
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
            "resourceBundle": {
                "name": grdb_bundle,
                "identifier": grdb_bundle_identifier,
                "privacyManifestSHA256": grdb_privacy_sha256,
            },
        }
    ],
    "signing": {
        "type": "trollstore-fakesign",
        "signer": "ldid",
        "ldid": {
            "tag": ldid_tag,
            "asset": ldid_asset,
            "sha256": ldid_sha256,
            "architecture": ldid_architecture,
        },
        "unsignedExecutableSHA256": unsigned_executable_sha256,
        "signedExecutableSHA256": signed_executable_sha256,
        "entitlementContractSHA256": entitlement_contract_sha256,
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
