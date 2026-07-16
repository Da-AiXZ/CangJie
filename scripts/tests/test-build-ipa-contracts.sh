#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
readonly PRIVACY_MANIFEST="${1:-}"
[[ -f "${PRIVACY_MANIFEST}" && ! -L "${PRIVACY_MANIFEST}" ]] || {
  echo "Usage: $0 <pinned GRDB PrivacyInfo.xcprivacy>" >&2
  exit 1
}

readonly TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEMP_ROOT}"' EXIT
readonly BUNDLE="${TEMP_ROOT}/GRDB_GRDB.bundle"
mkdir -p "${BUNDLE}"

write_info_plist() {
  local identifier="$1"
  python3 - "${BUNDLE}/Info.plist" "${identifier}" <<'PY'
import plistlib
import sys

path, identifier = sys.argv[1:]
with open(path, "wb") as destination:
    plistlib.dump(
        {
            "CFBundleIdentifier": identifier,
            "CFBundlePackageType": "BNDL",
        },
        destination,
        sort_keys=True,
    )
PY
}

reset_valid_bundle() {
  rm -rf "${BUNDLE}"
  mkdir -p "${BUNDLE}"
  cp "${PRIVACY_MANIFEST}" "${BUNDLE}/PrivacyInfo.xcprivacy"
  write_info_plist "grdb.swift.GRDB.resources"
}

assert_rejected() {
  local expected_message="$1"
  if output="$(bash "${ROOT}/scripts/build-ipa.sh" --verify-grdb-resource-bundle "${BUNDLE}" 2>&1)"; then
    echo "Expected resource bundle verification to fail: ${expected_message}" >&2
    exit 1
  fi
  grep -F "${expected_message}" <<<"${output}" >/dev/null || {
    echo "Verifier failed for an unexpected reason: ${output}" >&2
    exit 1
  }
}

reset_valid_bundle
bash "${ROOT}/scripts/build-ipa.sh" --verify-grdb-resource-bundle "${BUNDLE}"

for rejected_identifier in \
  "GRDB.GRDB.resources" \
  "org.swift.swiftpm.GRDB.GRDB.resources" \
  "grdb.swift.GRDB.resources.evil"; do
  write_info_plist "${rejected_identifier}"
  assert_rejected "Unexpected GRDB resource bundle identifier: '${rejected_identifier}'"
done

reset_valid_bundle
printf '\n' >>"${BUNDLE}/PrivacyInfo.xcprivacy"
assert_rejected "GRDB privacy manifest hash mismatch"

reset_valid_bundle
printf 'unexpected\n' >"${BUNDLE}/unexpected.txt"
assert_rejected "Unexpected GRDB resource bundle contents"

reset_valid_bundle
mkdir "${BUNDLE}/unexpected-directory"
assert_rejected "GRDB resource bundle contains an unexpected directory"

reset_valid_bundle
rm "${BUNDLE}/PrivacyInfo.xcprivacy"
if ln -s "${PRIVACY_MANIFEST}" "${BUNDLE}/PrivacyInfo.xcprivacy" 2>/dev/null && [[ -L "${BUNDLE}/PrivacyInfo.xcprivacy" ]]; then
  assert_rejected "GRDB privacy manifest is missing or unsafe"
else
  printf 'symlink negative test skipped: host cannot create symbolic links\n' >&2
fi

printf 'build-ipa dependency contract tests passed\n'