#!/usr/bin/env python3
"""
Tests for update_appcast.py — the release pipeline step that stitches a new
<item> into appcast.xml. Covered risk (audit report, 六/测试覆盖): a broken
regex or marker match here silently corrupts the Sparkle feed, and nothing
in the release workflow would notice until users stop getting update prompts.

Uses stdlib unittest (not pytest) so it runs with zero extra dependencies:
    python3 .github/scripts/test_update_appcast.py -v
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

_SCRIPT_PATH = Path(__file__).parent / "update_appcast.py"
_spec = importlib.util.spec_from_file_location("update_appcast", _SCRIPT_PATH)
update_appcast_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(update_appcast_module)

extract_release_notes_section = update_appcast_module.extract_release_notes_section
update_appcast = update_appcast_module.update_appcast


class ExtractReleaseNotesSectionTests(unittest.TestCase):

    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        self.tmp_path = Path(tmpdir.name)

    def _write_notes(self, content: str) -> str:
        path = self.tmp_path / "RELEASE_NOTES.md"
        path.write_text(content)
        return str(path)

    def test_extracts_section_between_two_headings(self):
        notes = self._write_notes(
            "# Release Notes\n\n"
            "## [3.3.0] - 2026-07-13\n"
            "- Added German localization\n"
            "- Fixed a bug\n\n"
            "## [3.2.2] - 2026-06-01\n"
            "- Older release\n"
        )
        result = extract_release_notes_section(notes, "3.3.0")
        self.assertEqual(result, "- Added German localization\n- Fixed a bug")

    def test_extracts_last_section_to_end_of_file(self):
        notes = self._write_notes(
            "## [1.0.0] - 2026-01-01\n"
            "- Older\n\n"
            "## [2.0.0] - 2026-02-01\n"
            "- Latest and only entry\n"
        )
        result = extract_release_notes_section(notes, "2.0.0")
        self.assertEqual(result, "- Latest and only entry")

    def test_returns_empty_string_when_version_not_found(self):
        notes = self._write_notes("## [1.0.0] - 2026-01-01\n- Something\n")
        self.assertEqual(extract_release_notes_section(notes, "9.9.9"), "")

    def test_version_dot_is_escaped_not_treated_as_regex_wildcard(self):
        # 若 "." 没被 re.escape 转义，会被当成"任意字符"通配符，
        # 导致 "1x2x3" 这类版本号被误判匹配 "1.2.3" 对应的 heading
        notes = self._write_notes(
            "## [1x2x3] - 2026-01-01\n"
            "- Should not match version 1.2.3\n"
        )
        self.assertEqual(extract_release_notes_section(notes, "1.2.3"), "")

    def test_strips_surrounding_whitespace(self):
        notes = self._write_notes(
            "## [1.0.0] - 2026-01-01\n"
            "\n\n  - Padded entry  \n\n\n"
            "## [0.9.0] - 2025-12-01\n"
            "- Older\n"
        )
        self.assertEqual(extract_release_notes_section(notes, "1.0.0"), "- Padded entry")


class UpdateAppcastTests(unittest.TestCase):

    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        self.tmp_path = Path(tmpdir.name)

        self.appcast_path = self.tmp_path / "appcast.xml"
        self.appcast_path.write_text(
            "<?xml version=\"1.0\"?>\n<rss><channel>\n"
            "<!-- Items go here. Top item is the latest version. -->\n"
            "</channel></rss>\n"
        )
        self.notes_path = self.tmp_path / "RELEASE_NOTES.md"
        self.notes_path.write_text("## [3.3.0] - 2026-07-13\n- New feature\n")
        self.enclosure_path = self.tmp_path / "enclosure.txt"
        self.enclosure_path.write_text(
            '<enclosure url="https://example.com/app.dmg" length="123" '
            'type="application/octet-stream" sparkle:edSignature="sig=="/>'
        )

    def _run_update(self, **overrides):
        kwargs = dict(
            appcast_path=str(self.appcast_path),
            version="3.3.0",
            build="42",
            pub_date="Mon, 13 Jul 2026 00:00:00 +0000",
            dmg_url="https://example.com/app.dmg",
            release_url="https://example.com/v3.3.0",
            notes_path=str(self.notes_path),
            enclosure_path=str(self.enclosure_path),
        )
        kwargs.update(overrides)
        update_appcast(**kwargs)

    def test_inserts_new_item_after_marker(self):
        self._run_update()
        content = self.appcast_path.read_text()

        self.assertIn(
            "<!-- Items go here. Top item is the latest version. -->", content,
            "marker must survive so the next release can insert above the same anchor"
        )
        self.assertIn("<title>v3.3.0</title>", content)
        self.assertIn("<sparkle:version>42</sparkle:version>", content)
        self.assertIn("<sparkle:shortVersionString>3.3.0</sparkle:shortVersionString>", content)
        self.assertIn("- New feature", content)
        self.assertIn('url="https://example.com/app.dmg"', content)

    def test_new_item_appears_directly_after_marker(self):
        self._run_update()
        content = self.appcast_path.read_text()
        marker = "<!-- Items go here. Top item is the latest version. -->"
        self.assertLess(content.index(marker), content.index("<title>v3.3.0</title>"))

    def test_second_release_stays_topmost_above_first(self):
        self._run_update()

        notes_v2 = self.tmp_path / "RELEASE_NOTES_v2.md"
        notes_v2.write_text("## [3.4.0] - 2026-08-01\n- Even newer feature\n")
        self._run_update(
            version="3.4.0",
            build="43",
            pub_date="Sat, 01 Aug 2026 00:00:00 +0000",
            dmg_url="https://example.com/b.dmg",
            release_url="https://example.com/v3.4.0",
            notes_path=str(notes_v2),
        )

        content = self.appcast_path.read_text()
        self.assertLess(
            content.index("<title>v3.4.0</title>"),
            content.index("<title>v3.3.0</title>"),
            "newest release must sit above the previous one (right after the marker each time)"
        )

    def test_exits_nonzero_when_marker_missing(self):
        broken = self.tmp_path / "broken_appcast.xml"
        broken.write_text("<rss><channel></channel></rss>")

        with self.assertRaises(SystemExit) as ctx:
            self._run_update(appcast_path=str(broken))
        self.assertEqual(ctx.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
