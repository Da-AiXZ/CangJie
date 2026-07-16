#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly PROJECT="${XCODE_PROJECT:-${ROOT}/CangJie.xcodeproj}"
readonly SCHEME="${XCODE_SCHEME:-CangJie}"

for tool in xcodebuild xcrun python3 mktemp; do
  command -v "${tool}" >/dev/null || { echo "Required tool is missing: ${tool}" >&2; exit 1; }
done
[[ -d "${PROJECT}" && ! -L "${PROJECT}" ]] || { echo "Generated Xcode project is missing or unsafe: ${PROJECT}" >&2; exit 1; }

readonly TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cangjie-simulator.XXXXXX")"
[[ -d "${TEMP_ROOT}" && ! -L "${TEMP_ROOT}" ]] || { echo "Unable to create a safe temporary directory" >&2; exit 1; }
cleanup() {
  rm -rf -- "${TEMP_ROOT}"
}
trap cleanup EXIT

readonly DESTINATIONS_FILE="${TEMP_ROOT}/destinations.txt"
readonly DEVICES_FILE="${TEMP_ROOT}/devices.json"

show_destination_args=(
  -project "${PROJECT}"
  -scheme "${SCHEME}"
  -showdestinations
  -disableAutomaticPackageResolution
)
if [[ -n "${SWIFTPM_CLONED_SOURCE_PACKAGES_DIR:-}" ]]; then
  show_destination_args+=( -clonedSourcePackagesDirPath "${SWIFTPM_CLONED_SOURCE_PACKAGES_DIR}" )
fi

xcodebuild "${show_destination_args[@]}" > "${DESTINATIONS_FILE}"
xcrun simctl list devices available -j > "${DEVICES_FILE}"

readonly SELECTION="$(python3 - "${DESTINATIONS_FILE}" "${DEVICES_FILE}" <<'PY'
import json
import re
import sys

showdestinations_path, devices_path = sys.argv[1:]
udid_pattern = re.compile(r"^[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$")

eligible_udids = set()
in_available_section = False
with open(showdestinations_path, encoding="utf-8", errors="replace") as source:
    for raw_line in source:
        line = raw_line.strip()
        if line.startswith("Available destinations for the"):
            in_available_section = True
            continue
        if line.startswith("Ineligible destinations for the"):
            in_available_section = False
            continue
        if not in_available_section or "platform:iOS Simulator" not in line:
            continue
        match = re.search(r"(?:^|,\s*)id:([^,}]+)", line.strip("{} \t"))
        if not match:
            continue
        udid = match.group(1).strip()
        if udid_pattern.fullmatch(udid) and re.search(r"(?:^|,\s*)name:iPad", line):
            eligible_udids.add(udid.lower())

if not eligible_udids:
    raise SystemExit("xcodebuild reported no eligible iPad Simulator destinations")

with open(devices_path, "rb") as source:
    data = json.load(source)

candidates = []
for runtime, devices in data.get("devices", {}).items():
    marker = ".SimRuntime.iOS-"
    if marker not in runtime:
        continue
    version_text = runtime.rsplit(marker, 1)[-1]
    version = tuple(int(part) for part in version_text.split("-") if part.isdigit())
    for device in devices:
        name = device.get("name", "")
        udid = device.get("udid", "")
        state = device.get("state", "")
        if (
            device.get("isAvailable")
            and isinstance(name, str)
            and name.startswith("iPad")
            and isinstance(udid, str)
            and udid_pattern.fullmatch(udid)
            and udid.lower() in eligible_udids
        ):
            preferred = 1 if "iPad Pro (11-inch)" in name else 0
            candidates.append((version, preferred, name, udid, state))

if not candidates:
    raise SystemExit("No iPad Simulator is both available in simctl and eligible in xcodebuild -showdestinations")

candidates.sort(reverse=True)
_, _, _, udid, state = candidates[0]
print(f"{udid}\t{state}")
PY
)"

readonly UDID="${SELECTION%%$'\t'*}"
readonly STATE="${SELECTION#*$'\t'}"
[[ "${SELECTION}" == *$'\t'* ]] || { echo "Simulator selection did not include a state" >&2; exit 1; }
[[ "${UDID}" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || {
  echo "Simulator selection returned an invalid iPad Simulator UDID" >&2
  exit 1
}

if [[ "${STATE}" != "Booted" ]]; then
  if ! xcrun simctl boot "${UDID}" >&2; then
    echo "Failed to boot selected iPad Simulator: ${UDID}" >&2
    exit 1
  fi
fi
xcrun simctl bootstatus "${UDID}" -b >&2
printf '%s\n' "${UDID}"