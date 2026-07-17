#!/usr/bin/env python3
import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from candidate_set_identity import (  # noqa: E402
    CandidateIdentityError,
    derive_build_version,
    derive_candidate_set_id,
)


class CandidateSetIdentityTests(unittest.TestCase):
    def test_build_version_is_unique_per_attempt(self):
        self.assertEqual(derive_build_version("28", "1"), "28001")
        self.assertEqual(derive_build_version("28", "2"), "28002")

    def test_attempt_must_fit_collision_free_suffix(self):
        for value in ("0", "1000", "-1", "01", "not-a-number"):
            with self.subTest(value=value), self.assertRaises(CandidateIdentityError):
                derive_build_version("28", value)

    def test_candidate_set_id_fixed_vector(self):
        self.assertEqual(
            derive_candidate_set_id(
                commit="b" * 40,
                run_id="123456",
                run_attempt="2",
                run_number="28",
                version="1.0",
                build="28002",
                main_bundle_id="com.juyang.CangJie",
                probe_bundle_id="com.juyang.CangJie.KeychainIsolationProbe",
            ),
            "9dee4bb2a55e2d8c554c63da911aab32cf26d2c60b5d5e53b022251d13c070b0",
        )

    def test_candidate_set_rejects_non_derived_build(self):
        with self.assertRaises(CandidateIdentityError):
            derive_candidate_set_id(
                commit="b" * 40,
                run_id="123456",
                run_attempt="2",
                run_number="28",
                version="1.0",
                build="28",
                main_bundle_id="com.juyang.CangJie",
                probe_bundle_id="com.juyang.CangJie.KeychainIsolationProbe",
            )

    def test_candidate_set_id_changes_with_marketing_version(self):
        common = {
            "commit": "b" * 40,
            "run_id": "123456",
            "run_attempt": "2",
            "run_number": "28",
            "build": "28002",
            "main_bundle_id": "com.juyang.CangJie",
            "probe_bundle_id": "com.juyang.CangJie.KeychainIsolationProbe",
        }
        self.assertNotEqual(
            derive_candidate_set_id(version="1.0", **common),
            derive_candidate_set_id(version="1.1", **common),
        )

    def test_candidate_set_rejects_noncanonical_marketing_version(self):
        for version in ("", "1", "1.0.0.0", "v1.0", "1.01-beta"):
            with self.subTest(version=version), self.assertRaises(CandidateIdentityError):
                derive_candidate_set_id(
                    commit="b" * 40,
                    run_id="123456",
                    run_attempt="2",
                    run_number="28",
                    version=version,
                    build="28002",
                    main_bundle_id="com.juyang.CangJie",
                    probe_bundle_id="com.juyang.CangJie.KeychainIsolationProbe",
                )


if __name__ == "__main__":
    unittest.main()
