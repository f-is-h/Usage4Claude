#!/usr/bin/env python3
"""
Tests for check_l10n.py — the localization consistency gate (audit report,
七/7.2 LLM 协作效率). Covered risk: a missing/duplicate/stale key in any of
the 7 supported languages silently falls back to English (or renders blank)
at runtime, and nothing in a normal build would catch it.

Uses stdlib unittest (not pytest) so it runs with zero extra dependencies:
    python3 scripts/test_check_l10n.py -v
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

_SCRIPT_PATH = Path(__file__).parent / "check_l10n.py"
_spec = importlib.util.spec_from_file_location("check_l10n", _SCRIPT_PATH)
check_l10n = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check_l10n)

parse_strings = check_l10n.parse_strings
find_localization_files = check_l10n.find_localization_files
find_referenced_keys = check_l10n.find_referenced_keys
check_localizations = check_l10n.check_localizations


class ParseStringsTests(unittest.TestCase):

    def test_parses_simple_entries(self):
        entries, duplicates = parse_strings(
            '"menu.about" = "About";\n'
            '"menu.quit" = "Quit";\n'
        )
        self.assertEqual(entries, {"menu.about": "About", "menu.quit": "Quit"})
        self.assertEqual(duplicates, [])

    def test_skips_line_comments(self):
        entries, _ = parse_strings(
            "// MARK: - Menu Items\n"
            '"menu.about" = "About";\n'
        )
        self.assertEqual(entries, {"menu.about": "About"})

    def test_skips_single_line_block_comment(self):
        entries, _ = parse_strings(
            "/* single line block */\n"
            '"menu.about" = "About";\n'
        )
        self.assertEqual(entries, {"menu.about": "About"})

    def test_skips_multi_line_block_comment(self):
        entries, _ = parse_strings(
            "/*\n"
            "  Localizable.strings (English)\n"
            "  Usage4Claude\n"
            "*/\n"
            '"menu.about" = "About";\n'
        )
        self.assertEqual(entries, {"menu.about": "About"})

    def test_value_containing_double_slash_is_not_treated_as_comment(self):
        # Real example from en.lproj: a URL inside the value.
        entries, _ = parse_strings(
            '"weblogin.hint" = "starts with http://localhost";\n'
        )
        self.assertEqual(entries, {"weblogin.hint": "starts with http://localhost"})

    def test_detects_duplicate_key_in_same_file(self):
        entries, duplicates = parse_strings(
            '"welcome.skip" = "Skip";\n'
            '"welcome.finish" = "Finish";\n'
            '"welcome.skip" = "Skip";\n'
        )
        self.assertEqual(duplicates, ["welcome.skip"])
        # First occurrence wins for the returned value.
        self.assertEqual(entries["welcome.skip"], "Skip")

    def test_blank_lines_and_whitespace_are_ignored(self):
        entries, duplicates = parse_strings(
            "\n"
            "   \n"
            '"menu.about" = "About";\n'
            "\n"
        )
        self.assertEqual(entries, {"menu.about": "About"})
        self.assertEqual(duplicates, [])


class FindLocalizationFilesTests(unittest.TestCase):

    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        self.tmp_path = Path(tmpdir.name)
        self._orig_resources_dir = check_l10n.RESOURCES_DIR
        check_l10n.RESOURCES_DIR = self.tmp_path

    def tearDown(self):
        check_l10n.RESOURCES_DIR = self._orig_resources_dir

    def _make_lproj(self, lang, content):
        lproj_dir = self.tmp_path / f"{lang}.lproj"
        lproj_dir.mkdir(parents=True)
        (lproj_dir / "Localizable.strings").write_text(content)

    def test_discovers_all_lproj_directories(self):
        self._make_lproj("en", '"a" = "A";\n')
        self._make_lproj("de", '"a" = "A (de)";\n')
        files = find_localization_files()
        self.assertEqual(set(files.keys()), {"en", "de"})

    def test_ignores_lproj_without_localizable_strings(self):
        empty_dir = self.tmp_path / "fr.lproj"
        empty_dir.mkdir(parents=True)
        self._make_lproj("en", '"a" = "A";\n')
        files = find_localization_files()
        self.assertEqual(set(files.keys()), {"en"})


class FindReferencedKeysTests(unittest.TestCase):

    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        self.tmp_path = Path(tmpdir.name)
        self._orig_source_dir = check_l10n.SOURCE_DIR
        check_l10n.SOURCE_DIR = self.tmp_path

    def tearDown(self):
        check_l10n.SOURCE_DIR = self._orig_source_dir

    def _write_swift(self, name, content):
        (self.tmp_path / name).write_text(content)

    def test_extracts_localized_call_keys(self):
        self._write_swift(
            "LocalizationHelper.swift",
            'enum L {\n'
            '    static var about: String { localized("menu.about") }\n'
            '    static var quit: String { localized("menu.quit") }\n'
            '}\n'
        )
        self.assertEqual(find_referenced_keys(), {"menu.about", "menu.quit"})

    def test_ignores_unrelated_function_calls(self):
        self._write_swift(
            "Foo.swift",
            'let x = somethingElse("not.a.key")\n'
        )
        self.assertEqual(find_referenced_keys(), set())

    def test_scans_nested_directories(self):
        nested = self.tmp_path / "Views" / "Settings"
        nested.mkdir(parents=True)
        (nested / "View.swift").write_text('let t = localized("settings.title")\n')
        self.assertEqual(find_referenced_keys(), {"settings.title"})


class CheckLocalizationsTests(unittest.TestCase):

    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        self.tmp_path = Path(tmpdir.name)

    def _write_lang(self, lang, content):
        lproj_dir = self.tmp_path / f"{lang}.lproj"
        lproj_dir.mkdir(parents=True, exist_ok=True)
        path = lproj_dir / "Localizable.strings"
        path.write_text(content)
        return path

    def test_all_consistent_passes_with_no_errors_or_warnings(self):
        en = self._write_lang("en", '"a" = "A";\n"b" = "B";\n')
        de = self._write_lang("de", '"a" = "A(de)";\n"b" = "B(de)";\n')
        lang_files = {"en": en, "de": de}
        errors, warnings, key_count, lang_count = check_localizations(
            lang_files, referenced_keys={"a", "b"}
        )
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])
        self.assertEqual(key_count, 2)
        self.assertEqual(lang_count, 2)

    def test_missing_key_in_non_base_language_is_an_error(self):
        en = self._write_lang("en", '"a" = "A";\n"b" = "B";\n')
        de = self._write_lang("de", '"a" = "A(de)";\n')
        errors, _, _, _ = check_localizations({"en": en, "de": de}, referenced_keys=set())
        self.assertTrue(any('[de] missing key present in "en": "b"' in e for e in errors))

    def test_extra_key_in_non_base_language_is_an_error(self):
        en = self._write_lang("en", '"a" = "A";\n')
        de = self._write_lang("de", '"a" = "A(de)";\n"c" = "C(de)";\n')
        errors, _, _, _ = check_localizations({"en": en, "de": de}, referenced_keys=set())
        self.assertTrue(any('[de] extra key not present in "en": "c"' in e for e in errors))

    def test_duplicate_key_within_a_file_is_an_error(self):
        en = self._write_lang("en", '"a" = "A";\n"a" = "A again";\n')
        errors, _, _, _ = check_localizations({"en": en}, referenced_keys=set())
        self.assertTrue(any('[en] duplicate key defined more than once: "a"' in e for e in errors))

    def test_code_referencing_undefined_key_is_an_error(self):
        en = self._write_lang("en", '"a" = "A";\n')
        errors, _, _, _ = check_localizations({"en": en}, referenced_keys={"a", "missing.key"})
        self.assertTrue(
            any('[code] referenced via localized(...) but not defined in "en": "missing.key"' in e for e in errors)
        )

    def test_defined_but_unreferenced_key_is_only_a_warning(self):
        en = self._write_lang("en", '"a" = "A";\n"unused" = "Unused";\n')
        errors, warnings, _, _ = check_localizations({"en": en}, referenced_keys={"a"})
        self.assertEqual(errors, [])
        self.assertTrue(
            any('[code] defined in "en" but never referenced via localized(...): "unused"' in w for w in warnings)
        )

    def test_missing_base_language_is_an_error(self):
        de = self._write_lang("de", '"a" = "A(de)";\n')
        errors, _, key_count, _ = check_localizations({"de": de}, referenced_keys=set())
        self.assertTrue(any("base language 'en' not found" in e for e in errors))
        self.assertEqual(key_count, 0)


if __name__ == "__main__":
    unittest.main()
