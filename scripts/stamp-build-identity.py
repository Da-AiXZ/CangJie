#!/usr/bin/env python3
import argparse
import json
import os
import plistlib
import re
import stat
import sys
import tempfile
from pathlib import Path

HEX64 = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> None:
    raise SystemExit(message)


def atomic_dump(path: Path, value: dict, mode: int) -> None:
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(mode="wb", prefix=f".{path.name}.", suffix=".tmp", dir=path.parent, delete=False) as temporary:
            temporary_name = temporary.name
            plistlib.dump(value, temporary, fmt=plistlib.FMT_BINARY, sort_keys=True)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
        temporary_name = None
    finally:
        if temporary_name is not None:
            try: os.unlink(temporary_name)
            except FileNotFoundError: pass


def load_identity(path: Path) -> dict:
    try:
        identity = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"Invalid identity metadata: {error}")
    required = {"version", "build", "visibleCommit", "fingerprint", "candidateSetID"}
    if not isinstance(identity, dict) or not required.issubset(identity):
        fail("Identity metadata is incomplete")
    return identity


def stamp(plist_path: Path, version: str, build: str, commit: str, fingerprint: str, candidate_set_id: str, unstamped_build: str) -> None:
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", version): fail("Invalid marketing version")
    if not re.fullmatch(r"[0-9]+", build) or int(build) < 1: fail("Invalid numeric build identity")
    if not re.fullmatch(r"[0-9]+", unstamped_build): fail("Invalid unstamped build identity")
    if not re.fullmatch(r"[0-9a-f]{12}", commit): fail("Invalid build commit identity")
    if not HEX64.fullmatch(fingerprint): fail("Invalid executable fingerprint")
    if not HEX64.fullmatch(candidate_set_id): fail("Invalid candidate set identity")
    if plist_path.is_symlink() or not plist_path.is_file(): fail(f"Info.plist is missing or unsafe: {plist_path}")
    original = plist_path.read_bytes()
    try: decoded = plistlib.loads(original)
    except (ValueError, TypeError, plistlib.InvalidFileException) as error: fail(f"Invalid Info.plist: {error}")
    if not isinstance(decoded, dict): fail("Info.plist root must be a dictionary")

    permitted = {
        "CFBundleVersion": {build, unstamped_build, "$(CURRENT_PROJECT_VERSION)"},
        "CFBundleShortVersionString": {None, version, "0.0.1", "1.0", "$(MARKETING_VERSION)"},
        "CangJieGitCommit": {None, "local", "$(CANGJIE_GIT_COMMIT)", commit},
        "CangJieExecutableFingerprint": {None, "local", "$(CANGJIE_EXECUTABLE_FINGERPRINT)", fingerprint},
        "CangJieCandidateSetID": {None, "local", "$(CANGJIE_CANDIDATE_SET_ID)", candidate_set_id},
    }
    for key, allowed in permitted.items():
        if decoded.get(key) not in allowed:
            fail(f"Refusing to replace unexpected {key}: {decoded.get(key)!r}")
    stamped = dict(decoded)
    stamped.update({
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "CangJieGitCommit": commit,
        "CangJieExecutableFingerprint": fingerprint,
        "CangJieCandidateSetID": candidate_set_id,
    })
    atomic_dump(plist_path, stamped, stat.S_IMODE(plist_path.stat().st_mode))
    verified = plistlib.loads(plist_path.read_bytes())
    for key, expected in stamped.items():
        if verified.get(key) != expected: fail(f"Stamped {key} did not persist")


def main() -> None:
    if len(sys.argv) == 5 and not sys.argv[1].startswith("-"):
        # Backward-compatible schema-4 caller; deterministic placeholders are not used by candidate-set builds.
        plist_path, commit, build, unstamped = sys.argv[1:]
        stamp(Path(plist_path), "1.0", build, commit, "0" * 64, "0" * 64, unstamped)
        return
    parser = argparse.ArgumentParser()
    parser.add_argument("--identity-json", required=True)
    parser.add_argument("--unstamped-build", default="1")
    parser.add_argument("plist")
    args = parser.parse_args()
    identity = load_identity(Path(args.identity_json))
    stamp(
        Path(args.plist), identity["version"], identity["build"], identity["visibleCommit"],
        identity["fingerprint"], identity["candidateSetID"], args.unstamped_build,
    )


if __name__ == "__main__":
    main()
