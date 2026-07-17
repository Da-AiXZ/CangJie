#!/bin/bash
set -euo pipefail

# Build contract: generate-build-identity.py must run before xcodegen and xcodebuild.
readonly ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly OUT="${ROOT}/.build-ipa"
readonly DERIVED="${OUT}/DerivedData"
readonly SOURCE_PACKAGES="${OUT}/SourcePackages"
readonly MAIN_ROLE="main"
readonly MAIN_SCHEME="CangJie"
readonly MAIN_PRODUCT="CangJie"
readonly MAIN_BUNDLE_ID="com.juyang.CangJie"
readonly MAIN_ENTITLEMENTS="${ROOT}/App/Config/CangJie.entitlements"
readonly MAIN_SWIFT_IDENTITY="${ROOT}/App/CangJieApp/GeneratedBuildIdentity.swift"
readonly MAIN_IPA="CangJie-M0.ipa"
readonly PROBE_ROLE="keychainIsolationProbe"
readonly PROBE_SCHEME="CangJieKeychainIsolationProbe"
readonly PROBE_PRODUCT="CangJieKeychainIsolationProbe"
readonly PROBE_BUNDLE_ID="com.juyang.CangJie.KeychainIsolationProbe"
readonly PROBE_ENTITLEMENTS="${ROOT}/App/Config/CangJieIsolationProbe.entitlements"
readonly PROBE_SWIFT_IDENTITY="${ROOT}/App/CangJieIsolationProbe/GeneratedBuildIdentity.swift"
readonly PROBE_IPA="CangJie-Keychain-Isolation-Probe.ipa"
readonly VERSION="${CANGJIE_MARKETING_VERSION:-1.0}"
readonly LDID_TAG="v2.1.5-procursus7"

fail() { echo "$*" >&2; exit 1; }
require_tool() { command -v "$1" >/dev/null || fail "Required tool is missing: $1"; }
regular_file() { [[ -f "$1" && ! -L "$1" ]] || fail "$2 is missing or unsafe: $1"; }

for tool in python3 git xcodegen xcodebuild xcrun lipo file zip unzip shasum codesign; do require_tool "${tool}"; done
[[ "${ROOT}" != "/" && "${OUT}" == "${ROOT}/.build-ipa" ]] || fail "Unsafe candidate output path"

readonly COMMIT="${GITHUB_SHA:-$(git -C "${ROOT}" rev-parse HEAD)}"
[[ "${COMMIT}" =~ ^[0-9a-f]{40}$ ]] || fail "A full lowercase 40-character Git commit is required"
readonly RUN_ID="${GITHUB_RUN_ID:-1}"
readonly RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
readonly RUN_NUMBER="${GITHUB_RUN_NUMBER:-$(git -C "${ROOT}" rev-list --count HEAD)}"
readonly BUILD_NUMBER="${RUN_NUMBER}"
for binding in RUN_ID RUN_ATTEMPT RUN_NUMBER BUILD_NUMBER; do
  value="${!binding}"
  [[ "${value}" =~ ^[1-9][0-9]*$ ]] || fail "${binding} must be a positive integer"
done

readonly CANDIDATE_SET_ID="$(python3 - "${COMMIT}" "${RUN_ID}" "${RUN_ATTEMPT}" "${BUILD_NUMBER}" "${MAIN_BUNDLE_ID}" "${PROBE_BUNDLE_ID}" <<'PY'
import hashlib, sys
print(hashlib.sha256("|".join(sys.argv[1:]).encode("utf-8")).hexdigest())
PY
)"
[[ "${CANDIDATE_SET_ID}" =~ ^[0-9a-f]{64}$ ]] || fail "Candidate set ID generation failed"

regular_file "${MAIN_ENTITLEMENTS}" "Main entitlement contract"
regular_file "${PROBE_ENTITLEMENTS}" "Probe entitlement contract"
bash "${ROOT}/scripts/build-ipa.sh" --verify-entitlements-for-bundle "${MAIN_ENTITLEMENTS}" "${MAIN_BUNDLE_ID}"
bash "${ROOT}/scripts/build-ipa.sh" --verify-entitlements-for-bundle "${PROBE_ENTITLEMENTS}" "${PROBE_BUNDLE_ID}"

rm -rf "${OUT}"
mkdir -p "${OUT}/identity" "${OUT}/metadata" "${OUT}/signing" "${OUT}/packages"

# These calls intentionally precede project generation and every xcodebuild invocation.
python3 "${ROOT}/scripts/generate-build-identity.py" \
  --role "${MAIN_ROLE}" --bundle-id "${MAIN_BUNDLE_ID}" --version "${VERSION}" \
  --build "${BUILD_NUMBER}" --commit "${COMMIT}" --candidate-set-id "${CANDIDATE_SET_ID}" \
  --swift-output "${MAIN_SWIFT_IDENTITY}" --metadata-output "${OUT}/identity/main.json"
python3 "${ROOT}/scripts/generate-build-identity.py" \
  --role "${PROBE_ROLE}" --bundle-id "${PROBE_BUNDLE_ID}" --version "${VERSION}" \
  --build "${BUILD_NUMBER}" --commit "${COMMIT}" --candidate-set-id "${CANDIDATE_SET_ID}" \
  --swift-output "${PROBE_SWIFT_IDENTITY}" --metadata-output "${OUT}/identity/probe.json"

cd "${ROOT}"
bash "${ROOT}/scripts/build-ipa.sh" --verify-dependency-contract
xcodegen generate --spec project.yml
xcodebuild -list -json -project CangJie.xcodeproj >"${OUT}/xcode-project-list.json"
python3 - "${OUT}/xcode-project-list.json" "${MAIN_SCHEME}" "${PROBE_SCHEME}" <<'PY'
import json, sys
project=json.load(open(sys.argv[1],encoding="utf-8"))["project"]
schemes=set(project.get("schemes",[])); missing=[name for name in sys.argv[2:] if name not in schemes]
if missing: raise SystemExit(f"project.yml must define candidate schemes: {missing}")
PY

xcodebuild -resolvePackageDependencies -project CangJie.xcodeproj -scheme "${MAIN_SCHEME}" -clonedSourcePackagesDirPath "${SOURCE_PACKAGES}"
bash "${ROOT}/scripts/build-ipa.sh" --verify-resolved-packages CangJie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

build_scheme() {
  local scheme="$1" bundle_id="$2" fingerprint="$3"
  xcodebuild build \
    -project CangJie.xcodeproj -scheme "${scheme}" -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "${DERIVED}" -clonedSourcePackagesDirPath "${SOURCE_PACKAGES}" \
    -disableAutomaticPackageResolution ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    PRODUCT_BUNDLE_IDENTIFIER="${bundle_id}" CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
    MARKETING_VERSION="${VERSION}" CANGJIE_GIT_COMMIT="${COMMIT:0:12}" \
    CANGJIE_EXECUTABLE_FINGERPRINT="${fingerprint}" CANGJIE_CANDIDATE_SET_ID="${CANDIDATE_SET_ID}"
}

readonly MAIN_FINGERPRINT="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["fingerprint"])' "${OUT}/identity/main.json")"
readonly PROBE_FINGERPRINT="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["fingerprint"])' "${OUT}/identity/probe.json")"
build_scheme "${MAIN_SCHEME}" "${MAIN_BUNDLE_ID}" "${MAIN_FINGERPRINT}"
build_scheme "${PROBE_SCHEME}" "${PROBE_BUNDLE_ID}" "${PROBE_FINGERPRINT}"

readonly LDID_PATH="${LDID_PATH:-}"
regular_file "${LDID_PATH}" "Pinned ldid executable"
[[ -x "${LDID_PATH}" ]] || fail "Pinned ldid is not executable"
case "$(uname -m)" in
  arm64|aarch64) readonly LDID_ARCH="arm64"; readonly LDID_ASSET="ldid_macosx_arm64"; readonly LDID_SHA="5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50" ;;
  x86_64|amd64) readonly LDID_ARCH="x86_64"; readonly LDID_ASSET="ldid_macosx_x86_64"; readonly LDID_SHA="9d46e0feedf96e399edfca09872802ba21e729f79c01927ad25ea2b0a35bca23" ;;
  *) fail "Unsupported ldid host architecture" ;;
esac
[[ "$(shasum -a 256 "${LDID_PATH}" | awk '{print $1}')" == "${LDID_SHA}" ]] || fail "Pinned ldid SHA-256 mismatch"

package_candidate() {
  local role="$1" product="$2" bundle_id="$3" entitlement_source="$4" identity_json="$5" ipa_name="$6"
  local app="${DERIVED}/Build/Products/Release-iphoneos/${product}.app"
  local info="${app}/Info.plist"
  regular_file "${info}" "${role} Info.plist"
  python3 "${ROOT}/scripts/stamp-build-identity.py" --identity-json "${identity_json}" --unstamped-build 1 "${info}"
  if find "${app}" -type l -print -quit | grep -q .; then fail "${role} app contains a symbolic link"; fi
  if find "${app}" -name embedded.mobileprovision -print -quit | grep -q .; then fail "${role} app contains an embedded provisioning profile"; fi

  local executable_name
  executable_name="$(python3 - "${info}" "${bundle_id}" <<'PY'
import plistlib,sys
info=plistlib.load(open(sys.argv[1],"rb")); expected=sys.argv[2]
if info.get("CFBundleIdentifier") != expected: raise SystemExit("bundle identifier mismatch")
name=info.get("CFBundleExecutable")
if not isinstance(name,str) or not name or "/" in name or "\\" in name: raise SystemExit("unsafe executable name")
print(name)
PY
)"
  local executable="${app}/${executable_name}"
  regular_file "${executable}" "${role} executable"
  [[ "$(lipo -archs "${executable}" | xargs)" == "arm64" ]] || fail "${role} executable is not arm64-only"
  local unsigned_sha signed_sha
  unsigned_sha="$(shasum -a 256 "${executable}" | awk '{print $1}')"
  bash "${ROOT}/scripts/build-ipa.sh" --sign-app-with-ldid-for-bundle \
    "${LDID_PATH}" "${entitlement_source}" "${app}" "${executable}" "${bundle_id}"
  signed_sha="$(shasum -a 256 "${executable}" | awk '{print $1}')"
  [[ "${signed_sha}" != "${unsigned_sha}" ]] || fail "${role} signature did not change executable hash"

  local stem="${ipa_name%.ipa}"
  local contract_file="${stem}.entitlements"
  local signed_entitlements_file="${stem}.signed-entitlements.plist"
  cp -p "${entitlement_source}" "${OUT}/${contract_file}"
  "${LDID_PATH}" -e "${executable}" >"${OUT}/${signed_entitlements_file}"
  bash "${ROOT}/scripts/build-ipa.sh" --verify-entitlements-for-bundle "${OUT}/${signed_entitlements_file}" "${bundle_id}"

  local package_root="${OUT}/packages/${role}"
  rm -rf "${package_root}"; mkdir -p "${package_root}/Payload"
  cp -R "${app}" "${package_root}/Payload/${product}.app"
  (cd "${package_root}" && zip -qry "${OUT}/${ipa_name}" Payload)
  unzip -tq "${OUT}/${ipa_name}"
  if unzip -Z1 "${OUT}/${ipa_name}" | grep -F 'embedded.mobileprovision' >/dev/null; then fail "${role} IPA contains an embedded provisioning profile"; fi
  local ipa_sha checksum_file
  ipa_sha="$(shasum -a 256 "${OUT}/${ipa_name}" | awk '{print $1}')"
  checksum_file="${stem}.sha256"
  printf '%s  %s\n' "${ipa_sha}" "${ipa_name}" >"${OUT}/${checksum_file}"
  (cd "${OUT}" && shasum -a 256 --check --strict "${checksum_file}")

  python3 - "${OUT}/metadata/${role}.json" "${role}" "${ipa_name}" "${ipa_sha}" "${checksum_file}" \
    "${bundle_id}" "${product}" "${executable_name}" "${identity_json}" "${contract_file}" \
    "$(shasum -a 256 "${OUT}/${contract_file}" | awk '{print $1}')" "${signed_entitlements_file}" \
    "$(shasum -a 256 "${OUT}/${signed_entitlements_file}" | awk '{print $1}')" "${unsigned_sha}" "${signed_sha}" \
    "${LDID_TAG}" "${LDID_ASSET}" "${LDID_SHA}" "${LDID_ARCH}" <<'PY'
import json,plistlib,sys
(out,role,ipa,ipa_sha,checksum,bundle,product,executable,identity_path,contract_file,contract_sha,
 signed_file,signed_sha,unsigned_exe,signed_exe,tag,asset,ldid_sha,arch)=sys.argv[1:]
identity=json.load(open(identity_path,encoding="utf-8"))
entitlements={"application-identifier":bundle,"keychain-access-groups":[bundle]}
value={"role":role,"file":ipa,"sha256":ipa_sha,"checksumFile":checksum,"bundleIdentifier":bundle,
 "productName":product,"executable":executable,"compiledIdentity":identity,
 "signing":{"type":"trollstore-fakesign","signer":"ldid","ldid":{"tag":tag,"asset":asset,"sha256":ldid_sha,"architecture":arch},
 "unsignedExecutableSHA256":unsigned_exe,"signedExecutableSHA256":signed_exe,
 "entitlementContractFile":contract_file,"entitlementContractSHA256":contract_sha,
 "signedEntitlementsFile":signed_file,"signedEntitlementsSHA256":signed_sha,
 "appleDeveloperCertificate":False,"provisioningProfile":False,"appleTeamIdentifier":None,
 "contract":"trollstore-prefixless-bundle-id","entitlements":entitlements}}
json.dump(value,open(out,"w",encoding="utf-8"),ensure_ascii=False,indent=2,sort_keys=True);open(out,"a",encoding="utf-8").write("\n")
PY
}

package_candidate "${MAIN_ROLE}" "${MAIN_PRODUCT}" "${MAIN_BUNDLE_ID}" "${MAIN_ENTITLEMENTS}" "${OUT}/identity/main.json" "${MAIN_IPA}"
package_candidate "${PROBE_ROLE}" "${PROBE_PRODUCT}" "${PROBE_BUNDLE_ID}" "${PROBE_ENTITLEMENTS}" "${OUT}/identity/probe.json" "${PROBE_IPA}"

python3 "${ROOT}/scripts/create-candidate-set-manifest.py" \
  --output "${OUT}/candidate-set-manifest.json" --candidate-set-id "${CANDIDATE_SET_ID}" \
  --commit "${COMMIT}" --build "${BUILD_NUMBER}" --run-id "${RUN_ID}" --run-attempt "${RUN_ATTEMPT}" \
  --run-number "${RUN_NUMBER}" --repository "${GITHUB_REPOSITORY:-unknown}" --ref "${GITHUB_REF:-unknown}" \
  --workflow "${GITHUB_WORKFLOW:-unknown}" --reason "${BUILD_REASON:-unspecified}" \
  --artifact "${OUT}/metadata/main.json" --artifact "${OUT}/metadata/keychainIsolationProbe.json"

cat >"${OUT}/DEVICE-VALIDATION.md" <<EOF
# CangJie candidate set device validation

- Candidate Set ID: \`${CANDIDATE_SET_ID}\`
- Commit: \`${COMMIT}\`
- Build / Run: \`${BUILD_NUMBER}\`
- Run ID / Attempt: \`${RUN_ID}\` / \`${RUN_ATTEMPT}\`

Install both IPA files from this exact directory. Acceptance remains fail-closed until the main App canary and the independent Probe isolation checks pass on the target TrollStore device.
EOF

python3 "${ROOT}/scripts/verify-build-artifacts.py" "${OUT}"
printf 'Built candidate set %s with two independently entitled IPA artifacts\n' "${CANDIDATE_SET_ID}"
