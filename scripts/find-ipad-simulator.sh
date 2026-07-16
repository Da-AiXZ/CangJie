#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly PROJECT="${XCODE_PROJECT:-${ROOT}/CangJie.xcodeproj}"
readonly SCHEME="${XCODE_SCHEME:-CangJie}"

for tool in xcodebuild xcrun awk grep sed sort mktemp; do
  command -v "${tool}" >/dev/null || { echo "Required tool is missing: ${tool}" >&2; exit 1; }
done
[[ -d "${PROJECT}" && ! -L "${PROJECT}" ]] || { echo "Generated Xcode project is missing or unsafe: ${PROJECT}" >&2; exit 1; }

readonly TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cangjie-simulator.XXXXXX")"
[[ -d "${TEMP_ROOT}" && ! -L "${TEMP_ROOT}" ]] || { echo "Unable to create a safe temporary directory" >&2; exit 1; }
selection_succeeded=0
created_simulator=''
cleanup() {
  if [[ "${selection_succeeded}" -ne 1 && "${created_simulator}" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    xcrun simctl delete "${created_simulator}" >&2 || true
  fi
  rm -rf -- "${TEMP_ROOT}"
}
trap cleanup EXIT

readonly DESTINATIONS_FILE="${TEMP_ROOT}/destinations.txt"
readonly AVAILABLE_IPADS_FILE="${TEMP_ROOT}/available-ipads.txt"
readonly ORDERED_IPADS_FILE="${TEMP_ROOT}/ordered-ipads.txt"
readonly DEVICES_FILE="${TEMP_ROOT}/devices.txt"
readonly RETRY_DEVICES_FILE="${TEMP_ROOT}/retry-devices.txt"
readonly RUNTIMES_FILE="${TEMP_ROOT}/runtimes.txt"
readonly ORDERED_RUNTIMES_FILE="${TEMP_ROOT}/ordered-runtimes.txt"
readonly DEVICE_TYPES_FILE="${TEMP_ROOT}/device-types.txt"
readonly ORDERED_DEVICE_TYPES_FILE="${TEMP_ROOT}/ordered-device-types.txt"
readonly CREATE_ERRORS_FILE="${TEMP_ROOT}/create-errors.txt"

show_destination_args=(
  -project "${PROJECT}"
  -scheme "${SCHEME}"
  -showdestinations
  -disableAutomaticPackageResolution
)
if [[ -n "${SWIFTPM_CLONED_SOURCE_PACKAGES_DIR:-}" ]]; then
  show_destination_args+=( -clonedSourcePackagesDirPath "${SWIFTPM_CLONED_SOURCE_PACKAGES_DIR}" )
fi

capture_available_ipads() {
  xcodebuild "${show_destination_args[@]}" > "${DESTINATIONS_FILE}"
  awk '
    /^[[:space:]]*Available destinations for the / { available = 1; next }
    /^[[:space:]]*Ineligible destinations for the / { available = 0; next }
    available && /platform:[[:space:]]*iOS Simulator/ && /name:[[:space:]]*iPad/ { print }
  ' "${DESTINATIONS_FILE}" > "${AVAILABLE_IPADS_FILE}"
}

create_missing_ipad() {
  xcrun simctl list runtimes available > "${RUNTIMES_FILE}"
  awk '
    /^[[:space:]]*iOS[[:space:]]+[0-9]+\.[0-9]+/ && /com\.apple\.CoreSimulator\.SimRuntime\.iOS-/ {
      version = $2
      split(version, parts, ".")
      identifier = $NF
      printf "%d\t%s\n", (parts[1] * 1000) + parts[2], identifier
    }
  ' "${RUNTIMES_FILE}" | sort -rn | awk -F '\t' '{ print $2 }' > "${ORDERED_RUNTIMES_FILE}"

  xcrun simctl list devicetypes > "${DEVICE_TYPES_FILE}"
  awk '
    /^[[:space:]]*iPad/ && /com\.apple\.CoreSimulator\.SimDeviceType\./ {
      identifier = $0
      sub(/^.*\(/, "", identifier)
      sub(/\)[[:space:]]*$/, "", identifier)
      preference = ($0 ~ /11-inch/) ? 0 : 1
      printf "%d\t%s\n", preference, identifier
    }
  ' "${DEVICE_TYPES_FILE}" | sort -n -k1,1 | awk -F '\t' '{ print $2 }' > "${ORDERED_DEVICE_TYPES_FILE}"

  [[ -s "${ORDERED_RUNTIMES_FILE}" ]] || { echo "No available iOS Simulator runtime is installed" >&2; exit 1; }
  [[ -s "${ORDERED_DEVICE_TYPES_FILE}" ]] || { echo "No iPad Simulator device type is installed" >&2; exit 1; }
  : > "${CREATE_ERRORS_FILE}"

  while IFS= read -r runtime_identifier; do
    while IFS= read -r device_type_identifier; do
      set +e
      candidate="$(xcrun simctl create 'iPad CangJie CI' "${device_type_identifier}" "${runtime_identifier}" 2>> "${CREATE_ERRORS_FILE}")"
      create_status=$?
      set -e
      if [[ "${create_status}" -eq 0 && "${candidate}" =~ ^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$ ]]; then
        created_simulator="${candidate}"
        echo "Created CI iPad Simulator ${created_simulator}" >&2
        return 0
      fi
    done < "${ORDERED_DEVICE_TYPES_FILE}"
  done < "${ORDERED_RUNTIMES_FILE}"

  echo "Unable to create an iPad Simulator from the installed runtimes and device types" >&2
  cat "${CREATE_ERRORS_FILE}" >&2
  exit 1
}

capture_available_ipads
if [[ ! -s "${AVAILABLE_IPADS_FILE}" ]]; then
  echo "No pre-created eligible iPad Simulator was found; creating one" >&2
  create_missing_ipad
  capture_available_ipads
fi
[[ -s "${AVAILABLE_IPADS_FILE}" ]] || {
  echo "xcodebuild reported no eligible iPad Simulator destinations after creation" >&2
  cat "${DESTINATIONS_FILE}" >&2
  exit 1
}

# Preserve xcodebuild order while preferring an 11-inch iPad when one is eligible.
awk '/11-inch/ { print }' "${AVAILABLE_IPADS_FILE}" > "${ORDERED_IPADS_FILE}"
awk '!/11-inch/ { print }' "${AVAILABLE_IPADS_FILE}" >> "${ORDERED_IPADS_FILE}"

# Capture simctl without masking command failures, then select from the true intersection.
xcrun simctl list devices available > "${DEVICES_FILE}"
selected_udid=''
selected_device_line=''
while IFS= read -r candidate_line; do
  candidate_udid="$(printf '%s\n' "${candidate_line}" | grep -oE 'id:[[:space:]]*[0-9A-Fa-f-]{36}' | sed -E 's/^id:[[:space:]]*//')"
  [[ "${candidate_udid}" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || {
    echo "Eligible destination contained an invalid iPad Simulator UDID: ${candidate_line}" >&2
    exit 1
  }

  set +e
  device_line="$(grep -F -m 1 "${candidate_udid}" "${DEVICES_FILE}")"
  grep_status=$?
  set -e
  if [[ "${grep_status}" -eq 0 ]]; then
    selected_udid="${candidate_udid}"
    selected_device_line="${device_line}"
    break
  fi
  [[ "${grep_status}" -eq 1 ]] || { echo "Unable to inspect simctl devices" >&2; exit "${grep_status}"; }
done < "${ORDERED_IPADS_FILE}"

[[ -n "${selected_udid}" && -n "${selected_device_line}" ]] || {
  echo "No iPad Simulator is both eligible in xcodebuild and available in simctl" >&2
  echo "Eligible xcodebuild destinations:" >&2
  cat "${AVAILABLE_IPADS_FILE}" >&2
  echo "Available simctl devices:" >&2
  cat "${DEVICES_FILE}" >&2
  exit 1
}

case "${selected_device_line}" in
  *"(Booted)"*|*"(Booting)"*)
    ;;
  *"(Shutdown)"*)
    if ! xcrun simctl boot "${selected_udid}" >&2; then
      # A concurrent CoreSimulator operation may have started the device after our list call.
      xcrun simctl list devices available > "${RETRY_DEVICES_FILE}"
      set +e
      retry_line="$(grep -F -m 1 "${selected_udid}" "${RETRY_DEVICES_FILE}")"
      retry_status=$?
      set -e
      if [[ "${retry_status}" -ne 0 || ( "${retry_line}" != *"(Booted)"* && "${retry_line}" != *"(Booting)"* ) ]]; then
        echo "Unable to boot selected iPad Simulator: ${selected_udid}" >&2
        exit 1
      fi
    fi
    ;;
  *)
    echo "Selected iPad Simulator is in an unsupported state: ${selected_device_line}" >&2
    exit 1
    ;;
esac

if [[ -n "${created_simulator}" && "${created_simulator}" != "${selected_udid}" ]]; then
  xcrun simctl delete "${created_simulator}" >&2
  created_simulator=''
fi
xcrun simctl bootstatus "${selected_udid}" -b >&2
selection_succeeded=1
printf '%s\n' "${selected_udid}"
