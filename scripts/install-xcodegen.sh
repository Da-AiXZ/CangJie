#!/bin/bash
set -euo pipefail

readonly VERSION="2.45.4"
readonly EXPECTED_SHA256="090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef"
readonly DOWNLOAD_URL="https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"
readonly TEMP_BASE="${RUNNER_TEMP:-/tmp}"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
command -v shasum >/dev/null || { echo "shasum is required" >&2; exit 1; }

INSTALL_ROOT="$(mktemp -d "${TEMP_BASE%/}/xcodegen-${VERSION}.XXXXXX")"
readonly INSTALL_ROOT
readonly ARCHIVE="${INSTALL_ROOT}/xcodegen.zip"
readonly EXTRACT_ROOT="${INSTALL_ROOT}/extract"
mkdir -p "${EXTRACT_ROOT}"

curl \
  --fail \
  --location \
  --proto '=https' \
  --tlsv1.2 \
  --retry 3 \
  --retry-all-errors \
  --silent \
  --show-error \
  "${DOWNLOAD_URL}" \
  --output "${ARCHIVE}"

printf '%s  %s\n' "${EXPECTED_SHA256}" "${ARCHIVE}" | shasum -a 256 --check --strict

python3 - "${ARCHIVE}" "${EXTRACT_ROOT}" <<'PY'
import os
import shutil
import stat
import sys
import zipfile
from pathlib import PurePosixPath

archive, destination = sys.argv[1:3]
destination = os.path.realpath(destination)
max_entries = 4096
max_total_size = 512 * 1024 * 1024
max_file_size = 256 * 1024 * 1024

with zipfile.ZipFile(archive) as package:
    entries = package.infolist()
    if not entries or len(entries) > max_entries:
        raise SystemExit(f"Unsafe XcodeGen ZIP entry count: {len(entries)}")

    total_size = 0
    validated = []
    for entry in entries:
        name = entry.filename
        if "\\" in name or "\x00" in name:
            raise SystemExit(f"Unsafe XcodeGen ZIP path: {name!r}")

        path = PurePosixPath(name)
        if path.is_absolute() or not path.parts or any(part in ("", ".", "..") for part in path.parts):
            raise SystemExit(f"Unsafe XcodeGen ZIP path: {name!r}")

        mode = (entry.external_attr >> 16) & 0xFFFF
        file_type = stat.S_IFMT(mode)
        if file_type == stat.S_IFLNK:
            raise SystemExit(f"XcodeGen ZIP contains a symbolic link: {name!r}")
        if file_type not in (0, stat.S_IFREG, stat.S_IFDIR):
            raise SystemExit(f"XcodeGen ZIP contains an unsupported file type: {name!r}")
        if entry.file_size > max_file_size:
            raise SystemExit(f"XcodeGen ZIP entry is too large: {name!r}")

        total_size += entry.file_size
        if total_size > max_total_size:
            raise SystemExit("XcodeGen ZIP exceeds the uncompressed size limit")

        target = os.path.realpath(os.path.join(destination, *path.parts))
        if os.path.commonpath((destination, target)) != destination:
            raise SystemExit(f"XcodeGen ZIP escapes the extraction root: {name!r}")
        validated.append((entry, target, mode))

    for entry, target, mode in validated:
        if entry.is_dir():
            os.makedirs(target, exist_ok=True)
            continue
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with package.open(entry, "r") as source, open(target, "xb") as output:
            shutil.copyfileobj(source, output)
        if mode:
            os.chmod(target, mode & 0o777)
PY

readonly XCODEGEN_BIN="${EXTRACT_ROOT}/bin/xcodegen"
[[ -f "${XCODEGEN_BIN}" && ! -L "${XCODEGEN_BIN}" ]] || {
  echo "Validated XcodeGen executable was not found: ${XCODEGEN_BIN}" >&2
  exit 1
}
chmod 0755 "${XCODEGEN_BIN}"

ACTUAL_VERSION="$("${XCODEGEN_BIN}" --version | tr -d '\r')"
[[ "${ACTUAL_VERSION}" == *"${VERSION}"* ]] || {
  echo "Unexpected XcodeGen version: ${ACTUAL_VERSION}" >&2
  exit 1
}

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "${EXTRACT_ROOT}/bin" >> "${GITHUB_PATH}"
else
  echo "XcodeGen is available for this process at ${XCODEGEN_BIN}" >&2
fi

printf '%s\n' "${ACTUAL_VERSION}"