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
    expected=(--verify --strict --verbose=2 "${FAKE_CODESIGN_APP:?}")
    ;;
  --display)
    expected=(--display --entitlements - --xml "${FAKE_CODESIGN_APP:?}")
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
if [[ "${actual[0]}" == "--verify" ]]; then
  if [[ "${FAKE_CODESIGN_MODE:?}" == "invalid-signature" ]]; then
    echo 'codesign: simulated invalid signature' >&2
    exit 1
  fi
  echo 'fake app: valid on disk' >&2
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
  printf '\0' >>"${REAL_APP}/RealFixture"
  assert_failure real-codesign-tampered 'Signed app failed strict codesign verification' bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${REAL_APP}"
  /usr/bin/codesign --force --sign - --timestamp=none "${REAL_APP}"
  assert_failure real-codesign-empty 'codesign returned no signed entitlements' bash "${BUILD_SCRIPT}" --verify-signed-entitlements "${REAL_APP}"
fi

printf 'build-ipa entitlement contract tests passed\n'