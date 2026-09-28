#!/usr/bin/env python3
"""
生成官网首页。

一份模板（src/index.html）加七份文案（src/strings/<lang>.json），拼出七个语言的
静态页面，并从 docs/images 拷贝首页用到的图片。生成结果提交进仓库，Cloudflare Pages
不需要构建步骤，直接发布 website/ 目录。

官网只在较大的更新时才刷新，所以它刻意不跟着发版走：
- 备用版本号和版权年份写在 src/site.json，刷新官网时手动改。线上的版本号由
  js/version.js 从 GitHub 实时获取，备用值只在请求失败时出现
- 图片是刷新官网那一刻从 docs/images 拍的快照。README 配图之后重新渲染，
  不会让官网的检查失败，下次运行本脚本时才会带过来

用法：
    python3 website/build.py           生成页面并拷贝图片
    python3 website/build.py --check   检查页面是否与模板和文案一致、图片是否齐全（CI 用）

模板语法：
    {{key}}     插入文案，文案本身就是 HTML 片段（需要 & 时写 &amp;）
    {{key|v}}   同上，并把文案里的 {version} 替换成 site.json 里的备用版本号
    {{_name}}   插入脚本计算的值（语言、链接、图片路径等），见 page_context()
"""

import json
import re
import sys
from pathlib import Path

WEBSITE = Path(__file__).resolve().parent
ROOT = WEBSITE.parent
SRC = WEBSITE / "src"
DOCS_IMAGES = ROOT / "docs" / "images"

SITE_URL = "https://u4c.fi5h.xyz"
REPO_URL = "https://github.com/f-is-h/Usage4Claude"

# (代码, HTML lang / hreflang, 语言名, 输出目录, README 路径, docs 图片后缀)
LANGUAGES = [
    ("en", "en", "English", "", "README.md", "en"),
    ("ja", "ja", "日本語", "ja/", "docs/README.ja.md", "ja"),
    ("ko", "ko", "한국어", "ko/", "docs/README.ko.md", "ko"),
    ("zh-cn", "zh-CN", "简体中文", "zh-cn/", "docs/README.zh-CN.md", "zh-CN"),
    ("zh-tw", "zh-TW", "繁體中文", "zh-tw/", "docs/README.zh-TW.md", "zh-TW"),
    ("fr", "fr", "Français", "fr/", "docs/README.fr.md", "fr"),
    ("de", "de", "Deutsch", "de/", "docs/README.de.md", "de"),
]

# 与语言无关、直接从 docs/images 拷贝的图
SHARED_IMAGES = [
    "bar.5h@2x.png",
    "bar.7d@2x.png",
    "bar.ex@2x.png",
    "bar.7do@2x.png",
    "bar.7ds@2x.png",
    "bar.mono.b@2x.png",
    "bar.mono.w@2x.png",
]

PLACEHOLDER = re.compile(r"\{\{(_?\w+)(\|v)?\}\}")


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def site_settings():
    settings = json.loads((SRC / "site.json").read_text(encoding="utf-8"))
    return settings["fallback_version"], settings["copyright_year"]


def load_strings():
    strings = {}
    for code, *_ in LANGUAGES:
        path = SRC / "strings" / f"{code}.json"
        if not path.exists():
            fail(f"缺少文案文件 {path.relative_to(ROOT)}")
        strings[code] = json.loads(path.read_text(encoding="utf-8"))

    reference = set(strings["en"])
    for code, table in strings.items():
        missing = reference - set(table)
        extra = set(table) - reference
        if missing or extra:
            fail(f"{code}.json 与 en.json 的 key 不一致：缺 {sorted(missing)}，多 {sorted(extra)}")
        for key, value in table.items():
            if '"' in value:
                # 文案也会放进属性值，直引号会截断属性
                fail(f'{code}.json 的 {key} 含有直引号 "，请改用 &quot; 或排版引号')
    return strings


def page_url(path):
    return f"{SITE_URL}/{path}"


def page_context(lang, version, year):
    code, html_lang, label, path, readme, image_lang = lang
    hreflang = [
        f'<link rel="alternate" hreflang="{l[1]}" href="{page_url(l[3])}">' for l in LANGUAGES
    ]
    hreflang.append(f'<link rel="alternate" hreflang="x-default" href="{page_url("")}">')

    menu = []
    for l in LANGUAGES:
        current = ' aria-current="true"' if l[0] == code else ""
        menu.append(
            f'<li><a href="/{l[3]}" hreflang="{l[1]}" lang="{l[1]}" data-lang="{l[0]}"{current}>{l[2]}</a></li>'
        )

    return {
        "_lang": code,
        "_html_lang": html_lang,
        "_lang_label": label,
        "_home": f"/{path}",
        "_canonical": page_url(path),
        "_hreflang": "\n  ".join(hreflang),
        "_lang_menu": "\n            ".join(menu),
        "_readme": f"{REPO_URL}/blob/main/{readme}",
        "_hero_light": f"/images/hero/hero.{image_lang}.light@2x.png",
        "_hero_dark": f"/images/hero/hero.{image_lang}.dark@2x.png",
        "_version": version,
        "_year": year,
        "_site": SITE_URL,
        "_repo": REPO_URL,
    }


def render(template, strings, context, version, code):
    used = set()

    def replace(match):
        key, with_version = match.group(1), match.group(2)
        if key.startswith("_"):
            if key not in context:
                fail(f"模板里的 {{{{{key}}}}} 没有对应的计算值")
            return context[key]
        if key not in strings:
            fail(f"模板里的 {{{{{key}}}}} 在 {code}.json 里没有")
        used.add(key)
        value = strings[key]
        return value.replace("{version}", version) if with_version else value

    html = PLACEHOLDER.sub(replace, template)
    return html, used


def sitemap():
    alternates = "\n".join(
        f'    <xhtml:link rel="alternate" hreflang="{l[1]}" href="{page_url(l[3])}"/>'
        for l in LANGUAGES
    )
    alternates += f'\n    <xhtml:link rel="alternate" hreflang="x-default" href="{page_url("")}"/>'
    urls = "\n".join(
        f"  <url>\n    <loc>{page_url(l[3])}</loc>\n{alternates}\n  </url>" for l in LANGUAGES
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n'
        '        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
        f"{urls}\n"
        "</urlset>\n"
    )


def pages():
    """返回 {输出路径: bytes}，只含由模板和文案决定的文件，生成和检查共用。"""
    version, year = site_settings()
    template = (SRC / "index.html").read_text(encoding="utf-8")
    strings = load_strings()
    result = {}

    for lang in LANGUAGES:
        code = lang[0]
        html, used = render(template, strings[code], page_context(lang, version, year), version, code)
        unused = set(strings[code]) - used
        if unused and code == "en":
            fail(f"en.json 里有模板没用到的 key：{sorted(unused)}")
        result[WEBSITE / lang[3] / "index.html"] = html.encode("utf-8")

    result[WEBSITE / "sitemap.xml"] = sitemap().encode("utf-8")
    return result


def images():
    """返回 {官网路径: docs/images 源文件}。"""
    result = {}
    for lang in LANGUAGES:
        for mode in ("light", "dark"):
            name = f"hero.{lang[5]}.{mode}@2x.png"
            result[WEBSITE / "images" / "hero" / name] = DOCS_IMAGES / name
    for name in SHARED_IMAGES:
        result[WEBSITE / "images" / "bar" / name] = DOCS_IMAGES / name
    return result


def write_if_changed(path, content):
    if path.exists() and path.read_bytes() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    print(f"wrote {path.relative_to(ROOT)}")


def main():
    if "--check" not in sys.argv[1:]:
        for path, content in pages().items():
            write_if_changed(path, content)
        for path, source in images().items():
            write_if_changed(path, source.read_bytes())
        return

    problems = [f"已过期 {p.relative_to(ROOT)}" for p, content in pages().items()
                if not p.exists() or p.read_bytes() != content]
    problems += [f"缺少 {p.relative_to(ROOT)}" for p in images() if not p.exists()]
    if problems:
        print("官网与源文件不一致，请运行 python3 website/build.py 并提交：", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        sys.exit(1)
    print("website is up to date")


if __name__ == "__main__":
    main()
