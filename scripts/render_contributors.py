#!/usr/bin/env python3
"""
Renders the contributor avatar walls used by the READMEs.

GitHub strips CSS from README HTML, so round avatars are only possible inside
an image. This does what contrib.rocks does (circular clip, avatars embedded
as base64 so the SVG renders through GitHub's image proxy), but reads the
list from docs/contributors.json instead of the contributors API, which only
knows commit authors and would leave out translators and issue reporters.

To add someone: append their GitHub login to the right group in
docs/contributors.json, run this script, commit both files.

    python3 scripts/render_contributors.py

Output: docs/images/contributors.<group>.svg, one per group. Standard library
only, so it runs on the system Python.
"""
import base64
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIST_FILE = ROOT / "docs" / "contributors.json"
OUT_DIR = ROOT / "docs" / "images"

AVATAR = 56          # 显示尺寸（pt）
FETCH = AVATAR * 2   # 按 2x 取图，Retina 下不糊
GAP = 10
PER_ROW = 12


def fetch_avatar(login):
    url = f"https://github.com/{login}.png?size={FETCH}"
    req = urllib.request.Request(url, headers={"User-Agent": "Usage4Claude-docs"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
        mime = resp.headers.get("Content-Type", "image/png").split(";")[0]
    return f"data:{mime};base64," + base64.b64encode(data).decode("ascii")


def render_group(logins):
    cols = min(len(logins), PER_ROW)
    rows = (len(logins) + PER_ROW - 1) // PER_ROW
    width = cols * AVATAR + (cols - 1) * GAP
    height = rows * AVATAR + (rows - 1) * GAP
    r = AVATAR / 2

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<defs><clipPath id="c"><circle cx="{r}" cy="{r}" r="{r}"/></clipPath></defs>',
    ]
    for i, login in enumerate(logins):
        x = (i % PER_ROW) * (AVATAR + GAP)
        y = (i // PER_ROW) * (AVATAR + GAP)
        print(f"  {login}", file=sys.stderr)
        href = fetch_avatar(login)
        # 描边用半透明灰，浅色与深色背景下都能勾出白底头像的边缘
        parts.append(
            f'<g transform="translate({x},{y})"><title>{login}</title>'
            f'<image width="{AVATAR}" height="{AVATAR}" clip-path="url(#c)" xlink:href="{href}"/>'
            f'<circle cx="{r}" cy="{r}" r="{r - 0.5}" fill="none" stroke="#8c8c8c" stroke-opacity="0.3"/></g>'
        )
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def main():
    groups = json.loads(LIST_FILE.read_text(encoding="utf-8"))
    for name, logins in groups.items():
        if not logins:
            continue
        print(f"{name} ({len(logins)})", file=sys.stderr)
        out = OUT_DIR / f"contributors.{name}.svg"
        out.write_text(render_group(logins), encoding="utf-8")
        print(f"  -> {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)", file=sys.stderr)


if __name__ == "__main__":
    main()
