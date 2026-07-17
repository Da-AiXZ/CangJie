#!/usr/bin/env python3
import base64
import hashlib
import importlib.util
import json
import os
import plistlib
import stat
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "scripts" / "verify-build-artifacts.py"
sys.path.insert(0, str(ROOT / "scripts"))
from candidate_set_identity import derive_build_version, derive_candidate_set_id  # noqa: E402

MAIN_BUNDLE = "com.juyang.CangJie"
PROBE_BUNDLE = "com.juyang.CangJie.KeychainIsolationProbe"
COMMIT = "b" * 40
RUN_ID = "123456"
RUN_ATTEMPT = "2"
RUN_NUMBER = "28"
VERSION = "1.0"
BUILD = derive_build_version(RUN_NUMBER, RUN_ATTEMPT)
CANDIDATE_ID = derive_candidate_set_id(
    commit=COMMIT,
    run_id=RUN_ID,
    run_attempt=RUN_ATTEMPT,
    run_number=RUN_NUMBER,
    version=VERSION,
    build=BUILD,
    main_bundle_id=MAIN_BUNDLE,
    probe_bundle_id=PROBE_BUNDLE,
)
MARKER_PREFIX = b"CANGJIE_IDENTITY_V1:"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_json(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")


def marker_for(identity: dict, *, canonical=True, terminate=True) -> bytes:
    raw = canonical_json(identity) if canonical else json.dumps(identity, ensure_ascii=False).encode("utf-8")
    payload = base64.urlsafe_b64encode(raw).rstrip(b"=")
    return MARKER_PREFIX + payload + (b"\0" if terminate else b"")


def zip_info(name: str, mode: int = 0o644) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name)
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | mode) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    return info


class VerifyBuildArtifactsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.artifacts = []
        self._add_artifact("main", "CangJie-M0", "CangJie", MAIN_BUNDLE)
        self._add_artifact(
            "keychainIsolationProbe",
            "CangJie-Keychain-Isolation-Probe",
            "CangJieKeychainIsolationProbe",
            PROBE_BUNDLE,
        )
        self.manifest = {
            "schemaVersion": 5,
            "candidateSetID": CANDIDATE_ID,
            "commit": COMMIT,
            "version": VERSION,
            "build": BUILD,
            "runId": RUN_ID,
            "runAttempt": RUN_ATTEMPT,
            "runNumber": RUN_NUMBER,
            "artifacts": self.artifacts,
            "acceptance": {
                "status": "blocked-pending-trollstore-device-keychain-isolation-validation",
                "failClosed": True,
            },
        }
        self.write_manifest()

    def tearDown(self):
        self.temp.cleanup()

    def _identity(self, role, bundle_id):
        fingerprint = hashlib.sha256(
            f"cangjie-executable-v1|{role}|{bundle_id}|{VERSION}|{BUILD}|{COMMIT}|{CANDIDATE_ID}".encode()
        ).hexdigest()
        return {
            "schemaVersion": 1,
            "role": role,
            "bundleIdentifier": bundle_id,
            "version": VERSION,
            "build": BUILD,
            "commit": COMMIT,
            "visibleCommit": COMMIT[:12],
            "fingerprint": fingerprint,
            "candidateSetID": CANDIDATE_ID,
        }

    def _add_artifact(self, role, stem, product, bundle_id):
        identity = self._identity(role, bundle_id)
        artifact = {
            "role": role,
            "file": f"{stem}.ipa",
            "checksumFile": f"{stem}.sha256",
            "bundleIdentifier": bundle_id,
            "productName": product,
            "executable": product,
            "compiledIdentity": identity,
        }
        entitlements = {
            "application-identifier": bundle_id,
            "keychain-access-groups": [bundle_id],
        }
        contract = self.root / f"{stem}.entitlements"
        contract.write_bytes(plistlib.dumps(entitlements))
        signed = self.root / f"{stem}.signed-entitlements.plist"
        signed.write_bytes(plistlib.dumps(entitlements))
        artifact["signing"] = {
            "type": "trollstore-fakesign",
            "signer": "ldid",
            "ldid": {
                "tag": "v2.1.5-procursus7",
                "asset": "ldid_macosx_arm64",
                "sha256": "5dff8e6b8d9dc3ff7226276c81e09930865f15381f54cb55b98b196a94c5ca50",
                "architecture": "arm64",
            },
            "unsignedExecutableSHA256": "1" * 64,
            "entitlementContractFile": contract.name,
            "entitlementContractSHA256": sha256(contract),
            "signedEntitlementsFile": signed.name,
            "signedEntitlementsSHA256": sha256(signed),
            "appleDeveloperCertificate": False,
            "provisioningProfile": False,
            "appleTeamIdentifier": None,
            "contract": "trollstore-prefixless-bundle-id",
            "entitlements": entitlements,
        }
        self.artifacts.append(artifact)
        self._write_ipa(artifact)

    def _info(self, artifact, executable=None, bundle_id=None):
        identity = artifact["compiledIdentity"]
        return {
            "CFBundleExecutable": executable or artifact["productName"],
            "CFBundleIdentifier": bundle_id or artifact["bundleIdentifier"],
            "CFBundleVersion": identity["build"],
            "CFBundleShortVersionString": identity["version"],
            "CangJieGitCommit": identity["visibleCommit"],
            "CangJieExecutableFingerprint": identity["fingerprint"],
            "CangJieCandidateSetID": identity["candidateSetID"],
        }

    def _write_ipa(
        self,
        artifact,
        *,
        app_name=None,
        executable=None,
        executable_data=None,
        executable_mode=0o755,
        extra_entries=(),
        duplicate_executable=False,
    ):
        product = app_name or artifact["productName"]
        executable = executable or artifact["productName"]
        app_root = f"Payload/{product}.app"
        identity = artifact["compiledIdentity"]
        if executable_data is None:
            executable_data = b"mock-macho\0" + marker_for(identity) + b"tail"
        ipa = self.root / artifact["file"]
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr(zip_info(f"{app_root}/Info.plist"), plistlib.dumps(self._info(artifact, executable)))
                executable_info = zip_info(f"{app_root}/{executable}", executable_mode)
                archive.writestr(executable_info, executable_data)
                if duplicate_executable:
                    archive.writestr(executable_info, executable_data)
                for name, data, mode in extra_entries:
                    archive.writestr(zip_info(name, mode), data)
        self._refresh_artifact(artifact, executable_data)

    def _refresh_artifact(self, artifact, executable_data=None):
        ipa = self.root / artifact["file"]
        artifact["sha256"] = sha256(ipa)
        (self.root / artifact["checksumFile"]).write_text(
            f"{artifact['sha256']}  {ipa.name}\n", encoding="utf-8"
        )
        if executable_data is not None:
            artifact["signing"]["signedExecutableSHA256"] = hashlib.sha256(executable_data).hexdigest()

    def write_manifest(self):
        (self.root / "candidate-set-manifest.json").write_text(
            json.dumps(self.manifest), encoding="utf-8"
        )

    def run_verifier(self, root=None):
        return subprocess.run(
            [sys.executable, str(VERIFIER), str(root or self.root), "--metadata-only"],
            text=True,
            capture_output=True,
        )

    def assert_rejected(self, message):
        self.write_manifest()
        result = self.run_verifier()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn(message, result.stderr)

    def test_accepts_complete_consistent_candidate_set(self):
        result = self.run_verifier()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_rejects_mixed_artifact_marketing_versions(self):
        self.artifacts[1]["compiledIdentity"]["version"] = "1.1"
        self.assert_rejected("compiled identity version mismatch")

    def test_rejects_manifest_marketing_version_drift(self):
        self.manifest["version"] = "1.1"
        self.assert_rejected("candidate set derivation mismatch")

    def test_recomputes_candidate_set_id(self):
        self.manifest["runId"] = "654321"
        self.assert_rejected("candidate set derivation mismatch")

    def test_rejects_run_attempt_change_without_new_candidate(self):
        self.manifest["runAttempt"] = "3"
        self.manifest["build"] = derive_build_version(RUN_NUMBER, "3")
        self.assert_rejected("candidate set derivation mismatch")

    def test_rejects_non_unique_build_formula(self):
        self.manifest["build"] = RUN_NUMBER
        self.assert_rejected("run/build binding mismatch")

    def test_rejects_attempt_outside_suffix_range(self):
        self.manifest["runAttempt"] = "1000"
        self.assert_rejected("runAttempt binding mismatch")

    def test_rejects_incomplete_or_wrong_compiled_identity_schema(self):
        cases = [
            ("schemaVersion", None, "compiled identity schema mismatch"),
            ("schemaVersion", 2, "compiled identity schema mismatch"),
            ("schemaVersion", True, "compiled identity schema mismatch"),
            ("role", "main", "compiled identity role mismatch"),
            ("bundleIdentifier", MAIN_BUNDLE, "compiled identity bundle identifier mismatch"),
            ("visibleCommit", "0" * 12, "visible commit binding mismatch"),
        ]
        artifact = self.artifacts[1]
        for field, value, message in cases:
            with self.subTest(field=field, value=value):
                original = artifact["compiledIdentity"].copy()
                if value is None:
                    artifact["compiledIdentity"].pop(field)
                else:
                    artifact["compiledIdentity"][field] = value
                self.assert_rejected(message)
                artifact["compiledIdentity"] = original

    def test_rejects_compiled_identity_extra_fields(self):
        self.artifacts[0]["compiledIdentity"]["shadowCommit"] = "trusted-looking"
        self.assert_rejected("compiled identity schema mismatch")

    def test_rejects_wrong_product_name(self):
        self.artifacts[0]["productName"] = "CangJieRenamed"
        self.assert_rejected("product name mismatch")

    def test_rejects_wrong_fixed_app_root(self):
        artifact = self.artifacts[0]
        self._write_ipa(artifact, app_name="Renamed")
        self.assert_rejected("IPA app root mismatch")

    def test_rejects_wrong_fixed_executable_name(self):
        artifact = self.artifacts[0]
        artifact["executable"] = "Renamed"
        self._write_ipa(artifact, executable="Renamed")
        self.assert_rejected("executable binding mismatch")

    def test_rejects_executable_without_execute_bit(self):
        artifact = self.artifacts[0]
        self._write_ipa(artifact, executable_mode=0o644)
        self.assert_rejected("IPA executable mode is invalid")

    def test_rejects_duplicate_zip_entry(self):
        artifact = self.artifacts[0]
        self._write_ipa(artifact, duplicate_executable=True)
        self.assert_rejected("duplicate IPA entry")

    def test_rejects_extra_top_level_path(self):
        artifact = self.artifacts[0]
        self._write_ipa(artifact, extra_entries=[("unexpected.txt", b"evil", 0o644)])
        self.assert_rejected("unexpected IPA entry root")

    def test_rejects_noncanonical_dot_path_segment(self):
        artifact = self.artifacts[0]
        self._write_ipa(
            artifact,
            extra_entries=[("Payload/CangJie.app/./shadow", b"evil", 0o644)],
        )
        self.assert_rejected("unsafe IPA entry")

    def test_rejects_missing_marker(self):
        artifact = self.artifacts[0]
        self._write_ipa(artifact, executable_data=b"mock-macho-without-identity")
        self.assert_rejected("executable identity marker count mismatch")

    def test_rejects_duplicate_marker(self):
        artifact = self.artifacts[0]
        marker = marker_for(artifact["compiledIdentity"])
        self._write_ipa(artifact, executable_data=b"macho" + marker + b"middle" + marker)
        self.assert_rejected("executable identity marker count mismatch")

    def test_rejects_marker_without_nul_terminator(self):
        artifact = self.artifacts[0]
        data = b"macho" + marker_for(artifact["compiledIdentity"], terminate=False)
        self._write_ipa(artifact, executable_data=data)
        self.assert_rejected("executable identity marker is not NUL terminated")

    def test_rejects_invalid_marker_base64url(self):
        artifact = self.artifacts[0]
        self._write_ipa(artifact, executable_data=b"macho" + MARKER_PREFIX + b"***\0")
        self.assert_rejected("executable identity marker payload is invalid")

    def test_rejects_noncanonical_marker_json(self):
        artifact = self.artifacts[0]
        data = b"macho" + marker_for(artifact["compiledIdentity"], canonical=False)
        self._write_ipa(artifact, executable_data=data)
        self.assert_rejected("executable identity marker JSON is not canonical")

    def test_rejects_marker_identity_different_from_manifest(self):
        artifact = self.artifacts[0]
        marker_identity = artifact["compiledIdentity"].copy()
        marker_identity["visibleCommit"] = "0" * 12
        self._write_ipa(artifact, executable_data=b"macho" + marker_for(marker_identity))
        self.assert_rejected("executable identity marker mismatch")

    def test_rejects_embedded_profile(self):
        artifact = self.artifacts[1]
        self._write_ipa(
            artifact,
            extra_entries=[(
                "Payload/CangJieKeychainIsolationProbe.app/embedded.mobileprovision",
                b"forbidden",
                0o644,
            )],
        )
        self.assert_rejected("embedded provisioning profile")

    def test_rejects_casefold_equivalent_zip_paths(self):
        artifact = self.artifacts[0]
        self._write_ipa(
            artifact,
            extra_entries=[("Payload/CangJie.app/info.plist", b"shadow", 0o644)],
        )
        self.assert_rejected("filesystem-equivalent IPA entry")

    def test_rejects_unicode_normalization_equivalent_zip_paths(self):
        artifact = self.artifacts[0]
        self._write_ipa(
            artifact,
            extra_entries=[
                ("Payload/CangJie.app/R\u00e9sum\u00e9.txt", b"nfc", 0o644),
                ("Payload/CangJie.app/Résumé.txt", b"nfd", 0o644),
            ],
        )
        self.assert_rejected("filesystem-equivalent IPA entry")

    def test_rejects_unreviewed_nested_code(self):
        artifact = self.artifacts[0]
        cases = [
            "Payload/CangJie.app/PlugIns/Evil.appex/Evil",
            "Payload/CangJie.app/Frameworks/Evil.framework/Evil",
            "Payload/CangJie.app/Frameworks/libEvil.dylib",
            "Payload/CangJie.app/Watch/Evil.app/Evil",
            "Payload/CangJie.app/XPCServices/Evil.xpc/Evil",
        ]
        for name in cases:
            with self.subTest(name=name):
                self._write_ipa(artifact, extra_entries=[(name, b"code", 0o755)])
                self.assert_rejected("unreviewed nested code")

    def test_rejects_duplicate_manifest_json_keys(self):
        encoded = json.dumps(self.manifest)
        (self.root / "candidate-set-manifest.json").write_text(
            '{"schemaVersion":5,' + encoded[1:], encoding="utf-8"
        )
        result = self.run_verifier()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("duplicate JSON key", result.stderr)

    def test_rejects_symlink_artifact_root(self):
        link = self.root.parent / (self.root.name + "-link")
        try:
            os.symlink(self.root, link, target_is_directory=True)
        except (OSError, NotImplementedError) as error:
            self.skipTest(f"directory symlink unavailable: {error}")
        try:
            result = self.run_verifier(link)
            self.assertNotEqual(result.returncode, 0, result.stderr)
            self.assertIn("artifact directory is missing or unsafe", result.stderr)
        finally:
            link.unlink(missing_ok=True)

    def test_rejects_archive_limit_violations_without_allocating_huge_files(self):
        spec = importlib.util.spec_from_file_location("verify_build_artifacts", VERIFIER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        too_many = [SimpleNamespace(file_size=0, compress_size=0, flag_bits=0)] * (module.MAX_IPA_ENTRIES + 1)
        with self.assertRaisesRegex(SystemExit, "compressed size limit"):
            module.validate_archive_limits(
                SimpleNamespace(stat=lambda: SimpleNamespace(st_size=module.MAX_IPA_BYTES + 1)),
                [],
            )
        with self.assertRaisesRegex(SystemExit, "too many entries"):
            module.validate_archive_limits(SimpleNamespace(stat=lambda: SimpleNamespace(st_size=1)), too_many)
        oversized = [SimpleNamespace(file_size=module.MAX_IPA_ENTRY_BYTES + 1, compress_size=1, flag_bits=0)]
        encrypted = [SimpleNamespace(file_size=1, compress_size=1, flag_bits=1)]
        with self.assertRaisesRegex(SystemExit, "encrypted IPA entries"):
            module.validate_archive_limits(SimpleNamespace(stat=lambda: SimpleNamespace(st_size=1)), encrypted)
        with self.assertRaisesRegex(SystemExit, "entry size limit"):
            module.validate_archive_limits(SimpleNamespace(stat=lambda: SimpleNamespace(st_size=1)), oversized)
        total = [
            SimpleNamespace(
                file_size=module.MAX_IPA_ENTRY_BYTES,
                compress_size=module.MAX_IPA_ENTRY_BYTES,
                flag_bits=0,
            )
            for _ in range(module.MAX_IPA_UNCOMPRESSED_BYTES // module.MAX_IPA_ENTRY_BYTES + 1)
        ]
        with self.assertRaisesRegex(SystemExit, "uncompressed size limit"):
            module.validate_archive_limits(SimpleNamespace(stat=lambda: SimpleNamespace(st_size=1)), total)

    def test_rejects_extreme_compression_ratio(self):
        artifact = self.artifacts[0]
        self._write_ipa(
            artifact,
            extra_entries=[("Payload/CangJie.app/zeros.bin", b"\0" * (1024 * 1024), 0o644)],
        )
        self.assert_rejected("compression ratio limit")

    def test_rejects_signed_entitlements_not_exact(self):
        signed = self.root / self.artifacts[1]["signing"]["signedEntitlementsFile"]
        signed.write_bytes(plistlib.dumps({"application-identifier": PROBE_BUNDLE}))
        self.artifacts[1]["signing"]["signedEntitlementsSHA256"] = sha256(signed)
        self.assert_rejected("signed entitlement mismatch")

    def test_rejects_non_fail_closed_acceptance(self):
        self.manifest["acceptance"]["failClosed"] = False
        self.assert_rejected("acceptance gate mismatch")


if __name__ == "__main__":
    unittest.main()
