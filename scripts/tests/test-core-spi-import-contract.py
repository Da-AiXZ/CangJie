#!/usr/bin/env python3
"""Regression contract for privileged CangJieCore SPI imports in app code."""

from __future__ import annotations

import re
import tempfile
import unittest
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEST_TARGET_TYPES = frozenset({"bundle.unit-test", "bundle.ui-testing"})
SWIFT_IDENTIFIER = r"[A-Za-z_][A-Za-z0-9_]*"
SPI_ATTRIBUTE_TOKEN = rf"@_spi[ \t]*\([ \t]*{SWIFT_IDENTIFIER}[ \t]*\)"
SPI_IMPORT_LINE = re.compile(
    rf"^[ \t]*(?P<attributes>{SPI_ATTRIBUTE_TOKEN}"
    rf"(?:[ \t]+{SPI_ATTRIBUTE_TOKEN})*)"
    r"[ \t]+import[ \t]+CangJieCore[ \t]*$"
)
PLAIN_CORE_IMPORT_LINE = re.compile(r"^[ \t]*import[ \t]+CangJieCore[ \t]*$")
TESTABLE_CORE_IMPORT_LINE = re.compile(
    r"^[ \t]*@testable[ \t]+import[ \t]+CangJieCore[ \t]*$")
TESTABLE_CORE_IMPORT_BLOCK = re.compile(
    r"(?P<attribute>@testable[ \t\r\n]+)"
    r"(?P<core_import>import[ \t\r\n]+CangJieCore\b)")
CORE_IMPORT_REFERENCE = re.compile(r"\bimport\b.*\bCangJieCore\b")
PRIVILEGED_CORE_IMPORT_BLOCK = re.compile(
    r"(?P<attributes>(?:@_spi[ \t\r\n]*\([^)]*\)[ \t\r\n]*)+)"
    r"(?P<core_import>import[ \t\r\n]+CangJieCore\b)"
)
SPI_NAME = re.compile(
    rf"@_spi[ \t]*\([ \t]*(?P<name>{SWIFT_IDENTIFIER})[ \t]*\)")
EXPECTED_SPI_IMPORTS = {
    "App/CangJieApp/ModelCredentialRepository.swift": frozenset({"ModelCredentialVerification"}),
    "App/CangJieApp/ModelDiscoveryAttempt.swift": frozenset({"ModelDiscoveryCredentialBinding"}),
    "App/CangJieApp/ModelDiscoveryNetworkClient.swift": frozenset({"ModelDiscoveryTransport"}),
}

@dataclass(frozen=True)
class CoreSPIImport:
    relative_path: str
    line_number: int
    spi_names: frozenset[str]

@dataclass(frozen=True)
class CoreSPIImportScan:
    imports: tuple[CoreSPIImport, ...]
    errors: tuple[str, ...]

@dataclass(frozen=True)
class ProductionSourceRootScan:
    roots: tuple[Path, ...]
    errors: tuple[str, ...]


def _yaml_scalar(raw_value: str) -> str:
    value_characters: list[str] = []
    quote: str | None = None
    escaped = False
    for index, character in enumerate(raw_value):
        if escaped:
            value_characters.append(character)
            escaped = False
            continue
        if quote == '"' and character == "\\":
            value_characters.append(character)
            escaped = True
            continue
        if character in {"'", '"'}:
            if quote is None:
                quote = character
            elif quote == character:
                quote = None
            value_characters.append(character)
            continue
        if (
            character == "#"
            and quote is None
            and (index == 0 or raw_value[index - 1].isspace())
        ):
            break
        value_characters.append(character)

    value = "".join(value_characters).strip()
    if (
        len(value) >= 2
        and value[0] == value[-1]
        and value[0] in {"'", '"'}
    ):
        return value[1:-1]
    return value

def scan_production_source_roots(
    repository_root: Path,
) -> ProductionSourceRootScan:
    project_path = repository_root / "project.yml"
    if not project_path.is_file():
        return ProductionSourceRootScan(roots=(), errors=())

    targets: dict[str, dict[str, object]] = {}
    current_target: str | None = None
    in_targets = False
    in_sources = False

    for raw_line in project_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indentation = len(line) - len(line.lstrip(" "))

        if indentation == 0:
            in_targets = stripped == "targets:"
            current_target = None
            in_sources = False
            continue
        if not in_targets:
            continue

        target_match = (
            re.fullmatch(r"  ([^:#]+):", line)
            if indentation == 2
            else None
        )
        if target_match is not None:
            current_target = target_match.group(1).strip()
            targets[current_target] = {
                "type": None,
                "sources": [],
                "source_errors": [],
            }
            in_sources = False
            continue
        if current_target is None:
            continue
        if indentation == 4 and stripped.startswith("type:"):
            targets[current_target]["type"] = _yaml_scalar(
                stripped.partition(":")[2]
            )
            in_sources = False
            continue
        if indentation == 4:
            in_sources = stripped == "sources:"
            continue
        if not in_sources or indentation != 6 or not stripped.startswith("-"):
            continue

        source_match = re.fullmatch(r"-\s+path\s*:\s*(.*)", stripped)
        if source_match is not None:
            source_value = _yaml_scalar(source_match.group(1))
        else:
            bare_source_match = re.fullmatch(r"-\s+(.+)", stripped)
            if bare_source_match is None or ":" in bare_source_match.group(1):
                source_errors = targets[current_target]["source_errors"]
                assert isinstance(source_errors, list)
                source_errors.append(
                    f"project.yml target '{current_target}' has an unrecognized "
                    f"production source entry: {stripped}"
                )
                continue
            source_value = _yaml_scalar(bare_source_match.group(1))
        if not source_value:
            source_errors = targets[current_target]["source_errors"]
            assert isinstance(source_errors, list)
            source_errors.append(
                f"project.yml target '{current_target}' has an empty production "
                "source root"
            )
            continue
        sources = targets[current_target]["sources"]
        assert isinstance(sources, list)
        sources.append(source_value)

    resolved_repository_root = repository_root.resolve()
    source_roots: set[Path] = set()
    errors: list[str] = []
    for target_name, target in targets.items():
        if target["type"] in TEST_TARGET_TYPES:
            continue
        source_errors = target["source_errors"]
        assert isinstance(source_errors, list)
        errors.extend(source_errors)
        sources = target["sources"]
        assert isinstance(sources, list)
        for source in sources:
            source_root = (repository_root / source).resolve()
            try:
                source_root.relative_to(resolved_repository_root)
            except ValueError:
                errors.append(
                    f"project.yml production source root '{source}' for target "
                    f"'{target_name}' resolves outside the repository"
                )
                continue
            if not source_root.exists():
                errors.append(
                    f"project.yml production source root '{source}' for target "
                    f"'{target_name}' does not exist"
                )
                continue
            source_roots.add(source_root)

    return ProductionSourceRootScan(
        roots=tuple(sorted(source_roots)), errors=tuple(errors))


def production_app_source_roots(repository_root: Path) -> tuple[Path, ...]:
    return scan_production_source_roots(repository_root).roots


def production_app_swift_sources(repository_root: Path) -> tuple[Path, ...]:
    sources: set[Path] = set()
    for source_root in production_app_source_roots(repository_root):
        if source_root.is_file() and source_root.suffix == ".swift":
            sources.add(source_root)
        elif source_root.is_dir():
            sources.update(source_root.rglob("*.swift"))
    return tuple(sorted(sources))


def _swift_code_lines(source: str) -> tuple[str, ...]:
    """Mask comments and string literals while preserving physical lines."""

    code_lines: list[str] = []
    block_comment_depth = 0
    multiline_string_hashes: int | None = None

    for raw_line in source.splitlines():
        code: list[str] = []
        index = 0
        while index < len(raw_line):
            if multiline_string_hashes is not None:
                delimiter = '"""' + ("#" * multiline_string_hashes)
                closing_index = raw_line.find(delimiter, index)
                if closing_index < 0:
                    index = len(raw_line)
                    continue
                code.append(" ")
                index = closing_index + len(delimiter)
                multiline_string_hashes = None
                continue

            if block_comment_depth > 0:
                if raw_line.startswith("/*", index):
                    block_comment_depth += 1
                    index += 2
                elif raw_line.startswith("*/", index):
                    block_comment_depth -= 1
                    code.append(" ")
                    index += 2
                else:
                    index += 1
                continue

            if raw_line.startswith("//", index):
                break
            if raw_line.startswith("/*", index):
                block_comment_depth = 1
                code.append(" ")
                index += 2
                continue

            multiline_start = re.match(r"(?P<hashes>#+)?\"\"\"", raw_line[index:])
            if multiline_start is not None:
                multiline_string_hashes = len(multiline_start.group("hashes") or "")
                code.append(" ")
                index += len(multiline_start.group(0))
                continue

            string_start = re.match(r"(?P<hashes>#+)?\"", raw_line[index:])
            if string_start is not None:
                hash_count = len(string_start.group("hashes") or "")
                delimiter = '"' + ("#" * hash_count)
                index += len(string_start.group(0))
                while index < len(raw_line):
                    if hash_count == 0 and raw_line[index] == "\\":
                        index += 2
                        continue
                    if raw_line.startswith(delimiter, index):
                        index += len(delimiter)
                        break
                    index += 1
                code.append(" ")
                continue

            code.append(raw_line[index])
            index += 1

        code_lines.append("".join(code))

    return tuple(code_lines)


def scan_core_spi_imports(source: str, relative_path: str) -> CoreSPIImportScan:
    imports: list[CoreSPIImport] = []
    errors: list[str] = []
    code_lines = _swift_code_lines(source)
    code_source = "\n".join(code_lines)

    for block_match in PRIVILEGED_CORE_IMPORT_BLOCK.finditer(code_source):
        if "\n" not in block_match.group(0) and "\r" not in block_match.group(0):
            continue
        line_number = code_source.count(
            "\n",
            0,
            block_match.start("core_import"),
        ) + 1
        errors.append(
            f"{relative_path}:{line_number}: every @_spi attribute and "
            "the CangJieCore import must share the same physical line"
        )

    for block_match in TESTABLE_CORE_IMPORT_BLOCK.finditer(code_source):
        if "\n" not in block_match.group(0) and "\r" not in block_match.group(0):
            continue
        line_number = code_source.count(
            "\n",
            0,
            block_match.start("core_import"),
        ) + 1
        errors.append(
            f"{relative_path}:{line_number}: @testable and the CangJieCore "
            "import must share the same physical line; production sources "
            "must not use @testable import CangJieCore"
        )

    for line_number, code_line in enumerate(code_lines, start=1):
        if not code_line.strip():
            continue

        import_match = SPI_IMPORT_LINE.fullmatch(code_line)
        if import_match is not None:
            names = tuple(
                match.group("name")
                for match in SPI_NAME.finditer(import_match.group("attributes"))
            )
            if len(names) != len(set(names)):
                errors.append(
                    f"{relative_path}:{line_number}: duplicate @_spi attributes "
                    "are not allowed"
                )
            imports.append(
                CoreSPIImport(
                    relative_path=relative_path,
                    line_number=line_number,
                    spi_names=frozenset(names),
                )
            )
            continue

        if PLAIN_CORE_IMPORT_LINE.fullmatch(code_line) is not None:
            continue

        if TESTABLE_CORE_IMPORT_LINE.fullmatch(code_line) is not None:
            errors.append(
                f"{relative_path}:{line_number}: production sources must not "
                "use @testable import CangJieCore"
            )
            continue

        if (
            "@_spi" in code_line or "@testable" in code_line
        ) and CORE_IMPORT_REFERENCE.search(code_line):
            errors.append(
                f"{relative_path}:{line_number}: malformed privileged "
                "CangJieCore import"
            )

    return CoreSPIImportScan(imports=tuple(imports), errors=tuple(errors))


def _format_spi_names(spi_names: frozenset[str]) -> str:
    return ", ".join(sorted(spi_names))


def validate_core_spi_import_contract(
    repository_root: Path,
    allowlist: Mapping[str, frozenset[str]],
) -> tuple[str, ...]:
    errors: list[str] = []
    imports_by_path: dict[str, list[CoreSPIImport]] = {}

    if not (repository_root / "project.yml").is_file():
        return ("missing XcodeGen target manifest: project.yml",)
    source_root_scan = scan_production_source_roots(repository_root)
    errors.extend(source_root_scan.errors)
    if not source_root_scan.roots:
        errors.append("project.yml defines no valid production source roots")
        return tuple(errors)

    source_paths: set[Path] = set()
    for source_root in source_root_scan.roots:
        if source_root.is_file() and source_root.suffix == ".swift":
            source_paths.add(source_root)
        elif source_root.is_dir():
            source_paths.update(source_root.rglob("*.swift"))

    for source_path in sorted(source_paths):
        relative_path = source_path.relative_to(repository_root).as_posix()
        scan = scan_core_spi_imports(
            source_path.read_text(encoding="utf-8"),
            relative_path,
        )
        errors.extend(scan.errors)
        if scan.imports:
            imports_by_path[relative_path] = list(scan.imports)

    for relative_path, core_imports in sorted(imports_by_path.items()):
        expected_names = allowlist.get(relative_path)
        if expected_names is None:
            for core_import in core_imports:
                errors.append(
                    f"{relative_path}:{core_import.line_number}: unexpected "
                    "privileged CangJieCore import "
                    f"[{_format_spi_names(core_import.spi_names)}]"
                )
            continue

        exact_matches = 0
        for core_import in core_imports:
            if core_import.spi_names == expected_names:
                exact_matches += 1
                continue
            errors.append(
                f"{relative_path}:{core_import.line_number}: privileged "
                "CangJieCore import must be exactly "
                f"[{_format_spi_names(expected_names)}], found "
                f"[{_format_spi_names(core_import.spi_names)}]"
            )
        if exact_matches > 1:
            errors.append(
                f"{relative_path}: duplicate allowlisted privileged "
                "CangJieCore imports"
            )

    for relative_path, expected_names in sorted(allowlist.items()):
        exact_matches = sum(
            core_import.spi_names == expected_names
            for core_import in imports_by_path.get(relative_path, ())
        )
        if exact_matches == 0:
            errors.append(
                f"{relative_path}: missing allowlisted privileged "
                f"CangJieCore import [{_format_spi_names(expected_names)}]"
            )

    return tuple(errors)


class CoreSPIImportFixtureTests(unittest.TestCase):
    @staticmethod
    def write_project(
        repository_root: Path,
        production_paths: tuple[str, ...],
        test_paths: tuple[str, ...] = (),
    ) -> None:
        lines = ["targets:"]
        for index, source_path in enumerate(production_paths):
            lines.extend(
                (
                    f"  Production{index}:",
                    "    type: application",
                    "    sources:",
                    f"      - path: {source_path}",
                )
            )
        for index, source_path in enumerate(test_paths):
            lines.extend(
                (
                    f"  Tests{index}:",
                    "    type: bundle.unit-test",
                    "    sources:",
                    f"      - path: {source_path}",
                )
            )
        (repository_root / "project.yml").write_text(
            "\n".join(lines) + "\n",
            encoding="utf-8",
        )

    def test_discovers_every_production_app_target_and_excludes_tests(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            included = {
                "App/CangJieApp/Main.swift",
                "App/CangJieApp/SecurityTests/Bypass.swift",
                "App/CangJieIsolationProbe/Probe.swift",
                "App/Shared/Shared.swift",
            }
            excluded = {
                "App/CangJieAppTests/MainTests.swift",
                "App/CangJieUITests/MainUITests.swift",
                "App/CangJieIsolationProbeTests/ProbeTests.swift",
                "App/CangJieIsolationProbeUITests/ProbeUITests.swift",
                "App/UnlistedProductionLookingDirectory/Worker.swift",
            }
            for relative_path in included | excluded:
                source_path = repository_root / relative_path
                source_path.parent.mkdir(parents=True, exist_ok=True)
                source_path.write_text("import Foundation\n", encoding="utf-8")
            (repository_root / "project.yml").write_text(
                """targets:
  CangJie:
    type: application
    sources:
      - path: App/CangJieApp
      - path: App/Shared
  CangJieAppTests:
    type: bundle.unit-test
    sources:
      - path: App/CangJieAppTests
  CangJieUITests:
    type: bundle.ui-testing
    sources:
      - path: App/CangJieUITests
  CangJieKeychainIsolationProbe:
    type: application
    sources:
      - path: App/CangJieIsolationProbe
      - path: App/Shared
  CangJieIsolationProbeTests:
    type: bundle.unit-test
    sources:
      - path: App/CangJieIsolationProbeTests
  CangJieIsolationProbeUITests:
    type: bundle.ui-testing
    sources:
      - path: App/CangJieIsolationProbeUITests
""",
                encoding="utf-8",
            )

            actual = {
                source_path.relative_to(repository_root).as_posix()
                for source_path in production_app_swift_sources(repository_root)
            }

            self.assertEqual(actual, included)

    def test_scans_non_app_production_roots_and_excludes_actual_test_targets(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            app_source = repository_root / "App/Main/Main.swift"
            adapter_source = repository_root / "Sources/Adapter/Adapter.swift"
            test_source = repository_root / "Sources/AdapterTests/AdapterTests.swift"
            for source_path in (app_source, adapter_source, test_source):
                source_path.parent.mkdir(parents=True, exist_ok=True)
            app_source.write_text("import Foundation\n", encoding="utf-8")
            adapter_source.write_text(
                "@_spi(UnauthorizedSPI) import CangJieCore\n",
                encoding="utf-8",
            )
            test_source.write_text(
                "@_spi(TestOnlySPI) import CangJieCore\n",
                encoding="utf-8",
            )
            self.write_project(
                repository_root,
                ("App/Main", "Sources/Adapter"),
                ("Sources/AdapterTests",),
            )

            actual = {
                source_path.relative_to(repository_root).as_posix()
                for source_path in production_app_swift_sources(repository_root)
            }
            errors = validate_core_spi_import_contract(repository_root, {})

            self.assertEqual(
                actual,
                {
                    "App/Main/Main.swift",
                    "Sources/Adapter/Adapter.swift",
                },
            )
            self.assertTrue(
                any("Sources/Adapter/Adapter.swift" in error for error in errors),
                errors,
            )
            self.assertFalse(any("TestOnlySPI" in error for error in errors), errors)

    def test_rejects_production_source_root_outside_repository(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temporary_root = Path(directory)
            repository_root = temporary_root / "Repository"
            app_source = repository_root / "App/Main/Main.swift"
            outside_source = temporary_root / "OutsideAdapter/Outside.swift"
            app_source.parent.mkdir(parents=True, exist_ok=True)
            outside_source.parent.mkdir(parents=True, exist_ok=True)
            app_source.write_text("import Foundation\n", encoding="utf-8")
            outside_source.write_text("import Foundation\n", encoding="utf-8")
            self.write_project(
                repository_root,
                ("App/Main", "../OutsideAdapter"),
            )

            errors = validate_core_spi_import_contract(repository_root, {})

            self.assertTrue(
                any(
                    "../OutsideAdapter" in error
                    and "outside the repository" in error
                    for error in errors
                ),
                errors,
            )

    def test_rejects_missing_declared_production_source_root(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            app_source = repository_root / "App/Main/Main.swift"
            app_source.parent.mkdir(parents=True, exist_ok=True)
            app_source.write_text("import Foundation\n", encoding="utf-8")
            self.write_project(
                repository_root,
                ("App/Main", "Sources/MissingAdapter"),
            )

            errors = validate_core_spi_import_contract(repository_root, {})

            self.assertTrue(
                any(
                    "Sources/MissingAdapter" in error
                    and "does not exist" in error
                    for error in errors
                ),
                errors,
            )

    def test_parses_one_or_multiple_spi_attributes_on_the_same_import_line(self) -> None:
        result = scan_core_spi_imports(
            "\n".join(
                (
                    "@_spi(FirstSPI) import CangJieCore",
                    "@_spi(SecondSPI)   @_spi(ThirdSPI)\timport CangJieCore",
                    "import CangJieCore",
                )
            ),
            "App/OtherProductionTarget/Adapter.swift",
        )

        self.assertEqual(result.errors, ())
        self.assertEqual(
            tuple(core_import.spi_names for core_import in result.imports),
            (frozenset({"FirstSPI"}), frozenset({"SecondSPI", "ThirdSPI"})),
        )

    def test_rejects_spi_attributes_split_across_physical_lines(self) -> None:
        for source in (
            "@_spi(FirstSPI)\nimport CangJieCore\n",
            "@_spi(\n    FirstSPI\n)\nimport CangJieCore\n",
        ):
            with self.subTest(source=source):
                result = scan_core_spi_imports(
                    source,
                    "App/OtherProductionTarget/Adapter.swift",
                )

                self.assertEqual(result.imports, ())
                self.assertEqual(len(result.errors), 1)
                self.assertIn("same physical line", result.errors[0])

    def test_minimal_allowlist_rejects_extra_spi_or_importer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            allowed_path = repository_root / "App/Main/AllowedAdapter.swift"
            allowed_path.parent.mkdir(parents=True, exist_ok=True)
            allowed_path.write_text(
                "@_spi(AllowedSPI) @_spi(ExtraSPI) import CangJieCore\n",
                encoding="utf-8",
            )
            unexpected_path = repository_root / "App/Probe/UnexpectedAdapter.swift"
            unexpected_path.parent.mkdir(parents=True, exist_ok=True)
            unexpected_path.write_text(
                "@_spi(AllowedSPI) import CangJieCore\n",
                encoding="utf-8",
            )
            ignored_test_path = repository_root / "App/MainTests/TestFixture.swift"
            ignored_test_path.parent.mkdir(parents=True, exist_ok=True)
            ignored_test_path.write_text(
                "@_spi(TestOnlySPI) import CangJieCore\n",
                encoding="utf-8",
            )
            self.write_project(
                repository_root,
                ("App/Main", "App/Probe"),
                ("App/MainTests",),
            )

            errors = validate_core_spi_import_contract(
                repository_root,
                {"App/Main/AllowedAdapter.swift": frozenset({"AllowedSPI"})},
            )

            self.assertTrue(any("ExtraSPI" in error for error in errors), errors)
            self.assertTrue(
                any("App/Probe/UnexpectedAdapter.swift" in error for error in errors),
                errors,
            )
            self.assertFalse(any("TestOnlySPI" in error for error in errors), errors)

    def test_exact_multi_spi_fixture_passes_and_ignores_non_code_examples(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            allowed_path = repository_root / "App/Probe/AllowedAdapter.swift"
            allowed_path.parent.mkdir(parents=True, exist_ok=True)
            allowed_path.write_text(
                "@_spi(FirstSPI) /* reviewed */ @_spi(SecondSPI) "
                "import CangJieCore\n",
                encoding="utf-8",
            )
            examples_path = repository_root / "App/Main/Examples.swift"
            examples_path.parent.mkdir(parents=True, exist_ok=True)
            examples_path.write_text(
                """// @_spi(CommentSPI) import CangJieCore
/* @_spi(BlockCommentSPI) import CangJieCore */
let example = \"\"\"
@_spi(StringSPI) import CangJieCore
\"\"\"
""",
                encoding="utf-8",
            )
            self.write_project(repository_root, ("App/Probe", "App/Main"))

            errors = validate_core_spi_import_contract(
                repository_root,
                {
                    "App/Probe/AllowedAdapter.swift": frozenset(
                        {"FirstSPI", "SecondSPI"}
                    )
                },
            )

            self.assertEqual(errors, ())

    def test_minimal_allowlist_rejects_a_missing_import(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            source_path = repository_root / "App/Main/AllowedAdapter.swift"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text("import CangJieCore\n", encoding="utf-8")
            self.write_project(repository_root, ("App/Main",))

            errors = validate_core_spi_import_contract(
                repository_root,
                {"App/Main/AllowedAdapter.swift": frozenset({"AllowedSPI"})},
            )

            self.assertTrue(any("missing" in error.lower() for error in errors), errors)

    def test_production_testable_core_import_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repository_root = Path(directory)
            source_path = repository_root / "App/Main/Bypass.swift"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(
                "@testable import CangJieCore\n",
                encoding="utf-8",
            )
            self.write_project(repository_root, ("App/Main",))

            errors = validate_core_spi_import_contract(repository_root, {})

            self.assertTrue(
                any("@testable" in error for error in errors),
                errors,
            )

    def test_split_line_testable_core_import_is_rejected(self) -> None:
        result = scan_core_spi_imports(
            "@testable\nimport CangJieCore\n",
            "Sources/Adapter/Bypass.swift",
        )

        self.assertEqual(result.imports, ())
        self.assertEqual(len(result.errors), 1)
        self.assertIn("@testable", result.errors[0])
        self.assertIn("same physical line", result.errors[0])


class CoreSPIImportContractTests(unittest.TestCase):
    def test_privileged_core_spi_imports_are_scoped_to_their_adapters(self) -> None:
        errors = validate_core_spi_import_contract(ROOT, EXPECTED_SPI_IMPORTS)

        self.assertEqual(
            errors,
            (),
            "Privileged CangJieCore imports must match the minimal production "
            "allowlist exactly:\n" + "\n".join(errors),
        )


if __name__ == "__main__":
    unittest.main()
