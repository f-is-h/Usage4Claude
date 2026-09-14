#!/usr/bin/env python3
"""
Localization consistency checker (audit report 七/7.2 LLM 协作效率).

Verifies that every Usage4Claude/Resources/*.lproj/Localizable.strings file
defines the same set of keys as the English baseline, contains no duplicate
keys within a single file, and matches the keys actually referenced from
Swift source via localized("..."). A silent mismatch here means a language
falls back to English text (or a key referenced by code simply crashes/
renders blank) at runtime, with nothing in a normal build catching it.

    python3 scripts/check_l10n.py
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
RESOURCES_DIR = REPO_ROOT / "Usage4Claude" / "Resources"
SOURCE_DIR = REPO_ROOT / "Usage4Claude"
BASE_LANGUAGE = "en"

# Matches a single "key" = "value"; line. Both key and value may contain
# escaped characters (\" \\ etc.) but not an unescaped double quote.
_ENTRY_RE = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$')
_LOCALIZED_CALL_RE = re.compile(r'localized\(\s*"((?:\\.|[^"\\])*)"\s*\)')


def parse_strings(text):
    """Parse a .strings file's contents into (key -> value dict, duplicate keys).

    Comments are stripped on a whole-line basis (// line comments and /* */
    block comments), matching the style actually used in this project's
    .strings files. Values may themselves contain "//" (e.g. a URL) without
    being mistaken for a comment, since only known-comment lines are skipped.
    """
    entries = {}
    duplicates = []
    in_block_comment = False

    for line in text.splitlines():
        stripped = line.strip()

        if in_block_comment:
            if "*/" in stripped:
                in_block_comment = False
            continue

        if not stripped:
            continue
        if stripped.startswith("//"):
            continue
        if stripped.startswith("/*"):
            if "*/" not in stripped:
                in_block_comment = True
            continue

        match = _ENTRY_RE.match(line)
        if not match:
            continue

        key, value = match.group(1), match.group(2)
        if key in entries:
            duplicates.append(key)
        else:
            entries[key] = value

    return entries, duplicates


def find_localization_files():
    """Return {language_code: path_to_Localizable.strings}, discovered by glob."""
    files = {}
    for lproj_dir in sorted(RESOURCES_DIR.glob("*.lproj")):
        strings_file = lproj_dir / "Localizable.strings"
        if strings_file.exists():
            files[lproj_dir.stem] = strings_file
    return files


def find_referenced_keys():
    """Scan all Swift source for localized("...") calls, return the set of keys."""
    keys = set()
    for swift_file in SOURCE_DIR.rglob("*.swift"):
        text = swift_file.read_text(encoding="utf-8")
        keys.update(_LOCALIZED_CALL_RE.findall(text))
    return keys


def check_localizations(lang_files, referenced_keys):
    """Run all checks. Returns (errors, warnings, base_key_count, lang_count)."""
    errors = []
    warnings = []

    if BASE_LANGUAGE not in lang_files:
        errors.append(f"base language '{BASE_LANGUAGE}' not found under {RESOURCES_DIR}")
        return errors, warnings, 0, len(lang_files)

    parsed = {}
    for lang, path in lang_files.items():
        entries, duplicates = parse_strings(path.read_text(encoding="utf-8"))
        parsed[lang] = entries
        for key in duplicates:
            errors.append(f'[{lang}] duplicate key defined more than once: "{key}"')

    base_keys = set(parsed[BASE_LANGUAGE].keys())
    for lang, entries in sorted(parsed.items()):
        if lang == BASE_LANGUAGE:
            continue
        lang_keys = set(entries.keys())
        for key in sorted(base_keys - lang_keys):
            errors.append(f'[{lang}] missing key present in "{BASE_LANGUAGE}": "{key}"')
        for key in sorted(lang_keys - base_keys):
            errors.append(f'[{lang}] extra key not present in "{BASE_LANGUAGE}": "{key}"')

    undefined = sorted(referenced_keys - base_keys)
    unreferenced = sorted(base_keys - referenced_keys)
    for key in undefined:
        errors.append(f'[code] referenced via localized(...) but not defined in "{BASE_LANGUAGE}": "{key}"')
    for key in unreferenced:
        warnings.append(f'[code] defined in "{BASE_LANGUAGE}" but never referenced via localized(...): "{key}"')

    return errors, warnings, len(base_keys), len(lang_files)


def main():
    lang_files = find_localization_files()
    referenced_keys = find_referenced_keys()
    errors, warnings, key_count, lang_count = check_localizations(lang_files, referenced_keys)

    if errors:
        print(f"Localization check FAILED ({len(errors)} error(s)):")
        for error in errors:
            print(f"  error: {error}")

    if warnings:
        print(f"\n{len(warnings)} warning(s) (does not fail the check):")
        for warning in warnings:
            print(f"  warning: {warning}")

    if not errors:
        print(f"Localization check passed: {lang_count} languages, {key_count} keys each.")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
