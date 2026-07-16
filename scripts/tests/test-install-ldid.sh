#!/bin/bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
readonly INSTALLER="${ROOT}/scripts/install-ldid.sh"
readonly TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEMP_ROOT}"' EXIT

readonly BIN_DIR="${TEMP_ROOT}/bin"
readonly REAL_MKTEMP="$(command -v mktemp)"
readonly REAL_CHMOD="$(command -v chmod)"
export REAL_MKTEMP
mkdir -p "${BIN_DIR}"

cat >"${BIN_DIR}/uname" <<'SH'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
  -s) printf '%s\n' "${FAKE_UNAME_S:-Darwin}" ;;
  -m) printf '%s\n' "${FAKE_UNAME_M:?}" ;;
  *) echo "unexpected uname arguments: $*" >&2; exit 64 ;;
esac
SH

cat >"${BIN_DIR}/mktemp" <<'SH'
#!/bin/bash
set -euo pipefail
case "${FAKE_MKTEMP_MODE:-normal}" in
  normal)
    exec "${REAL_MKTEMP:?}" "$@"
    ;;
  outside)
    mkdir -p "${FAKE_OUTSIDE_DIR:?}"
    printf '%s\n' "${FAKE_OUTSIDE_DIR}"
    ;;
  relative)
    printf '%s\n' "${FAKE_RELATIVE_DIR:?}"
    ;;
  *)
    echo "unknown fake mktemp mode" >&2
    exit 65
    ;;
esac
SH

cat >"${BIN_DIR}/curl" <<'SH'
#!/bin/bash
set -euo pipefail
[[ "${FAKE_CURL_FAIL:-0}" != "1" ]] || {
  echo "curl: simulated download failure" >&2
  exit 22
}

actual=("$@")
required=(--fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 20 --max-time 120 --max-filesize "${FAKE_EXPECTED_SIZE:?}" --retry 3 --retry-all-errors --silent --show-error)
index=0
for expected in "${required[@]}"; do
  [[ "${actual[$index]:-}" == "${expected}" ]] || {
    printf 'unsafe curl argument %s: got %q expected %q\n' "${index}" "${actual[$index]:-}" "${expected}" >&2
    exit 64
  }
  index=$((index + 1))
done
[[ "${actual[$index]:-}" == "${FAKE_EXPECTED_URL:?}" ]] || {
  echo "unexpected download URL: ${actual[$index]:-}" >&2
  exit 64
}
index=$((index + 1))
[[ "${actual[$index]:-}" == "--output" ]] || { echo "missing curl --output" >&2; exit 64; }
index=$((index + 1))
output="${actual[$index]:-}"
[[ -n "${output}" && "${#actual[@]}" -eq $((index + 1)) ]] || {
  echo "unexpected curl output arguments" >&2
  exit 64
}

if [[ "${FAKE_CURL_OUTPUT_MODE:-regular}" == "symlink" ]]; then
  rm -f "${output}"
  ln -s "${FAKE_SYMLINK_TARGET:?}" "${output}"
else
  : >"${output}"
  truncate -s "${FAKE_EXPECTED_SIZE:?}" "${output}"
fi
SH

cat >"${BIN_DIR}/shasum" <<'SH'
#!/bin/bash
set -euo pipefail
[[ "$#" -eq 4 && "$1" == "-a" && "$2" == "256" && "$3" == "--check" && "$4" == "--strict" ]] || {
  echo "unexpected shasum arguments: $*" >&2
  exit 64
}
IFS= read -r line
actual_sha="${line%%  *}"
file="${line#*  }"
[[ -f "${file}" && ! -L "${file}" ]] || { echo "unsafe shasum input" >&2; exit 64; }
[[ "${actual_sha}" == "${FAKE_EXPECTED_SHA:?}" ]] || {
  echo "installer supplied unexpected SHA: ${actual_sha}" >&2
  exit 64
}
[[ "${FAKE_SHA_MISMATCH:-0}" != "1" ]] || {
  echo "${file}: FAILED" >&2
  exit 1
}
printf '%s: OK\n' "${file}"
SH

cat >"${BIN_DIR}/lipo" <<'SH'
#!/bin/bash
set -euo pipefail
[[ "$#" -eq 2 && "$1" == "-archs" && -f "$2" && ! -L "$2" ]] || {
  echo "unexpected lipo invocation" >&2
  exit 64
}
printf '%s\n' "${FAKE_LIPO_ARCHS:?}"
SH

cat >"${BIN_DIR}/chmod" <<'SH'
#!/bin/bash
set -euo pipefail
[[ "$#" -eq 2 && "$1" == "0755" && -f "$2" && ! -L "$2" ]] || {
  echo "unexpected chmod invocation: $*" >&2
  exit 64
}
printf '%s\n' "$2" >"${FAKE_CHMOD_LOG:?}"
SH

"${REAL_CHMOD}" +x "${BIN_DIR}"/*

assert_success() {
  local label="$1"
  local arch="$2"
  local asset="$3"
  local sha="$4"
  local run_root="${TEMP_ROOT}/${label}-runner"
  local stdout="${TEMP_ROOT}/${label}.stdout"
  local stderr="${TEMP_ROOT}/${label}.stderr"
  mkdir -p "${run_root}"
  run_root="$(cd "${run_root}" && pwd -P)"

  if ! PATH="${BIN_DIR}:${PATH}" \
    RUNNER_TEMP="${run_root}" \
    FAKE_UNAME_M="${arch}" \
    FAKE_EXPECTED_URL="https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/${asset}" \
    FAKE_EXPECTED_SHA="${sha}" \
    FAKE_EXPECTED_SIZE="$([[ "${arch}" == "arm64" ]] && printf 2572056 || printf 2824936)" \
    FAKE_LIPO_ARCHS="${arch}" \
    FAKE_CHMOD_LOG="${TEMP_ROOT}/${label}.chmod" \
    bash "${INSTALLER}" >"${stdout}" 2>"${stderr}"; then
    echo "Expected success for ${label}" >&2
    cat "${stderr}" >&2
    exit 1
  fi

  [[ ! -s "${stderr}" ]] || { echo "Unexpected stderr for ${label}" >&2; cat "${stderr}" >&2; exit 1; }
  [[ "$(wc -l <"${stdout}" | tr -d ' ')" == "1" ]] || { echo "Expected one output path for ${label}" >&2; cat "${stdout}" >&2; exit 1; }
  local executable
  executable="$(cat "${stdout}")"
  [[ "${executable}" == /* ]] || { echo "Installer returned a non-absolute path: ${executable}" >&2; exit 1; }
  [[ "${executable}" == "${run_root}"/* ]] || { echo "Installer escaped RUNNER_TEMP: ${executable}" >&2; exit 1; }
  [[ -f "${executable}" && ! -L "${executable}" ]] || {
    echo "Installer returned an unsafe executable: ${executable}" >&2
    exit 1
  }
  [[ "$(cat "${TEMP_ROOT}/${label}.chmod")" == "${executable%/*}/ldid.download" ]] || {
    echo "Installer did not chmod the verified temporary file for ${label}" >&2
    exit 1
  }
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
    echo "Unexpected failure for ${label}" >&2
    cat "${stderr}" >&2
    exit 1
  }
}

readonly ARM64_SHA="5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50"
readonly X86_64_SHA="9d46e0feedf96e399edfca09872802ba21e729f79c01927ad25ea2b0a35bca23"

assert_success arm64 arm64 ldid_macosx_arm64 "${ARM64_SHA}"
assert_success x86-64 x86_64 ldid_macosx_x86_64 "${X86_64_SHA}"

common_failure_env=(
  env
  "PATH=${BIN_DIR}:${PATH}"
  "REAL_MKTEMP=${REAL_MKTEMP}"
  "FAKE_UNAME_M=arm64"
  "FAKE_EXPECTED_URL=https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_macosx_arm64"
  "FAKE_EXPECTED_SHA=${ARM64_SHA}"
  "FAKE_EXPECTED_SIZE=2572056"
  "FAKE_LIPO_ARCHS=arm64"
)

mkdir -p "${TEMP_ROOT}/sha-runner"
assert_failure sha-mismatch "ldid SHA-256 mismatch" \
  "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/sha-runner" "FAKE_SHA_MISMATCH=1" bash "${INSTALLER}"

mkdir -p "${TEMP_ROOT}/download-runner"
assert_failure download-failure "Failed to download ldid" \
  "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/download-runner" "FAKE_CURL_FAIL=1" bash "${INSTALLER}"

mkdir -p "${TEMP_ROOT}/unknown-runner"
assert_failure unknown-architecture "Unsupported macOS architecture: riscv64" \
  env "PATH=${BIN_DIR}:${PATH}" "REAL_MKTEMP=${REAL_MKTEMP}" "RUNNER_TEMP=${TEMP_ROOT}/unknown-runner" \
  "FAKE_UNAME_M=riscv64" bash "${INSTALLER}"

mkdir -p "${TEMP_ROOT}/wrong-lipo-runner"
assert_failure wrong-lipo-architecture "Unexpected ldid architecture: x86_64 (expected arm64)" \
  "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/wrong-lipo-runner" "FAKE_LIPO_ARCHS=x86_64" bash "${INSTALLER}"

printf 'outside\n' >"${TEMP_ROOT}/symlink-target"
if ln -s "${TEMP_ROOT}/symlink-target" "${TEMP_ROOT}/symlink-probe" 2>/dev/null \
  && [[ -L "${TEMP_ROOT}/symlink-probe" ]]; then
  mkdir -p "${TEMP_ROOT}/symlink-runner"
  assert_failure symlink-download "Downloaded ldid is missing or unsafe" \
    "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/symlink-runner" \
    "FAKE_CURL_OUTPUT_MODE=symlink" "FAKE_SYMLINK_TARGET=${TEMP_ROOT}/symlink-target" bash "${INSTALLER}"

  mkdir -p "${TEMP_ROOT}/real-runner"
  ln -s "${TEMP_ROOT}/real-runner" "${TEMP_ROOT}/linked-runner"
  assert_failure symlink-runner-temp "RUNNER_TEMP is missing or unsafe" \
    "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/linked-runner" bash "${INSTALLER}"
else
  printf 'install-ldid symlink negative tests skipped: host cannot create symbolic links\n' >&2
fi

mkdir -p "${TEMP_ROOT}/unsafe-runner" "${TEMP_ROOT}/outside-install"
assert_failure escaped-install-root "Unsafe ldid install directory" \
  "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/unsafe-runner" \
  "FAKE_MKTEMP_MODE=outside" "FAKE_OUTSIDE_DIR=${TEMP_ROOT}/outside-install" bash "${INSTALLER}"

mkdir -p "${TEMP_ROOT}/relative-runner"
assert_failure relative-install-root "Unsafe ldid install directory" \
  "${common_failure_env[@]}" "RUNNER_TEMP=${TEMP_ROOT}/relative-runner" \
  "FAKE_MKTEMP_MODE=relative" "FAKE_RELATIVE_DIR=relative-ldid-output" bash "${INSTALLER}"

printf 'install-ldid tests passed\n'
