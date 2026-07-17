#!/usr/bin/env python3
import os
import plistlib
import re
import stat
import sys
import tempfile
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    if len(sys.argv) != 5:
        fail(
            "Usage: stamp-build-identity.py "
            "<Info.plist> <12-char-commit> <numeric-build> <unstamped-build>"
        )

    plist_path = Path(sys.argv[1])
    expected_commit = sys.argv[2]
    expected_build = sys.argv[3]
    unstamped_build = sys.argv[4]

    if re.fullmatch(r"[0-9a-f]{12}", expected_commit) is None:
        fail(f"Invalid build commit identity: {expected_commit!r}")
    if re.fullmatch(r"[0-9]+", expected_build) is None:
        fail(f"Invalid numeric build identity: {expected_build!r}")
    if re.fullmatch(r"[0-9]+", unstamped_build) is None:
        fail(f"Invalid unstamped build identity: {unstamped_build!r}")
    if plist_path.is_symlink() or not plist_path.is_file():
        fail(f"Info.plist is missing or unsafe: {plist_path}")

    original_bytes = plist_path.read_bytes()
    try:
        decoded = plistlib.loads(original_bytes)
    except (ValueError, TypeError, plistlib.InvalidFileException) as error:
        fail(f"Invalid Info.plist: {error}")
    if not isinstance(decoded, dict):
        fail("Info.plist root must be a dictionary")

    actual_build = decoded.get("CFBundleVersion")
    permitted_unstamped_builds = {
        expected_build,
        unstamped_build,
        "$(CURRENT_PROJECT_VERSION)",
    }
    if actual_build not in permitted_unstamped_builds:
        fail(
            f"Refusing to replace unexpected CFBundleVersion: {actual_build!r}; "
            f"expected {expected_build!r} or baseline {unstamped_build!r}"
        )

    existing_commit = decoded.get("CangJieGitCommit")
    permitted_unstamped_values = {None, "local", "$(CANGJIE_GIT_COMMIT)", expected_commit}
    if existing_commit not in permitted_unstamped_values:
        fail(f"Refusing to replace unexpected CangJieGitCommit: {existing_commit!r}")

    stamped = dict(decoded)
    stamped["CangJieGitCommit"] = expected_commit
    stamped["CFBundleVersion"] = expected_build
    mode = stat.S_IMODE(plist_path.stat().st_mode)
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f".{plist_path.name}.",
            suffix=".tmp",
            dir=plist_path.parent,
            delete=False,
        ) as temporary:
            temporary_name = temporary.name
            plistlib.dump(stamped, temporary, fmt=plistlib.FMT_BINARY, sort_keys=True)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, plist_path)
        temporary_name = None
    finally:
        if temporary_name is not None:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass

    verified = plistlib.loads(plist_path.read_bytes())
    if verified.get("CangJieGitCommit") != expected_commit:
        fail("Stamped CangJieGitCommit did not persist")
    if verified.get("CFBundleVersion") != expected_build:
        fail("Stamped Info.plist changed CFBundleVersion")


if __name__ == "__main__":
    main()
