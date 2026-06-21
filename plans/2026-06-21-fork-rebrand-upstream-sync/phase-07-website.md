# Phase 07 — Rebrand: Website (Optional / Deferrable)

## Context links
- plan.md → D5 (domain), D6 (multilingual)
- Scout §5, §7

## Overview
Rebrand the marketing site. OPTIONAL and DEFERRABLE — app distribution does not
depend on it (download is via GitHub Releases). Do after the app ships, or skip
initially. Depends on Phase 02 (name) and ideally Phase 05 (web icons).

## Insights (verified paths/lines)
- Pages: `website/index.html` (+ `index.{zh-cn,zh-tw,ja,ko}.html`), `legal.html`, `privacy.html`, `README.md`.
- `index.html:11` canonical `https://usage4claude.pages.dev/`; `:12-16` hreflang alternates; `:23-32` OG tags; `:72` navbar GitHub; `:290` download `releases/latest`; `:293,332-335,342` footer/sponsor; `:362` LICENSE link; `:368` footer `© 2026 f-is-h`.
- `legal.html:53,94`, `privacy.html:86,125-126` GitHub/LICENSE/issues links.
- `website/js/main.js:19` console banner `✨ Usage4Claude … github.com/f-is-h/Usage4Claude`.
- Config: `website/functions/_middleware.js`, `website/js/i18n.js`, `website/favicon.ico`, `website/images/icon.png`.

## Requirements (D5, D6)
- New domain or skip; English-only first vs keep all 6 localized pages.

## Files
- All `website/*.html`, `website/js/main.js`, `website/js/i18n.js`, `website/functions/_middleware.js`, `website/README.md`, favicon + images.

## Steps
1. Decide D5 (domain) + D6 (langs). Default: `<newname>.pages.dev`, English-only first; archive other-lang HTML to restore later.
2. Replace brand name + title + OG/meta across kept HTML pages.
3. Replace all `f-is-h/Usage4Claude` GitHub links → `quangyendn/Usage4Claude`; download → `quangyendn` releases/latest; LICENSE link → fork LICENSE.
4. Replace canonical/hreflang/og:url domains → new domain (or remove hreflang if English-only).
5. Footer `© 2026 f-is-h` → `© 2026 Yen NQ` + add "based on f-is-h/Usage4Claude" + Anthropic disclaimer.
6. `js/main.js:19` console banner → new name + fork URL.
7. Favicon + `images/icon.png` → new icon (from Phase 05).
8. Update legal.html/privacy.html links; review legal text for brand + disclaimer.
9. Deploy preview (Cloudflare Pages) and verify.

## Todos
- [ ] D5/D6 decided
- [ ] HTML pages rebranded (name, meta, OG)
- [ ] all GitHub links → quangyendn
- [ ] domain/canonical/hreflang updated or trimmed
- [ ] footer copyright + attribution + Anthropic disclaimer
- [ ] js console banner + favicon/icon updated
- [ ] legal/privacy reviewed
- [ ] preview deploy verified

## Success
- Site renders under new name/domain; all links resolve to fork; no `f-is-h`/`usage4claude.pages.dev` leftovers on kept pages.

## Risks
- Multilingual drift if only English updated but other pages kept live → either update all or take others offline (D6).
- Custom domain DNS/Pages config is extra ops — default to `.pages.dev` to avoid scope creep.

## Next
Independent of Phase 09; can ship after app release.
