# Usage4Claude Website

Product website for the Usage4Claude macOS app: https://u4c.fi5h.xyz

It is a landing page, not a manual. It covers what the app does, its highlights, privacy and
installation, and links to the README for everything else. Keep it that way: details such as exact
thresholds, colors or model names go stale between website updates, while the README is updated
with every release.

## How It Works

The seven homepages are generated from one template and seven string files, and the generated
files are committed. Cloudflare Pages has no build step and publishes `website/` as is.

```
website/
├── src/
│   ├── index.html          # The only homepage template
│   ├── strings/<lang>.json # Copy for en, ja, ko, zh-cn, zh-tw, fr, de (same keys in all seven)
│   └── site.json           # Fallback version and copyright year
├── build.py                # Generates the pages below and copies images from docs/images
├── index.html              # Generated: English, served at /
├── ja/ ko/ zh-cn/ zh-tw/ fr/ de/index.html   # Generated
├── sitemap.xml             # Generated
├── images/hero/, images/bar/                  # Copied from docs/images by build.py
├── css/site.css            # Homepage styles (light and dark)
├── js/site.js              # Language menu
├── js/version.js           # Fills in the latest version from the GitHub Releases API
├── functions/_middleware.js
├── legal.html, privacy.html # Hand-written, still on Tailwind CDN + css/custom.css + js/i18n.js
└── images/og-image.png     # 1200×630 share image
```

Never edit the generated `index.html` files by hand. CI runs `python3 website/build.py --check`
and fails when they no longer match the template and strings.

## Updating the Website

The website is refreshed after larger updates only, not on every release.

1. Edit `src/strings/*.json` (all seven keep the same keys) and, for structural changes,
   `src/index.html`
2. Bump `fallback_version` and `copyright_year` in `src/site.json`
3. If the app UI changed, re-render the images first with `./scripts/render_docs_images.sh`
4. Run `python3 website/build.py` and commit the source and generated files together

Template syntax: `{{key}}` inserts a string (strings are HTML fragments, so write `&amp;`);
`{{key|v}}` also replaces `{version}` with the fallback version; `{{_name}}` inserts a value computed
by `build.py`. Strings must not contain a straight `"`, since some end up in attributes.

## Edge Logic (functions/_middleware.js)

- `usage4claude.pages.dev` → 301 to `u4c.fi5h.xyz`. Hashed preview subdomains are left alone
- Old homepage URLs (`/index.ja`, `/index.ja.html`, …) → 301 to `/ja/` and so on
- `/` redirects to a language homepage: the `u4c_lang` cookie set by the language menu wins,
  otherwise the first supported language in `Accept-Language`. English or anything unsupported
  stays on `/`
- `[NAME_PLACEHOLDER]`, `[EMAIL_PLACEHOLDER]` and `[ADDRESS_PLACEHOLDER]` in `legal.html` are
  replaced from environment variables, so the real details never enter the repository (see
  `functions/README.md`)

The middleware does not run under a local static server, so language redirects can only be seen
after deployment.

## Local Preview

```bash
python3 -m http.server 8765 --directory website
```

Pages use absolute paths (`/css/site.css`), so open them through the server rather than as files.

## Adding a Language

Add it to `LANGUAGES` in `build.py` and `LANGUAGES` in `functions/_middleware.js`, add
`src/strings/<code>.json`, make sure `docs/images/hero.<code>.{light,dark}@2x.png` exists, and run
the build. `privacy.html` and `js/translations-privacy.js` need the language separately.
