#!/usr/bin/env python3
import argparse
import datetime
import json
import os
import re
import tempfile
from pathlib import Path

HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> None: raise SystemExit(message)

def load(path: Path):
    try: return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error: fail(f"invalid artifact metadata: {error}")

def atomic_write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as destination:
            destination.write(text); destination.flush(); os.fsync(destination.fileno())
        os.replace(temp, path)
    except BaseException:
        try: os.unlink(temp)
        except FileNotFoundError: pass
        raise


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--candidate-set-id", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--run-attempt", required=True)
    parser.add_argument("--run-number", required=True)
    parser.add_argument("--repository", default="unknown")
    parser.add_argument("--ref", default="unknown")
    parser.add_argument("--workflow", default="unknown")
    parser.add_argument("--reason", default="unspecified")
    parser.add_argument("--artifact", action="append", required=True)
    args=parser.parse_args()
    if not HEX64.fullmatch(args.candidate_set_id): fail("invalid candidate set ID")
    if not HEX40.fullmatch(args.commit): fail("invalid commit")
    for label,value in (("build",args.build),("run ID",args.run_id),("run attempt",args.run_attempt),("run number",args.run_number)):
        if not value.isdigit() or int(value)<1: fail(f"invalid {label}")
    if args.build != args.run_number: fail("build must equal run number")
    artifacts=[load(Path(path)) for path in args.artifact]
    roles={item.get("role") for item in artifacts if isinstance(item,dict)}
    if roles != {"main","keychainIsolationProbe"} or len(artifacts)!=2: fail("artifact roles mismatch")
    for item in artifacts:
        identity=item.get("compiledIdentity",{})
        if identity.get("candidateSetID") != args.candidate_set_id: fail("candidate set binding mismatch")
        if identity.get("commit") != args.commit: fail("commit binding mismatch")
        if identity.get("build") != args.build: fail("build binding mismatch")
    manifest={
        "schemaVersion":5,"candidateSetID":args.candidate_set_id,"commit":args.commit,"build":args.build,
        "runId":args.run_id,"runAttempt":args.run_attempt,"runNumber":args.run_number,
        "repository":args.repository,"ref":args.ref,"workflow":args.workflow,"reason":args.reason,
        "builtAtUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"artifacts":artifacts,
        "acceptance":{
            "status":"blocked-pending-trollstore-device-keychain-isolation-validation","failClosed":True,
            "requiredChecks":[
                "Install both exact SHA-256 IPA artifacts from this candidate set",
                "Prepare the isolation canary in CangJie",
                "Run the companion own-group control and forbidden-group entitlement check",
                "Require errSecMissingEntitlement for the explicit main-group query",
            ],
            "reason":"macOS CI can verify signing contracts but cannot prove TrollStore real-device Keychain isolation.",
        },
    }
    atomic_write(Path(args.output),json.dumps(manifest,ensure_ascii=False,indent=2,sort_keys=True)+"\n")

if __name__=="__main__": main()
