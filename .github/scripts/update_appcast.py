#!/usr/bin/env python3
"""
Insert a new release item into appcast.xml.

Usage:
    update_appcast.py <appcast.xml> <version> <build> <pub_date>
                      <dmg_url> <release_url> <changelog.md> <enclosure.txt>
"""

import re
import sys


def extract_changelog_section(changelog_path: str, version: str) -> str:
    with open(changelog_path, "r") as f:
        content = f.read()

    # Match the section starting with ## [X.Y.Z] up to the next ## heading
    pattern = rf"## \[{re.escape(version)}\][^\n]*\n(.*?)(?=\n## \[|\Z)"
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return ""

    return match.group(1).strip()


def update_appcast(
    appcast_path: str,
    version: str,
    build: str,
    pub_date: str,
    dmg_url: str,
    release_url: str,
    changelog_path: str,
    enclosure_path: str,
) -> None:
    with open(enclosure_path, "r") as f:
        enclosure = f.read().strip()

    release_notes = extract_changelog_section(changelog_path, version)

    new_item = f"""
        <item>
            <title>v{version}</title>
            <pubDate>{pub_date}</pubDate>
            <sparkle:version>{build}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <link>{release_url}</link>
            <description sparkle:format="markdown"><![CDATA[
{release_notes}
            ]]></description>
            {enclosure}
        </item>"""

    marker = "<!-- Items go here. Top item is the latest version. -->"

    with open(appcast_path, "r") as f:
        content = f.read()

    if marker not in content:
        print(f"error: marker not found in {appcast_path}", file=sys.stderr)
        sys.exit(1)

    content = content.replace(marker, marker + new_item, 1)

    with open(appcast_path, "w") as f:
        f.write(content)

    print(f"✅ appcast.xml updated with v{version}")


if __name__ == "__main__":
    if len(sys.argv) != 9:
        print(
            f"Usage: {sys.argv[0]} <appcast.xml> <version> <build> <pub_date>"
            " <dmg_url> <release_url> <changelog.md> <enclosure.txt>"
        )
        sys.exit(1)

    update_appcast(
        appcast_path=sys.argv[1],
        version=sys.argv[2],
        build=sys.argv[3],
        pub_date=sys.argv[4],
        dmg_url=sys.argv[5],
        release_url=sys.argv[6],
        changelog_path=sys.argv[7],
        enclosure_path=sys.argv[8],
    )
