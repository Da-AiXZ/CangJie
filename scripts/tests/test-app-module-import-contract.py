#!/usr/bin/env python3
"""Regression contract for Swift files that consume S1 preview Core symbols."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_SOURCE_ROOTS = (
    ROOT / "App" / "CangJieApp",
    ROOT / "App" / "Shared",
)
CORE_PREVIEW_SYMBOL = re.compile(
    r"\bS1Conversation(?:Preview|PreviewError|PreviewTurn|Speaker)\b"
)
CORE_IMPORT = re.compile(r"(?m)^import\s+CangJieCore\s*$")


class AppModuleImportContractTests(unittest.TestCase):
    def test_files_using_s1_preview_symbols_import_cangjie_core(self) -> None:
        missing_imports: list[str] = []

        source_paths = sorted(
            source_path
            for source_root in APP_SOURCE_ROOTS
            for source_path in source_root.rglob("*.swift")
        )
        for source_path in source_paths:
            source = source_path.read_text(encoding="utf-8")
            if CORE_PREVIEW_SYMBOL.search(source) and not CORE_IMPORT.search(source):
                missing_imports.append(source_path.relative_to(ROOT).as_posix())

        self.assertEqual(
            missing_imports,
            [],
            "Swift imports are file-scoped; files using S1 conversation preview "
            f"symbols must import CangJieCore: {missing_imports}",
        )


if __name__ == "__main__":
    unittest.main()
