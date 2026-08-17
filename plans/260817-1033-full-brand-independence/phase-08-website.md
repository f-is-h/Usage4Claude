# Phase 08 — Website Rebrand + Cloudflare Domain Rename

> **Status: DEFERRED — out of scope for this run (decision V4).**
> This run executes Phases 01–06 only; the plan is "done" at Phase 06. Two things changed
> for this phase in the meantime:
> - **The domain token is already swept** (V8, Phase 04): every doc and page now names
>   `usagepacecc.pages.dev`. Until the Cloudflare project rename in step 2 below happens,
>   **that host does not resolve.** Closing that gap is now this phase's first job.
> - **Sponsor links are removed, not kept** (V1 overrides D8). See the note in Key Insights.

## Context links

- Plan: [plan.md](./plan.md) — decision V8 (domain), V1 (sponsor links), V4 (deferral)
- Scout: [scout-01 §F](./scout/scout-01-residual-branding-surface.md)
- Prior plan: `plans/2026-06-21-fork-rebrand-upstream-sync/phase-07-website.md` (deferred there too, D5/D6)
- Depends on: [Phase 05](./phase-05-github-identity.md) (repo renamed) and
  [Phase 04](./phase-04-string-sweep.md) (domain token already swept); ideally the deferred
  [Phase 07](./phase-07-signing-release.md) (download links need a real release)

## Overview

Rebrand the Cloudflare Pages site: 5 localized landing pages + legal/privacy, all
GitHub links, and the Cloudflare Pages domain. **Deferred — the plan is already "done" at
Phase 06.** Do this when the site is worth publishing again.

## Key Insights

- The site is the largest remaining brand surface: ~60 `Usage4Claude` refs across 7 HTML
  files, plus `website/README.md`, `robots.txt`, `js/translations-privacy.js`, `js/main.js`.
- The site is **Cloudflare Pages, not GitHub Pages** — the repo rename in Phase 05 does not
  touch it. Confirmed: `gh api …/pages` → 404.
- The site currently sends visitors to **upstream** for downloads/issues/discussions
  (`f-is-h/Usage4Claude`). Post-detach that is misleading, not attribution. Repoint —
  except the explicit "based on / MIT" credit. **The upstream sponsor link is removed, not
  kept: V1 overrides D8.** Phase 04 already removed it everywhere outside `website/`; do the
  same here rather than repointing it to the fork.
- Download links are dead until the deferred Phase 07 publishes a release. Sequencing matters.
- **The repo already advertises `usagepacecc.pages.dev` and it does not resolve** — Phase 04
  swept the token (V8) while the Cloudflare project still serves `usage4claude.pages.dev`.
  Every day this phase stays deferred, the documented URL 404s. Fixing that is step 2.
- Domain rename is a Cloudflare-side operation (rename or recreate the Pages project);
  `*.pages.dev` gives no redirect from the old subdomain. Any external link to
  `usage4claude.pages.dev` breaks — near-zero risk (site is not promoted outside this repo).
- The 5 localized pages must move together; a half-translated brand looks broken.

## Requirements

- Cloudflare Pages project renamed so the already-documented `usagepacecc.pages.dev` resolves.
- All GitHub links repoint to `quangyendn/UsagePaceCC`, except the MIT attribution.
- No sponsor/funding link survives anywhere in `website/` (V1).
- Title/meta/OG/canonical/`robots.txt` sitemap URL consistent across all 7 pages.
- Legal pages keep the MIT attribution to f-is-h.
- Deployed site loads in all 5 languages with the language switcher intact.

## Architecture

```
website/
  index.html         21 old refs   EN   title, meta, OG, canonical, 6+ GH links
  index.zh-cn.html   21            zh-CN
  index.zh-tw.html   21            zh-TW
  index.ja.html      21            ja
  index.ko.html      21            ko
  legal.html          7                 MIT + upstream refs (mostly KEEP)
  privacy.html        5
  README.md           5                 build/deploy notes + domain
  robots.txt                            sitemap URL → new domain
  js/main.js          1
  js/i18n.js                            verify: language switcher paths
  js/translations-privacy.js  4
  functions/_middleware.js              verify: no hardcoded host
docs/CLOUDFLARE_DEPLOYMENT.md           deploy guide — brand + domain already swept in
                                        Phase 04; here: drop the "rename pending" note
docs/WEBSITE_GUIDE.md                   project refs done in Phase 04; verify only
docs/images/GitHubSocialPreview_v2.0.html  4   social card
```

## Related code files

All paths rooted at `/Users/yennq/Projects/opensrc/Usage4Claude/`. Every row above is a
modify. No file renames required.

## Implementation Steps

1. Domain is **already decided and already written into the repo**: `usagepacecc.pages.dev`
   (V8, swept in Phase 04). No decision left — only the Cloudflare-side rename below.
2. **[USER][MANUAL]** In the Cloudflare dashboard, rename the Pages project to
   `usagepacecc` (or create a new project bound to the same repo and delete the old one),
   so `usagepacecc.pages.dev` serves the site. The old `*.pages.dev` subdomain does **not**
   redirect — nothing in the repo points at it any more, so that is acceptable.
3. Update the shared metadata in all 5 `index*.html`: `<title>`, `<meta name="description">`,
   OG/Twitter tags, `<link rel="canonical">`, and any `hreflang` alternates → new domain +
   `UsagePaceCC`.
4. Repoint GitHub links in all 5 `index*.html`: releases/download, issues, discussions,
   repo link → `quangyendn/UsagePaceCC`. **Keep** the "based on Usage4Claude by f-is-h
   (MIT)" credit. **Delete** any sponsor / Ko-fi / funding link (V1) — do not repoint it.
5. `legal.html` + `privacy.html`: rebrand the product name; **keep** the MIT/copyright
   attribution to f-is-h; repoint the issues link.
6. `robots.txt`: sitemap URL → new domain. `js/translations-privacy.js` + `js/main.js`:
   replace remaining brand strings. Verify `js/i18n.js` language switching still resolves
   page paths.
7. Verify `functions/_middleware.js` has no hardcoded host/origin.
8. `docs/CLOUDFLARE_DEPLOYMENT.md`: remove the "domain rename pending" note Phase 04 added —
   it is no longer pending. Verify `docs/WEBSITE_GUIDE.md` needs nothing further.
9. Regenerate the social preview from `docs/images/GitHubSocialPreview_v2.0.html` and
   upload it in repo Settings → Social preview (Phase 05 checklist item).
10. Screenshots: the site embeds app screenshots showing the old menu-bar name. **The
    capture skill was deleted in Phase 04 (V7)** — recapture manually, or accept stale
    images and log it. Do not go looking for the skill.
11. Deploy preview → check all 5 languages, the switcher, the download button (must hit the
    Phase 07 release), and legal/privacy. Then promote to production.
12. Update the repo homepage to the site URL:
    `gh repo edit quangyendn/UsagePaceCC --homepage "https://<new-domain>/"`.

## Todo list

- [ ] **[USER][MANUAL]** Cloudflare Pages project rename → `usagepacecc.pages.dev`
      (closes the gap opened by Phase 04's doc sweep)
- [ ] 5 × `index*.html`: title/meta/OG/canonical/hreflang
- [ ] 5 × `index*.html`: GitHub links → fork (keep attribution, **delete sponsor**)
- [ ] `legal.html`, `privacy.html`
- [ ] `robots.txt`, `js/translations-privacy.js`, `js/main.js`; verify `js/i18n.js`
- [ ] Verify `functions/_middleware.js`
- [ ] `docs/CLOUDFLARE_DEPLOYMENT.md`, `docs/WEBSITE_GUIDE.md` domain refs
- [ ] Regenerate + upload social preview
- [ ] Recapture screenshots manually (capture skill was deleted in Phase 04) or log as stale
- [ ] Deploy preview → verify 5 languages + download link → promote
- [ ] `gh repo edit --homepage`

## Success Criteria

- [ ] `git grep -c "Usage4Claude" -- website/` → only the MIT attribution lines
- [ ] `https://usagepacecc.pages.dev/` resolves (the repo has named it since Phase 04)
- [ ] `git grep "sponsors/f-is-h\|ko-fi" -- website/` → 0
- [ ] All 5 language pages load; switcher works; canonical/hreflang consistent
- [ ] Download button resolves to the (deferred) Phase 07 release asset
- [ ] `legal.html`/`privacy.html` still credit f-is-h under MIT
- [ ] Repo homepage points at the live site

## Verification commands

```bash
git grep -n "Usage4Claude"          -- website/ docs/CLOUDFLARE_DEPLOYMENT.md
git grep -n "usage4claude.pages.dev" -- . ':!plans'   # → 0 since Phase 04
grep -n "canonical\|og:url\|hreflang" website/index.html
curl -sI https://<new-domain>/ | head -1
curl -s  https://<new-domain>/ | grep -o "<title>.*</title>"
```

## Rollback

Repo-side edits are one revert. The Cloudflare project rename is dashboard-side: renaming
back restores the old `*.pages.dev` subdomain, but any cached/external link is broken in
the interim. Deploy to a preview branch first.

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Old `*.pages.dev` links break with no redirect | Low | Site is unpromoted and the repo stopped referencing the old host in Phase 04; optionally keep the old project serving a one-page redirect |
| Localized pages drift out of sync | Medium | Treat the 5 pages as one atomic change set; verify each in preview |
| Download link 404s | Medium | Sequence after the deferred Phase 07; verified in step 11 |
| Documented domain 404s while this phase stays deferred | Medium | Known and accepted (V8). Phase 04 recorded a "rename pending" note in `docs/CLOUDFLARE_DEPLOYMENT.md`; step 2 closes it |
| Attribution removed from legal pages | **High** | Steps 4–5 call out the keeps explicitly; grep check in Success Criteria |
| Stale screenshots showing the old brand | Low | Step 10 — recapture or consciously accept |

## Security Considerations

- Static site: no secrets in the repo. Confirm `functions/_middleware.js` adds no headers
  leaking origin/build info.
- Privacy page must still accurately describe data handling after the bundle-id change
  (local-only storage; no telemetry) — re-read before publishing, do not just rebrand it.
- Cloudflare deploy tokens live in the Cloudflare dashboard, not the repo. Do not migrate
  them into GitHub secrets to "simplify".

## Next steps

Final phase. On completion set `plan.md` frontmatter `status: completed` and close out the
prior plan's Phase 07 (`plans/2026-06-21-fork-rebrand-upstream-sync/phase-07-website.md`),
which this supersedes.
