#!/usr/bin/env python3
import argparse
import datetime
import json
import os
import re
import tempfile
from pathlib import Path

from candidate_set_identity import (
    CandidateIdentityError,
    derive_build_version,
    derive_candidate_set_id,
    validate_compiled_identity,
)

HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
MAIN_BUNDLE = "com.juyang.CangJie"
PROBE_BUNDLE = "com.juyang.CangJie.KeychainIsolationProbe"
ARTIFACT_SPECS = {
    "main": {
        "bundleIdentifier": MAIN_BUNDLE,
        "productName": "CangJie",
        "executable": "CangJie",
    },
    "keychainIsolationProbe": {
        "bundleIdentifier": PROBE_BUNDLE,
        "productName": "CangJieKeychainIsolationProbe",
        "executable": "CangJieKeychainIsolationProbe",
    },
}


def fail(message: str) -> None:
    raise SystemExit(message)


def _reject_duplicate_json_keys(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def load(path: Path):
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_json_keys,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"invalid artifact metadata: {error}")
    if not isinstance(value, dict):
        fail("invalid artifact metadata root")
    return value


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as destination:
            destination.write(text)
            destination.flush()
            os.fsync(destination.fileno())
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def validate_artifacts(artifacts, args) -> None:
    if len(artifacts) != len(ARTIFACT_SPECS):
        fail("artifact roles mismatch")
    by_role = {}
    for artifact in artifacts:
        role = artifact.get("role")
        if role in by_role or role not in ARTIFACT_SPECS:
            fail("artifact roles mismatch")
        by_role[role] = artifact
    if set(by_role) != set(ARTIFACT_SPECS):
        fail("artifact roles mismatch")

    for role, spec in ARTIFACT_SPECS.items():
        artifact = by_role[role]
        for field in ("bundleIdentifier", "productName", "executable"):
            if artifact.get(field) != spec[field]:
                fail(f"{role} artifact {field} mismatch")
        try:
            validate_compiled_identity(
                artifact.get("compiledIdentity"),
                role=role,
                bundle_identifier=spec["bundleIdentifier"],
                version=args.version,
                build=args.build,
                commit=args.commit,
                candidate_set_id=args.candidate_set_id,
            )
        except CandidateIdentityError as error:
            fail(str(error))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--candidate-set-id", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--run-attempt", required=True)
    parser.add_argument("--run-number", required=True)
    parser.add_argument("--repository", default="unknown")
    parser.add_argument("--ref", default="unknown")
    parser.add_argument("--workflow", default="unknown")
    parser.add_argument("--reason", default="unspecified")
    parser.add_argument("--artifact", action="append", required=True)
    args = parser.parse_args()

    if not HEX64.fullmatch(args.candidate_set_id):
        fail("invalid candidate set ID")
    if not HEX40.fullmatch(args.commit):
        fail("invalid commit")
    try:
        expected_build = derive_build_version(args.run_number, args.run_attempt)
        if args.build != expected_build:
            fail("build must equal runNumber * 1000 + runAttempt")
        expected_candidate = derive_candidate_set_id(
            commit=args.commit,
            run_id=args.run_id,
            run_attempt=args.run_attempt,
            run_number=args.run_number,
            version=args.version,
            build=args.build,
            main_bundle_id=MAIN_BUNDLE,
            probe_bundle_id=PROBE_BUNDLE,
        )
    except CandidateIdentityError as error:
        fail(str(error))
    if args.candidate_set_id != expected_candidate:
        fail("candidate set derivation mismatch")

    artifacts = [load(Path(path)) for path in args.artifact]
    validate_artifacts(artifacts, args)
    manifest = {
        "schemaVersion": 5,
        "candidateSetID": args.candidate_set_id,
        "commit": args.commit,
        "version": args.version,
        "build": args.build,
        "runId": args.run_id,
        "runAttempt": args.run_attempt,
        "runNumber": args.run_number,
        "repository": args.repository,
        "ref": args.ref,
        "workflow": args.workflow,
        "reason": args.reason,
        "builtAtUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "artifacts": artifacts,
        "acceptance": {
            "status": "blocked-pending-trollstore-device-keychain-isolation-validation",
            "failClosed": True,
            "requiredChecks": [
                "Install both exact SHA-256 IPA artifacts from this candidate set",
                "Prepare the isolation canary in CangJie",
                "Run the companion own-group control and forbidden-group entitlement check",
                "Require errSecMissingEntitlement for the explicit main-group query",
            ],
            "reason": "macOS CI can verify signing contracts but cannot prove TrollStore real-device Keychain isolation.",
        },
    }
    atomic_write(
        Path(args.output),
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    )


if __name__ == "__main__":
    main()
