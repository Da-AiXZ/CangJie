#!/bin/bash
set -euo pipefail

readonly REQUESTED="${XCODE_VERSION:-16.4}"
if [[ ! "${REQUESTED}" =~ ^[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]{1,2})?$ ]]; then
  echo "Invalid XCODE_VERSION value: ${REQUESTED}" >&2
  exit 1
fi

readonly CANDIDATE="/Applications/Xcode_${REQUESTED}.app/Contents/Developer"
if [[ ! -d "${CANDIDATE}" || -L "${CANDIDATE}" ]]; then
  echo "Requested Xcode was not found as a regular installation: ${CANDIDATE}" >&2
  find /Applications -maxdepth 1 -type d -name 'Xcode*.app' -print >&2 || true
  exit 1
fi

sudo xcode-select --switch "${CANDIDATE}"
readonly SELECTED="$(xcode-select --print-path)"
[[ "${SELECTED}" == "${CANDIDATE}" ]] || {
  echo "xcode-select chose an unexpected developer directory: ${SELECTED}" >&2
  exit 1
}

readonly ACTUAL_VERSION="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
[[ "${ACTUAL_VERSION}" == "${REQUESTED}" ]] || {
  echo "Requested Xcode ${REQUESTED}, but xcodebuild reports ${ACTUAL_VERSION}" >&2
  exit 1
}

xcodebuild -version