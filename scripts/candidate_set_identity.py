#!/usr/bin/env python3
"""Shared, deterministic identity rules for a CangJie candidate set."""

import argparse
import hashlib
import json
import re
from typing import Mapping

HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
POSITIVE_DECIMAL = re.compile(r"^[1-9][0-9]*$")
BUNDLE_IDENTIFIER = re.compile(r"^[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+$")
VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){1,2}$")
MAX_RUN_ATTEMPT = 999
IDENTITY_SCHEMA_VERSION = 1
IDENTITY_KEYS = frozenset(
    {
        "schemaVersion",
        "role",
        "bundleIdentifier",
        "version",
        "build",
        "commit",
        "visibleCommit",
        "fingerprint",
        "candidateSetID",
    }
)


class CandidateIdentityError(ValueError):
    pass


def _positive_decimal(value: str, label: str) -> str:
    if not isinstance(value, str) or not POSITIVE_DECIMAL.fullmatch(value):
        raise CandidateIdentityError(f"{label} must be a canonical positive integer")
    return value


def derive_build_version(run_number: str, run_attempt: str) -> str:
    run_number = _positive_decimal(run_number, "run number")
    run_attempt = _positive_decimal(run_attempt, "run attempt")
    attempt = int(run_attempt)
    if attempt > MAX_RUN_ATTEMPT:
        raise CandidateIdentityError(f"run attempt must be between 1 and {MAX_RUN_ATTEMPT}")
    return str(int(run_number) * 1000 + attempt)


def derive_candidate_set_id(
    *,
    commit: str,
    run_id: str,
    run_attempt: str,
    run_number: str,
    version: str,
    build: str,
    main_bundle_id: str,
    probe_bundle_id: str,
) -> str:
    if not isinstance(commit, str) or not HEX40.fullmatch(commit):
        raise CandidateIdentityError("commit must be a full lowercase 40-character SHA")
    run_id = _positive_decimal(run_id, "run ID")
    run_attempt = _positive_decimal(run_attempt, "run attempt")
    run_number = _positive_decimal(run_number, "run number")
    if not isinstance(version, str) or not VERSION.fullmatch(version):
        raise CandidateIdentityError("version must be a canonical marketing version")
    build = _positive_decimal(build, "build")
    expected_build = derive_build_version(run_number, run_attempt)
    if build != expected_build:
        raise CandidateIdentityError("build does not match run number and run attempt")
    for value, label in (
        (main_bundle_id, "main bundle identifier"),
        (probe_bundle_id, "probe bundle identifier"),
    ):
        if not isinstance(value, str) or not BUNDLE_IDENTIFIER.fullmatch(value):
            raise CandidateIdentityError(f"invalid {label}")
    canonical = json.dumps(
        [
            "cangjie-candidate-set-v2",
            commit,
            version,
            run_id,
            run_attempt,
            run_number,
            build,
            main_bundle_id,
            probe_bundle_id,
        ],
        ensure_ascii=True,
        separators=(",", ":"),
    ).encode("ascii")
    return hashlib.sha256(canonical).hexdigest()


def expected_fingerprint(
    role: str,
    bundle_identifier: str,
    version: str,
    build: str,
    commit: str,
    candidate_set_id: str,
) -> str:
    canonical = "|".join(
        [
            "cangjie-executable-v1",
            role,
            bundle_identifier,
            version,
            build,
            commit,
            candidate_set_id,
        ]
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def validate_compiled_identity(
    identity: object,
    *,
    role: str,
    bundle_identifier: str,
    version: str,
    build: str,
    commit: str,
    candidate_set_id: str,
) -> Mapping[str, object]:
    if not isinstance(identity, dict) or set(identity) != IDENTITY_KEYS:
        raise CandidateIdentityError("compiled identity schema mismatch")
    if type(identity.get("schemaVersion")) is not int or identity["schemaVersion"] != IDENTITY_SCHEMA_VERSION:
        raise CandidateIdentityError("compiled identity schema mismatch")
    if identity.get("role") != role:
        raise CandidateIdentityError("compiled identity role mismatch")
    if identity.get("bundleIdentifier") != bundle_identifier:
        raise CandidateIdentityError("compiled identity bundle identifier mismatch")
    if not isinstance(version, str) or not VERSION.fullmatch(version):
        raise CandidateIdentityError("compiled identity version mismatch")
    if identity.get("version") != version:
        raise CandidateIdentityError("compiled identity version mismatch")
    if identity.get("build") != build:
        raise CandidateIdentityError("build binding mismatch")
    if identity.get("commit") != commit:
        raise CandidateIdentityError("commit binding mismatch")
    if identity.get("visibleCommit") != commit[:12]:
        raise CandidateIdentityError("visible commit binding mismatch")
    if identity.get("candidateSetID") != candidate_set_id:
        raise CandidateIdentityError("candidate set binding mismatch")
    fingerprint = expected_fingerprint(role, bundle_identifier, version, build, commit, candidate_set_id)
    if identity.get("fingerprint") != fingerprint:
        raise CandidateIdentityError("compiled identity fingerprint mismatch")
    return identity


def _main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_parser = subparsers.add_parser("build-version")
    build_parser.add_argument("--run-number", required=True)
    build_parser.add_argument("--run-attempt", required=True)

    candidate_parser = subparsers.add_parser("candidate-set-id")
    candidate_parser.add_argument("--commit", required=True)
    candidate_parser.add_argument("--run-id", required=True)
    candidate_parser.add_argument("--run-attempt", required=True)
    candidate_parser.add_argument("--run-number", required=True)
    candidate_parser.add_argument("--version", required=True)
    candidate_parser.add_argument("--build", required=True)
    candidate_parser.add_argument("--main-bundle-id", required=True)
    candidate_parser.add_argument("--probe-bundle-id", required=True)

    args = parser.parse_args()
    try:
        if args.command == "build-version":
            result = derive_build_version(args.run_number, args.run_attempt)
        else:
            result = derive_candidate_set_id(
                commit=args.commit,
                run_id=args.run_id,
                run_attempt=args.run_attempt,
                run_number=args.run_number,
                version=args.version,
                build=args.build,
                main_bundle_id=args.main_bundle_id,
                probe_bundle_id=args.probe_bundle_id,
            )
    except CandidateIdentityError as error:
        raise SystemExit(str(error)) from error
    print(result)


if __name__ == "__main__":
    _main()
