#!/bin/bash
set -euo pipefail

readonly VERSION="v2.1.5-procursus7"
readonly RELEASE_BASE_URL="https://github.com/ProcursusTeam/ldid/releases/download/${VERSION}"
readonly ARM64_SHA256="5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50"
readonly X86_64_SHA256="9d46e0feedf96e399edfca09872802ba21e729f79c01927ad25ea2b0a35bca23"
readonly ARM64_SIZE="2572056"
readonly X86_64_SIZE="2824936"

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "ldid installer only supports macOS" >&2
  exit 1
}

MACHINE_ARCH="$(uname -m)"
readonly MACHINE_ARCH
case "${MACHINE_ARCH}" in
  arm64)
    readonly ASSET_NAME="ldid_macosx_arm64"
    readonly EXPECTED_SHA256="${ARM64_SHA256}"
    readonly EXPECTED_SIZE="${ARM64_SIZE}"
    ;;
  x86_64)
    readonly ASSET_NAME="ldid_macosx_x86_64"
    readonly EXPECTED_SHA256="${X86_64_SHA256}"
    readonly EXPECTED_SIZE="${X86_64_SIZE}"
    ;;
  *)
    echo "Unsupported macOS architecture: ${MACHINE_ARCH}" >&2
    exit 1
    ;;
esac
readonly DOWNLOAD_URL="${RELEASE_BASE_URL}/${ASSET_NAME}"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v shasum >/dev/null || { echo "shasum is required" >&2; exit 1; }
command -v lipo >/dev/null || { echo "lipo is required" >&2; exit 1; }

readonly TEMP_BASE_INPUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
[[ -d "${TEMP_BASE_INPUT}" && ! -L "${TEMP_BASE_INPUT}" ]] || {
  echo "RUNNER_TEMP is missing or unsafe: ${TEMP_BASE_INPUT}" >&2
  exit 1
}
TEMP_BASE="$(cd "${TEMP_BASE_INPUT}" && pwd -P)"
readonly TEMP_BASE
[[ "${TEMP_BASE}" == /* && "${TEMP_BASE}" != "/" ]] || {
  echo "RUNNER_TEMP did not resolve to a safe absolute directory: ${TEMP_BASE}" >&2
  exit 1
}

umask 077
INSTALL_ROOT="$(mktemp -d "${TEMP_BASE}/ldid-${VERSION}.XXXXXX")"
readonly INSTALL_ROOT
[[ "${INSTALL_ROOT}" == /* && -d "${INSTALL_ROOT}" && ! -L "${INSTALL_ROOT}" ]] || {
  echo "Unsafe ldid install directory: ${INSTALL_ROOT}" >&2
  exit 1
}
INSTALL_ROOT_RESOLVED="$(cd "${INSTALL_ROOT}" && pwd -P)"
readonly INSTALL_ROOT_RESOLVED
[[ "${INSTALL_ROOT_RESOLVED%/*}" == "${TEMP_BASE}" && "${INSTALL_ROOT_RESOLVED##*/}" == ldid-${VERSION}.* ]] || {
  echo "Unsafe ldid install directory: ${INSTALL_ROOT_RESOLVED}" >&2
  exit 1
}

cleanup() {
  local status=$?
  if [[ -n "${INSTALL_ROOT_RESOLVED}" && "${INSTALL_ROOT_RESOLVED%/*}" == "${TEMP_BASE}" ]]; then
    rm -rf "${INSTALL_ROOT_RESOLVED}"
  fi
  return "${status}"
}
trap cleanup EXIT

readonly DOWNLOAD_PATH="${INSTALL_ROOT_RESOLVED}/ldid.download"
readonly OUTPUT_PATH="${INSTALL_ROOT_RESOLVED}/ldid"
[[ ! -e "${DOWNLOAD_PATH}" && ! -L "${DOWNLOAD_PATH}" && ! -e "${OUTPUT_PATH}" && ! -L "${OUTPUT_PATH}" ]] || {
  echo "Unsafe pre-existing ldid output" >&2
  exit 1
}

if ! curl \
  --fail \
  --location \
  --proto '=https' \
  --proto-redir '=https' \
  --tlsv1.2 \
  --connect-timeout 20 \
  --max-time 120 \
  --max-filesize "${EXPECTED_SIZE}" \
  --retry 3 \
  --retry-all-errors \
  --silent \
  --show-error \
  "${DOWNLOAD_URL}" \
  --output "${DOWNLOAD_PATH}"; then
  echo "Failed to download ldid ${VERSION} for ${MACHINE_ARCH}" >&2
  exit 1
fi

[[ -f "${DOWNLOAD_PATH}" && ! -L "${DOWNLOAD_PATH}" ]] || {
  echo "Downloaded ldid is missing or unsafe" >&2
  exit 1
}
readonly ACTUAL_SIZE="$(wc -c <"${DOWNLOAD_PATH}" | tr -d '[:space:]')"
[[ "${ACTUAL_SIZE}" == "${EXPECTED_SIZE}" ]] || {
  echo "ldid size mismatch for ${ASSET_NAME}: ${ACTUAL_SIZE} (expected ${EXPECTED_SIZE})" >&2
  exit 1
}

if ! printf '%s  %s\n' "${EXPECTED_SHA256}" "${DOWNLOAD_PATH}" \
  | shasum -a 256 --check --strict >/dev/null; then
  echo "ldid SHA-256 mismatch for ${ASSET_NAME}" >&2
  exit 1
fi

if ! ACTUAL_ARCHS="$(lipo -archs "${DOWNLOAD_PATH}")"; then
  echo "Failed to inspect ldid architecture" >&2
  exit 1
fi
ACTUAL_ARCHS="${ACTUAL_ARCHS//$'\r'/}"
readonly ACTUAL_ARCHS
[[ "${ACTUAL_ARCHS}" == "${MACHINE_ARCH}" ]] || {
  echo "Unexpected ldid architecture: ${ACTUAL_ARCHS} (expected ${MACHINE_ARCH})" >&2
  exit 1
}

chmod 0755 "${DOWNLOAD_PATH}"
mv "${DOWNLOAD_PATH}" "${OUTPUT_PATH}"
[[ -f "${OUTPUT_PATH}" && ! -L "${OUTPUT_PATH}" ]] || {
  echo "Installed ldid output is missing or unsafe" >&2
  exit 1
}

trap - EXIT
printf '%s\n' "${OUTPUT_PATH}"
