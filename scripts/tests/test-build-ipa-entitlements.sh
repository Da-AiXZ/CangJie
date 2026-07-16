#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
readonly BUILD_SCRIPT="${ROOT}/scripts/build-ipa.sh"
readonly CONTRACT="${ROOT}/App/Config/CangJie.entitlements"
readonly TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEMP_ROOT}"' EXIT

readonly FIXTURES="${TEMP_ROOT}/fixtures"
readonly BIN_DIR="${TEMP_ROOT}/bin"
readonly APP_PATH="${TEMP_ROOT}/App With Spaces.app"
mkdir -p "${FIXTURES}" "${BIN_DIR}" "${APP_PATH}"

python3 - "${FIXTURES}" <<'PY'
import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "application-identifier": "com.juyang.CangJie",
    "keychain-access-groups": ["com.juyang.CangJie"],
}
fixtures = {
    "valid.xml": expected,
    "valid.binary": expected,
    "empty.xml": {},
    "missing.xml": {"application-identifier": "com.juyang.CangJie"},
    "extra.xml": {**expected, "get-task-allow": True},
    "wrong-type.xml": {
        "application-identifier": ["com.juyang.CangJie"],
        "keychain-access-groups": "com.juyang.CangJie",
    },
    "extra-group.xml": {
        "application-identifier": "com.juyang.CangJie",
        "keychain-access-groups": ["com.juyang.CangJie", "com.juyang.Other"],
    },
}
for name, value in fixtures.items():
    fmt = plistlib.FMT_BINARY if name.endswith("binary") else plistlib.FMT_XML
    (root / name).write_bytes(plistlib.dumps(value, fmt=fmt, sort_keys=False))
(root / "invalid.txt").write_text("{}", encoding="utf-8")
PY

assert_success() {
  local label="$1"
  shift
  local stdout="${TEMP_ROOT}/${label}.stdout"
  local stderr="${TEMP_ROOT}/${label}.stderr"
  if ! "$@" >"${stdout}" 2>"${stderr}"; then
    echo "Expected success for ${label}" >&2
    cat "${stderr}" >&2
    exit 1
  fi
  [[ ! -s "${stdout}" ]] || { echo "Unexpected stdout for ${label}" >&2; cat "${stdout}" >&2; exit 1; }
  [[ ! -s "${stderr}" ]] || { echo "Unexpected stderr for ${label}" >&2; cat "${stderr}" >&2; exit 1; }
}

assert_failure() {
  local label="$1"
  local expected="$2"
  shift 2
  local stdout="${TEMP_ROOT}/${label}.stdout"
  local stderr="${TEMP_ROOT}/${label}.stderr"
  if "$@" >"${stdout}" 2>"${stderr}"; then
    echo "Expected failure for ${label}" >&2
    exit 1
  fi
  [[ ! -s "${stdout}" ]] || { echo "Failure leaked stdout for ${label}" >&2; cat "${stdout}" >&2; exit 1; }
  grep -F "${expected}" "${stderr}" >/dev/null || {
    echo "Unexpected error for ${label}" >&2
    cat "${stderr}" >&2
    exit 1
  }
  if grep -F 'Traceback' "${stderr}" >/dev/null; then
    echo "Python traceback leaked for ${label}" >&2
    cat "${stderr}" >&2
    exit 1
  fi
}

assert_success valid-xml bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/valid.xml"
assert_success valid-binary bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/valid.binary"
assert_failure empty-dictionary 'Entitlement contract mismatch: {}' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/empty.xml"
assert_failure invalid-plist 'Entitlements file is not a valid plist' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/invalid.txt"
assert_failure missing-key 'Entitlement contract mismatch' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/missing.xml"
assert_failure extra-key 'Entitlement contract mismatch' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/extra.xml"
assert_failure wrong-type 'Entitlement contract mismatch' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/wrong-type.xml"
assert_failure extra-group 'Entitlement contract mismatch' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/extra-group.xml"
assert_failure missing-file 'Entitlements file is missing or unsafe' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/missing.xml.nope"
assert_failure verify-entitlements-arity 'Usage:' bash "${BUILD_SCRIPT}" --verify-entitlements

if ln -s "${FIXTURES}/valid.xml" "${FIXTURES}/symlink.xml" 2>/dev/null && [[ -L "${FIXTURES}/symlink.xml" ]]; then
  assert_failure symlink-entitlements 'Entitlements file is missing or unsafe' bash "${BUILD_SCRIPT}" --verify-entitlements "${FIXTURES}/symlink.xml"
else
  printf 'entitlements symlink negative test skipped: host cannot create symbolic links\n' >&2
fi

cat >"${BIN_DIR}/codesign" <<'SH'
#!/bin/bash
set -euo pipefail
actual=("$@")
case "${actual[0]:-}" in
  --verify)
    expected=(--verify --strict --verbose=2 "${actual[$(( ${#actual[@]} - 1 ))]}")
    ;;
  --display)
    expected=(--display --entitlements - --xml "${actual[$(( ${#actual[@]} - 1 ))]}")
    ;;
  -dvv)
    expected=(-dvv "${actual[$(( ${#actual[@]} - 1 ))]}")
    ;;
  *)
    echo "unexpected codesign operation: ${actual[0]:-missing}" >&2
    exit 64
    ;;
esac
if [[ "${#actual[@]}" -ne "${#expected[@]}" ]]; then
  echo "unexpected codesign argument count: ${#actual[@]}" >&2
  exit 64
fi
for index in "${!expected[@]}"; do
  [[ "${actual[$index]}" == "${expected[$index]}" ]] || {
    printf 'unexpected codesign argument %s: %q expected %q\n' "$index" "${actual[$index]}" "${expected[$index]}" >&2
    exit 64
  }
done
target="${actual[$(( ${#actual[@]} - 1 ))]}"
case ":${FAKE_CODESIGN_ALLOWED_TARGETS:-${FAKE_CODESIGN_APP:?}}:" in
  *":${target}:"*) ;;
  *) echo "unexpected codesign target: ${target}" >&2; exit 64 ;;
esac
if [[ "${actual[0]}" == "--verify" ]]; then
  if [[ "${FAKE_CODESIGN_MODE:?}" == "invalid-signature" ]]; then
    echo 'codesign: simulated invalid signature' >&2
    exit 1
  fi
  echo 'fake app: valid on disk' >&2
  exit 0
fi
if [[ "${actual[0]}" == "-dvv" ]]; then
  echo 'Executable=fake' >&2
  echo 'Signature=adhoc' >&2
  exit 0
fi
case "${FAKE_CODESIGN_MODE:?}" in
  valid)
    cat "${FAKE_CODESIGN_VALID:?}"
    echo 'Executable=fake' >&2
    ;;
  empty-dictionary)
    cat "${FAKE_CODESIGN_EMPTY:?}"
    ;;
  empty-output)
    ;;
  stderr-only)
    cat "${FAKE_CODESIGN_VALID:?}" >&2
    ;;
  argument-error)
    echo 'codesign: simulated argument failure' >&2
    exit 2
    ;;
  partial-error)
    cat "${FAKE_CODESIGN_VALID:?}"
    echo 'codesign: simulated failure after output' >&2
    exit 3
    ;;
  *)
    echo "unknown fake mode" >&2
    exit 65
    ;;
esac
SH
chmod +x "${BIN_DIR}/codesign"

run_fake() {
  local mode="$1"
  shift
  PATH="${BIN_DIR}:${PATH}" \
    FAKE_CODESIGN_APP="${APP_PATH}" \
    FAKE_CODESIGN_MODE="${mode}" \
    FAKE_CODESIGN_VALID="${FIXTURES}/valid.xml" \
    FAKE_CODESIGN_EMPTY="${FIXTURES}/empty.xml" \
    "$@"
}

assert_success fake-valid run_fake valid bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure fake-invalid-signature 'Signed app failed strict codesign verification' run_fake invalid-signature bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure fake-empty-dictionary 'Entitlement contract mismatch: {}' run_fake empty-dictionary bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure fake-empty-output 'codesign returned no signed entitlements' run_fake empty-output bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure fake-stderr-only 'codesign returned no signed entitlements' run_fake stderr-only bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure fake-argument-error 'Failed to extract signed entitlements' run_fake argument-error bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure fake-partial-error 'Failed to extract signed entitlements' run_fake partial-error bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${APP_PATH}"
assert_failure verify-signed-arity 'Usage:' bash "${BUILD_SCRIPT}" --verify-signed-entitlements

readonly EXECUTABLE_PATH="${TEMP_ROOT}/Executable With Spaces.exe"
printf 'fixture' >"${EXECUTABLE_PATH}"
chmod +x "${EXECUTABLE_PATH}"

readonly APP_FIXTURE="${TEMP_ROOT}/Fixture With Resources.app"
readonly APP_EXECUTABLE="${APP_FIXTURE}/Fixture With Resources"
mkdir -p "${APP_FIXTURE}"
printf 'fixture executable' >"${APP_EXECUTABLE}"
chmod +x "${APP_EXECUTABLE}"
python3 - "${APP_FIXTURE}/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "wb") as destination:
    plistlib.dump(
        {
            "CFBundleExecutable": "Fixture With Resources",
            "CFBundleIdentifier": "com.juyang.CangJie",
            "CFBundlePackageType": "APPL",
        },
        destination,
    )
PY

cat >"${BIN_DIR}/csreq" <<'SH'
#!/bin/bash
set -euo pipefail
[[ "$#" == "4" ]] || { echo 'unexpected csreq argument count' >&2; exit 64; }
[[ "$1" == "-r" ]] || { echo "unexpected csreq operation: $1" >&2; exit 64; }
[[ "$2" == '=designated => identifier "com.juyang.CangJie"' ]] || { echo "unexpected designated requirement: $2" >&2; exit 64; }
[[ "$3" == "-b" ]] || { echo "unexpected csreq output option: $3" >&2; exit 64; }
[[ "$(basename "$4")" == "designated-requirement.bin" ]] || { echo "unexpected csreq output path: $4" >&2; exit 64; }
printf 'compiled designated requirement' >"$4"
SH
chmod +x "${BIN_DIR}/csreq"

cat >"${BIN_DIR}/ldid" <<'SH'
#!/bin/bash
set -euo pipefail
operation="${1:-}"
case "${operation}" in
  -Cadhoc)
    if [[ "$#" == "5" ]]; then
      [[ "$2" == "-Icom.juyang.CangJie" ]] || { echo "unexpected ldid identifier argument: $2" >&2; exit 64; }
      [[ "$3" == -Q* && -s "${3#-Q}" ]] || { echo "unexpected ldid requirement argument: $3" >&2; exit 64; }
      [[ "$4" == "-S${FAKE_LDID_CONTRACT:?}" ]] || { echo "unexpected ldid entitlement argument: $4" >&2; exit 64; }
      [[ "$5" == "${FAKE_LDID_EXECUTABLE:?}" ]] || { echo "unexpected ldid executable: $5" >&2; exit 64; }
      if [[ "${FAKE_LDID_MODE:?}" == "sign-error" ]]; then
        echo 'ldid: simulated signing failure' >&2
        exit 2
      fi
    elif [[ "$#" == "7" ]]; then
      [[ "$2" == "-Icom.juyang.CangJie" ]] || { echo "unexpected ldid identifier argument: $2" >&2; exit 64; }
      [[ "$3" == -Q* && -s "${3#-Q}" ]] || { echo "unexpected ldid requirement argument: $3" >&2; exit 64; }
      [[ "$4" == "-E1:${FAKE_LDID_APP:?}/Info.plist" ]] || { echo "unexpected ldid Info.plist slot: $4" >&2; exit 64; }
      [[ "$5" == "-E3:${FAKE_LDID_APP:?}/_CodeSignature/CodeResources" ]] || { echo "unexpected ldid CodeResources slot: $5" >&2; exit 64; }
      [[ "$6" == "-S${FAKE_LDID_CONTRACT:?}" ]] || { echo "unexpected ldid entitlement argument: $6" >&2; exit 64; }
      [[ "$7" == "${FAKE_LDID_EXECUTABLE:?}" ]] || { echo "unexpected ldid executable: $7" >&2; exit 64; }
      if [[ "${FAKE_LDID_MODE:?}" == "app-executable-sign-error" ]]; then
        echo 'ldid: simulated app executable signing failure' >&2
        exit 2
      fi
    else
      echo 'unexpected ldid sign argument count' >&2
      exit 64
    fi
    ;;
  -w)
    [[ "$#" == "5" ]] || { echo 'unexpected ldid shallow sign argument count' >&2; exit 64; }
    [[ "$2" == "-Icom.juyang.CangJie" ]] || { echo "unexpected ldid identifier argument: $2" >&2; exit 64; }
    [[ "$3" == -Q* && -s "${3#-Q}" ]] || { echo "unexpected ldid requirement argument: $3" >&2; exit 64; }
    [[ "$4" == "-S${FAKE_LDID_CONTRACT:?}" ]] || { echo "unexpected ldid entitlement argument: $4" >&2; exit 64; }
    [[ "$5" == "${FAKE_LDID_APP:?}" ]] || { echo "unexpected ldid app path: $5" >&2; exit 64; }
    mkdir -p "${FAKE_LDID_APP}/_CodeSignature"
    printf 'fake CodeResources' >"${FAKE_LDID_APP}/_CodeSignature/CodeResources"
    if [[ "${FAKE_LDID_MODE:?}" == "app-sign-error" ]]; then
      echo 'ldid: simulated app signing failure' >&2
      exit 2
    fi
    ;;
  -e)
    [[ "$#" == "2" ]] || { echo 'unexpected ldid extract argument count' >&2; exit 64; }
    [[ "$2" == "${FAKE_LDID_EXECUTABLE:?}" ]] || { echo "unexpected ldid executable: $2" >&2; exit 64; }
    case "${FAKE_LDID_MODE:?}" in
      valid)
        cat "${FAKE_LDID_VALID:?}"
        ;;
      empty-dictionary)
        cat "${FAKE_LDID_EMPTY:?}"
        ;;
      empty-output)
        ;;
      extract-error)
        echo 'ldid: simulated extraction failure' >&2
        exit 3
        ;;
      sign-error)
        echo 'ldid extraction must not run after signing failure' >&2
        exit 65
        ;;
      *)
        echo "unknown fake ldid mode" >&2
        exit 65
        ;;
    esac
    ;;
  *)
    echo "unexpected ldid operation: ${operation}" >&2
    exit 64
    ;;
esac
SH
chmod +x "${BIN_DIR}/ldid"

run_fake_ldid() {
  local ldid_mode="$1"
  local codesign_mode="$2"
  shift 2
  PATH="${BIN_DIR}:${PATH}" \
    FAKE_CODESIGN_APP="${EXECUTABLE_PATH}" \
    FAKE_CODESIGN_ALLOWED_TARGETS="${EXECUTABLE_PATH}" \
    FAKE_CODESIGN_MODE="${codesign_mode}" \
    FAKE_CODESIGN_VALID="${FIXTURES}/valid.xml" \
    FAKE_CODESIGN_EMPTY="${FIXTURES}/empty.xml" \
    FAKE_LDID_CONTRACT="${CONTRACT}" \
    FAKE_LDID_EXECUTABLE="${EXECUTABLE_PATH}" \
    FAKE_LDID_APP="${APP_FIXTURE}" \
    FAKE_LDID_MODE="${ldid_mode}" \
    FAKE_LDID_VALID="${FIXTURES}/valid.xml" \
    FAKE_LDID_EMPTY="${FIXTURES}/empty.xml" \
    "$@"
}

assert_success fake-ldid-valid run_fake_ldid valid valid bash "${BUILD_SCRIPT}" --sign-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${EXECUTABLE_PATH}"
assert_failure fake-ldid-sign-error 'ldid failed to sign the main executable' run_fake_ldid sign-error valid bash "${BUILD_SCRIPT}" --sign-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${EXECUTABLE_PATH}"
assert_failure fake-ldid-invalid-signature 'Signed executable failed strict codesign verification' run_fake_ldid valid invalid-signature bash "${BUILD_SCRIPT}" --sign-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${EXECUTABLE_PATH}"
assert_failure fake-ldid-empty-dictionary 'Entitlement contract mismatch: {}' run_fake_ldid empty-dictionary valid bash "${BUILD_SCRIPT}" --sign-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${EXECUTABLE_PATH}"
assert_failure fake-ldid-empty-output 'ldid returned no signed entitlements' run_fake_ldid empty-output valid bash "${BUILD_SCRIPT}" --sign-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${EXECUTABLE_PATH}"
assert_failure fake-ldid-extract-error 'Failed to extract ldid-signed entitlements' run_fake_ldid extract-error valid bash "${BUILD_SCRIPT}" --sign-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${EXECUTABLE_PATH}"
assert_failure sign-with-ldid-arity 'Usage:' bash "${BUILD_SCRIPT}" --sign-with-ldid

run_fake_ldid_app() {
  local ldid_mode="$1"
  local codesign_mode="$2"
  shift 2
  PATH="${BIN_DIR}:${PATH}" \
    FAKE_CODESIGN_APP="${APP_FIXTURE}" \
    FAKE_CODESIGN_ALLOWED_TARGETS="${APP_FIXTURE}:${APP_EXECUTABLE}" \
    FAKE_CODESIGN_MODE="${codesign_mode}" \
    FAKE_CODESIGN_VALID="${FIXTURES}/valid.xml" \
    FAKE_CODESIGN_EMPTY="${FIXTURES}/empty.xml" \
    FAKE_LDID_CONTRACT="${CONTRACT}" \
    FAKE_LDID_EXECUTABLE="${APP_EXECUTABLE}" \
    FAKE_LDID_APP="${APP_FIXTURE}" \
    FAKE_LDID_MODE="${ldid_mode}" \
    FAKE_LDID_VALID="${FIXTURES}/valid.xml" \
    FAKE_LDID_EMPTY="${FIXTURES}/empty.xml" \
    "$@"
}

assert_success fake-ldid-app-valid run_fake_ldid_app valid valid bash "${BUILD_SCRIPT}" --sign-app-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${APP_FIXTURE}" "${APP_EXECUTABLE}"
assert_failure fake-ldid-app-sign-error 'ldid failed to shallow-sign the app bundle' run_fake_ldid_app app-sign-error valid bash "${BUILD_SCRIPT}" --sign-app-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${APP_FIXTURE}" "${APP_EXECUTABLE}"
assert_failure fake-ldid-app-executable-sign-error 'ldid failed to ad-hoc sign the app executable' run_fake_ldid_app app-executable-sign-error valid bash "${BUILD_SCRIPT}" --sign-app-with-ldid "${BIN_DIR}/ldid" "${CONTRACT}" "${APP_FIXTURE}" "${APP_EXECUTABLE}"
assert_failure sign-app-with-ldid-arity 'Usage:' bash "${BUILD_SCRIPT}" --sign-app-with-ldid

readonly EXECUTABLE_SHA256="$(python3 - "${EXECUTABLE_PATH}" <<'PY'
import hashlib
import sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)"
assert_success final-executable-valid run_fake_ldid valid valid bash "${BUILD_SCRIPT}" --verify-final-executable "${BIN_DIR}/ldid" "${EXECUTABLE_PATH}" "${EXECUTABLE_SHA256}"
assert_failure final-executable-hash-mismatch 'Final executable SHA-256 mismatch' run_fake_ldid valid valid bash "${BUILD_SCRIPT}" --verify-final-executable "${BIN_DIR}/ldid" "${EXECUTABLE_PATH}" "0000000000000000000000000000000000000000000000000000000000000000"
assert_failure final-executable-codesign-entitlements 'Entitlement contract mismatch: {}' run_fake_ldid valid empty-dictionary bash "${BUILD_SCRIPT}" --verify-final-executable "${BIN_DIR}/ldid" "${EXECUTABLE_PATH}" "${EXECUTABLE_SHA256}"
assert_failure verify-final-executable-arity 'Usage:' bash "${BUILD_SCRIPT}" --verify-final-executable

if [[ "$(uname -s)" == "Darwin" ]]; then
  readonly REAL_APP="${TEMP_ROOT}/RealFixture.app"
  mkdir -p "${REAL_APP}"
  cat >"${TEMP_ROOT}/main.c" <<'C'
int main(void) { return 0; }
C
  xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=16.6 "${TEMP_ROOT}/main.c" -o "${REAL_APP}/RealFixture"
  python3 - "${REAL_APP}/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "wb") as destination:
    plistlib.dump(
        {
            "CFBundleExecutable": "RealFixture",
            "CFBundleIdentifier": "com.juyang.CangJie",
            "CFBundleName": "RealFixture",
            "CFBundlePackageType": "APPL",
            "MinimumOSVersion": "16.6",
            "UIDeviceFamily": [2],
        },
        destination,
    )
PY
  /usr/bin/codesign --force --sign - --timestamp=none --entitlements "${CONTRACT}" --generate-entitlement-der "${REAL_APP}"
  assert_success real-codesign bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${REAL_APP}"
  readonly REAL_EMPTY_APP="${TEMP_ROOT}/RealFixtureWithoutEntitlements.app"
  cp -R "${REAL_APP}" "${REAL_EMPTY_APP}"
  printf '\0' >>"${REAL_APP}/RealFixture"
  assert_failure real-codesign-tampered 'Signed app failed strict codesign verification' bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${REAL_APP}"
  /usr/bin/codesign --force --sign - --timestamp=none "${REAL_EMPTY_APP}"
  assert_failure real-codesign-empty 'codesign returned no signed entitlements' bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${REAL_EMPTY_APP}"

  if [[ -n "${LDID_PATH:-}" ]]; then
    readonly REAL_LDID_EXECUTABLE="${TEMP_ROOT}/RealLdidFixture"
    xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=16.6 "${TEMP_ROOT}/main.c" -o "${REAL_LDID_EXECUTABLE}"
    readonly REAL_LDID_BEFORE_SHA256="$(shasum -a 256 "${REAL_LDID_EXECUTABLE}" | awk '{print $1}')"
    if ! bash "${BUILD_SCRIPT}" --sign-with-ldid "${LDID_PATH}" "${CONTRACT}" "${REAL_LDID_EXECUTABLE}"; then
      readonly REAL_LDID_AFTER_SHA256="$(shasum -a 256 "${REAL_LDID_EXECUTABLE}" | awk '{print $1}')"
      printf 'real ldid diagnostic: sha256 before=%s after=%s\n' "${REAL_LDID_BEFORE_SHA256}" "${REAL_LDID_AFTER_SHA256}" >&2
      printf '%s\n' 'real ldid diagnostic: LC_CODE_SIGNATURE load command' >&2
      otool -l "${REAL_LDID_EXECUTABLE}" | awk '/cmd LC_CODE_SIGNATURE/{show=1; count=0} show{print; count++} count==5{show=0}' >&2 || true
      printf '%s\n' 'real ldid diagnostic: codesign details' >&2
      /usr/bin/codesign -dvv "${REAL_LDID_EXECUTABLE}" >&2 || true
      printf '%s\n' 'real ldid diagnostic: codesign entitlements' >&2
      /usr/bin/codesign --display --entitlements - --xml "${REAL_LDID_EXECUTABLE}" >&2 || true
      printf '%s\n' 'real ldid diagnostic: ldid entitlements' >&2
      "${LDID_PATH}" -e "${REAL_LDID_EXECUTABLE}" >&2 || true
      exit 1
    fi

    readonly REAL_LDID_APP="${TEMP_ROOT}/RealLdidFixture.app"
    readonly REAL_LDID_APP_EXECUTABLE="${REAL_LDID_APP}/RealLdidFixture"
    mkdir -p "${REAL_LDID_APP}"
    cp "${REAL_LDID_EXECUTABLE}" "${REAL_LDID_APP_EXECUTABLE}"
    printf 'resource fixture' >"${REAL_LDID_APP}/Resource.txt"
    python3 - "${REAL_LDID_APP}/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "wb") as destination:
    plistlib.dump(
        {
            "CFBundleExecutable": "RealLdidFixture",
            "CFBundleIdentifier": "com.juyang.CangJie",
            "CFBundleName": "RealLdidFixture",
            "CFBundlePackageType": "APPL",
            "MinimumOSVersion": "16.6",
            "UIDeviceFamily": [2],
        },
        destination,
    )
PY
    if ! bash "${BUILD_SCRIPT}" --sign-app-with-ldid "${LDID_PATH}" "${CONTRACT}" "${REAL_LDID_APP}" "${REAL_LDID_APP_EXECUTABLE}" >"${TEMP_ROOT}/real-ldid-app.stdout" 2>"${TEMP_ROOT}/real-ldid-app.stderr"; then
      cat "${TEMP_ROOT}/real-ldid-app.stdout" >&2 || true
      cat "${TEMP_ROOT}/real-ldid-app.stderr" >&2 || true
      printf '%s\n' 'real ldid app diagnostic: bundle files' >&2
      find "${REAL_LDID_APP}" -maxdepth 3 -print >&2 || true
      printf '%s\n' 'real ldid app diagnostic: executable codesign details' >&2
      /usr/bin/codesign -dvv "${REAL_LDID_APP_EXECUTABLE}" >&2 || true
      printf '%s\n' 'real ldid app diagnostic: executable requirement' >&2
      /usr/bin/codesign -d -r- "${REAL_LDID_APP_EXECUTABLE}" >&2 || true
      printf '%s\n' 'real ldid app diagnostic: executable entitlements' >&2
      /usr/bin/codesign --display --entitlements - --xml "${REAL_LDID_APP_EXECUTABLE}" >&2 || true
      printf '%s\n' 'real ldid app diagnostic: ldid entitlements' >&2
      "${LDID_PATH}" -e "${REAL_LDID_APP_EXECUTABLE}" >&2 || true
      printf '%s\n' 'real ldid app diagnostic: code signature load command' >&2
      otool -l "${REAL_LDID_APP_EXECUTABLE}" | awk '/cmd LC_CODE_SIGNATURE/{show=1; count=0} show{print; count++} count==5{show=0}' >&2 || true
      exit 1
    fi
    [[ -f "${REAL_LDID_APP}/_CodeSignature/CodeResources" && ! -L "${REAL_LDID_APP}/_CodeSignature/CodeResources" ]] || {
      echo 'real ldid app did not produce a regular CodeResources file' >&2
      exit 1
    }
    assert_success real-ldid-app-verify bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${REAL_LDID_APP}"
  fi
fi

printf 'build-ipa entitlement contract tests passed\n'