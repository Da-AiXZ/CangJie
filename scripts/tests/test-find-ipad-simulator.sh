#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
readonly SELECTOR="${ROOT}/scripts/find-ipad-simulator.sh"
readonly TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cangjie-selector-tests.XXXXXX")"

cleanup() {
  rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

readonly MOCK_BIN="${TEST_ROOT}/bin"
readonly MOCK_PROJECT="${TEST_ROOT}/CangJie.xcodeproj"
mkdir -p "${MOCK_BIN}" "${MOCK_PROJECT}"

cat > "${MOCK_BIN}/xcodebuild" <<'MOCK'
#!/bin/bash
set -euo pipefail
printf '%s\n' "${MOCK_DESTINATIONS:?MOCK_DESTINATIONS is required}"
MOCK

cat > "${MOCK_BIN}/xcrun" <<'MOCK'
#!/bin/bash
set -euo pipefail
[[ "${1:-}" == "simctl" ]] || { echo "Unexpected xcrun command: $*" >&2; exit 2; }
case "${2:-}" in
  list)
    [[ "${3:-}" == "devices" && "${4:-}" == "available" ]] || { echo "Unexpected simctl list command: $*" >&2; exit 2; }
    if [[ "${MOCK_SIMCTL_LIST_EXIT:-0}" != "0" ]]; then
      echo "simctl list failed" >&2
      exit "${MOCK_SIMCTL_LIST_EXIT}"
    fi
    printf '%s\n' "${MOCK_DEVICES:?MOCK_DEVICES is required}"
    ;;
  boot)
    printf '%s\n' "${3:-missing}" >> "${MOCK_BOOT_LOG:?MOCK_BOOT_LOG is required}"
    exit "${MOCK_BOOT_EXIT:-0}"
    ;;
  bootstatus)
    printf 'bootstatus:%s\n' "${3:-missing}" >&2
    ;;
  *)
    echo "Unexpected simctl command: $*" >&2
    exit 2
    ;;
esac
MOCK
chmod +x "${MOCK_BIN}/xcodebuild" "${MOCK_BIN}/xcrun"

run_selector() {
  local case_name="$1"
  local destinations="$2"
  local devices="$3"
  local boot_exit="${4:-0}"
  local list_exit="${5:-0}"
  CASE_OUTPUT_FILE="${TEST_ROOT}/${case_name}.stdout"
  CASE_ERROR_FILE="${TEST_ROOT}/${case_name}.stderr"
  CASE_BOOT_LOG="${TEST_ROOT}/${case_name}.boot.log"
  : > "${CASE_BOOT_LOG}"

  set +e
  PATH="${MOCK_BIN}:${PATH}" \
    XCODE_PROJECT="${MOCK_PROJECT}" \
    MOCK_DESTINATIONS="${destinations}" \
    MOCK_DEVICES="${devices}" \
    MOCK_BOOT_LOG="${CASE_BOOT_LOG}" \
    MOCK_BOOT_EXIT="${boot_exit}" \
    MOCK_SIMCTL_LIST_EXIT="${list_exit}" \
    bash "${SELECTOR}" > "${CASE_OUTPUT_FILE}" 2> "${CASE_ERROR_FILE}"
  CASE_STATUS=$?
  set -e
}

assert_success_with_udid() {
  local expected="$1"
  [[ "${CASE_STATUS}" -eq 0 ]] || {
    echo "Expected success, got ${CASE_STATUS}: $(cat "${CASE_ERROR_FILE}")" >&2
    exit 1
  }
  local actual
  actual="$(cat "${CASE_OUTPUT_FILE}")"
  [[ "${actual}" == "${expected}" ]] || {
    echo "Expected UDID ${expected}, got ${actual}" >&2
    exit 1
  }
}

readonly IPAD_A='AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
readonly IPAD_B='BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB'
readonly IPAD_C='CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC'

# Only the Available section is eligible; an 11-inch device in Ineligible must never win.
run_selector \
  'available-section' \
  "Available destinations for the \"CangJie\" scheme:
    { platform:iOS Simulator, arch:arm64, id:${IPAD_A}, OS:18.5, name:iPad mini (A17 Pro) }
Ineligible destinations for the \"CangJie\" scheme:
    { platform:iOS Simulator, arch:arm64, id:${IPAD_B}, OS:18.5, name:iPad Pro (11-inch) (M4) }" \
  "== Devices ==
    iPad mini (A17 Pro) (${IPAD_A}) (Shutdown)
    iPad Pro (11-inch) (M4) (${IPAD_B}) (Shutdown)"
assert_success_with_udid "${IPAD_A}"

# Select the first device in the intersection, not merely the first xcodebuild candidate.
run_selector \
  'available-intersection' \
  "Available destinations for the \"CangJie\" scheme:
    { platform:iOS Simulator, arch:arm64, id:${IPAD_A}, OS:18.5, name:iPad Pro (11-inch) (M4) }
    { platform:iOS Simulator, arch:arm64, id:${IPAD_C}, OS:18.5, name:iPad Air (11-inch) (M3) }" \
  "== Devices ==
    iPad Air (11-inch) (M3) (${IPAD_C}) (Shutdown)"
assert_success_with_udid "${IPAD_C}"

# A device already Booting must proceed to bootstatus without another boot call.
run_selector \
  'booting-state' \
  "Available destinations for the \"CangJie\" scheme:
    { platform:iOS Simulator, arch:arm64, id:${IPAD_A}, OS:18.5, name:iPad Air (11-inch) (M3) }" \
  "== Devices ==
    iPad Air (11-inch) (M3) (${IPAD_A}) (Booting)" \
  9
assert_success_with_udid "${IPAD_A}"
[[ ! -s "${CASE_BOOT_LOG}" ]] || { echo "Booting device was booted again" >&2; exit 1; }

# A real simctl failure must remain a command failure.
run_selector \
  'simctl-failure' \
  "Available destinations for the \"CangJie\" scheme:
    { platform:iOS Simulator, arch:arm64, id:${IPAD_A}, OS:18.5, name:iPad Air (11-inch) (M3) }" \
  'unused' \
  0 \
  7
[[ "${CASE_STATUS}" -ne 0 ]] || { echo "Expected simctl failure to fail the selector" >&2; exit 1; }
grep -q 'simctl list failed' "${CASE_ERROR_FILE}" || { echo "Original simctl failure was not preserved" >&2; exit 1; }

printf 'find-ipad-simulator tests passed\n'
