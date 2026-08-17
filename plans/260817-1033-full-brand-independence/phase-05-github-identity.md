# Phase 05 — GitHub Identity: Detach → Rename → Re-point

## Context links

- Plan: [plan.md](./plan.md) — "Reality Check" holds the verified repo state
- Research: [researcher-01 — GitHub detach/rename](./research/researcher-01-github-detach-rename.md)
- Depends on: [Phase 01](./phase-01-preflight-safety.md) confirm gate item B = YES,
  [Phase 04](./phase-04-string-sweep.md) pushed

## Overview

Leave the fork network, rename `Usage4Claude` → `UsagePaceCC`, refresh description /
homepage / settings, and re-point everything the rename does not redirect.
**Contains the one permanently irreversible action in this plan.**

## Key Insights

- Detach eligibility confirmed live: public ✓, 20 MB ≪ 1 GB ✓, 0 child forks ✓ →
  self-service "Leave fork network" applies; no Support ticket.
- Verified blast radius: **0 stars, 0 watchers, Issues disabled, 0 PRs, 0 releases,
  no wiki content in use**. The scary docs list is nearly empty here.
- **No GitHub Pages site exists** (`gh api …/pages` → 404) → the classic
  "rename silently breaks Pages" failure mode does not apply. The website is Cloudflare
  Pages, independent of the repo name (deferred Phase 08).
- **Zero published releases** → no shipped binary holds a stale update endpoint.
  The "cannot retro-patch shipped builds" risk is currently nil — and stays nil only if
  `UpdateChecker.repoName` is already `UsagePaceCC` (done in Phase 04) **before** the
  deferred Phase 07 publishes the first release. Phase 04 lands that fix in this run, so the
  mitigation is already in place when 07 is eventually picked up.
- Labels are repo-scoped → they survive rename and detach. `security` and `upstream-sync`
  already exist. Only `dependencies` is missing (created in Phase 06).
- Only one workflow (`Build and Release`) is registered, and it references no
  external composite action from this repo → nothing for GitHub Actions to fail on.
- Detach cannot be scripted safely via `gh`; it is a **UI action** in Settings → Danger Zone.
- Order per research: **detach first, then rename** (avoids a transitional
  "new name + still shows forked from f-is-h" state).

## Requirements

- Explicit re-confirmation immediately before the detach click.
- Detach, then rename, then metadata, then verification — in that order.
- Local remotes updated; old URL redirect verified working.
- Issues enabled (docs now point fork users at fork issues).

## Architecture

```
BEFORE                                    AFTER
quangyendn/Usage4Claude                   quangyendn/UsagePaceCC
  fork of f-is-h/Usage4Claude               standalone (no parent)
  description: upstream's text              own description
  homepage: github.com/f-is-h/Usage4Claude  own homepage
  Issues: disabled                          Issues: enabled
  git remote origin: …/Usage4Claude.git     …/UsagePaceCC.git
  remote upstream: f-is-h/… (unchanged)     unchanged — still tracked, manual only
```

## Related code files

| Path | Action | Note |
|---|---|---|
| `.git/config` (remote `origin` URL) | modify | via `git remote set-url` |
| (no tracked source files) | — | all repo-content edits landed in Phase 04 |

## Implementation Steps

1. Pre-flight: confirm Phase 04 is pushed and `origin/main` is green.
   ```bash
   git status -sb; git log --oneline -1 origin/main
   gh run list --repo quangyendn/Usage4Claude --limit 3
   ```
2. Re-confirm detach eligibility and blast radius **right now** (state may have changed):
   ```bash
   gh repo view quangyendn/Usage4Claude --json isFork,visibility,diskUsage,forkCount,\
stargazerCount,watchers,hasIssuesEnabled
   gh issue list --repo quangyendn/Usage4Claude --state all 2>&1 | head
   gh pr    list --repo quangyendn/Usage4Claude --state all       | head
   ```
   If any count is now non-zero, STOP and re-present the gate with the new numbers.
3. **[USER][MANUAL][PERMANENT — CANNOT BE UNDONE]** Detach:
   - Open `https://github.com/quangyendn/Usage4Claude/settings`
   - Scroll to **Danger Zone** → **Leave fork network**
   - Tick "I have read and understand these effects"
   - Type the repo name to confirm → click **Leave fork network**
4. Verify detach: `gh repo view quangyendn/Usage4Claude --json isFork,parent`
   → `isFork: false`, `parent: null`. The "forked from f-is-h/Usage4Claude" banner is gone.
5. **[USER][MANUAL]** Rename (either path):
   - UI: Settings → General → Repository name → `UsagePaceCC` → Rename
   - or: `gh repo rename UsagePaceCC --repo quangyendn/Usage4Claude`
6. Update local remote and verify redirect:
   ```bash
   git remote set-url origin git@github.com:quangyendn/UsagePaceCC.git
   git remote -v                                  # upstream stays f-is-h/Usage4Claude
   git fetch origin && git status -sb
   curl -sI https://github.com/quangyendn/Usage4Claude | head -1   # 301 → new path
   ```
7. **Enable Issues (decision V2) — do this before anything else in this step.** Phase 04
   already published docs, READMEs and in-app Diagnostics links that send users to this
   repo's issue tracker; those links 404 while Issues stay disabled. Close that window
   immediately after the rename:
   ```bash
   gh repo edit quangyendn/UsagePaceCC --enable-issues
   gh repo view quangyendn/UsagePaceCC --json hasIssuesEnabled   # → true
   ```
   Ordering rule: **rename → enable Issues → publicise**. Do not defer this to the end of
   the phase, and do not announce the repo anywhere until it returns `true`.
8. Refresh the rest of the repo metadata (currently still upstream's copy):
   ```bash
   gh repo edit quangyendn/UsagePaceCC \
     --description "UsagePaceCC — a macOS menu-bar monitor for Claude and Codex usage limits. MIT fork of f-is-h/Usage4Claude." \
     --homepage "https://github.com/quangyendn/UsagePaceCC"
   ```
   *(Homepage becomes the website URL in the deferred Phase 08 if the site is rebranded.)*
9. Enumerate + re-point what rename does NOT redirect (checklist, most are no-ops here):
   - [ ] GitHub Pages — **N/A**, no Pages site (verified 404)
   - [ ] Actions referencing this repo as an action source — **none**; only `Build and Release`
   - [ ] Workflow badges in README — verify they render (shields.io follows redirects, but confirm)
   - [ ] Repo secrets / variables — unaffected by rename; just record the current list:
         `gh secret list --repo quangyendn/UsagePaceCC`.
         **Do not treat `CODESIGN_CERTIFICATE` / `CODESIGN_PASSWORD` as something to keep** —
         they are deleted in Phase 06 (V3). This step only captures the before-state.
   - [ ] Branch protection / rulesets — re-check they still apply post-rename
   - [ ] Social preview image — re-upload if it embeds the old name
         (`docs/images/GitHubSocialPreview_v2.0.html` has 4 old refs)
   - [ ] Any local clone on another machine — `git remote set-url` there too
   - [ ] `docs/UPSTREAM_SYNC.md` origin URL — owned by Phase 06
10. Enable repo security features (prior-plan USER TODO, still outstanding):
   Settings → Code security → Dependency graph, Dependabot alerts, Dependabot security updates.
11. Smoke-test the app's live endpoints:
    ```bash
    curl -s https://api.github.com/repos/quangyendn/UsagePaceCC/releases/latest | head -5
    # 404 "Not Found" until the deferred Phase 07 publishes — correct shape, right repo
    ```
    Launch the app, open About → GitHub link resolves; Diagnostics → issues link resolves.
12. Now safe to delete the old branch: `git push origin --delete feat/rebrand-usagepacecc`
    (keep `backup/*` refs indefinitely).

## Todo list

- [ ] Verify Phase 04 pushed, CI green
- [ ] Re-check detach eligibility + blast radius numbers
- [ ] **[USER][MANUAL][PERMANENT]** Leave fork network
- [ ] Verify `isFork: false`, `parent: null`
- [ ] **[USER][MANUAL]** Rename repo → `UsagePaceCC`
- [ ] `git remote set-url origin`; verify fetch + 301 redirect
- [ ] **`gh repo edit --enable-issues` (V2)** — immediately after the rename, before the
      repo is publicised; verify `hasIssuesEnabled: true`
- [ ] `gh repo edit`: description, homepage
- [ ] Walk the re-point checklist
- [ ] Enable Dependency graph + Dependabot alerts + security updates
- [ ] Smoke-test UpdateChecker endpoint + in-app links
- [ ] Delete `feat/rebrand-usagepacecc` on origin

## Success Criteria

- [ ] `gh repo view quangyendn/UsagePaceCC --json isFork,parent` → `false` / `null`
- [ ] `https://github.com/quangyendn/UsagePaceCC` loads; old URL 301-redirects
- [ ] Description + homepage are the fork's own text
- [ ] `hasIssuesEnabled: true` (V2)
- [ ] `gh label list` still shows `security` + `upstream-sync`
- [ ] `gh workflow list` intact; a manual `Build and Release` dispatch (or the next push) is green
- [ ] `git fetch origin` works from the updated remote
- [ ] README badges render

## Verification commands

```bash
gh repo view quangyendn/UsagePaceCC --json name,isFork,parent,description,homepageUrl,hasIssuesEnabled
gh label list    --repo quangyendn/UsagePaceCC
gh workflow list --repo quangyendn/UsagePaceCC
gh secret list   --repo quangyendn/UsagePaceCC
curl -sI https://github.com/quangyendn/Usage4Claude | head -1
git remote -v && git fetch origin
```

## Rollback

- **Rename: reversible** — rename back to `Usage4Claude` (as long as nobody claimed the
  old name in the interim).
- **Detach: NOT reversible.** There is no rollback. The Phase 01 backup preserves git
  history and metadata snapshots, not the fork relationship. Re-forking upstream would
  create a *different* repo.
- The redirect is fragile: if anyone later creates a repo at `quangyendn/Usage4Claude`,
  the redirect dies silently. Consider parking the old name under your account as an empty
  placeholder if that matters (optional, low priority given zero external users).

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Detach destroys something unnoticed | Medium→Low | Phase 01 export + step 2 re-check; verified counts are all zero |
| User clicks detach on the wrong repo | High | Step 3 spells out the exact URL; GitHub requires typing the repo name |
| Rename breaks CI | Low | Only one workflow, no self-referencing actions; step 8 verifies |
| Old URL redirect later hijacked | Low | Documented in Rollback; optionally park the old name |
| Docs point at Issues while Issues stay disabled | Medium | `--enable-issues` in step 7, gated in Success Criteria |
| Local clones elsewhere still on the old URL | Low | Redirect keeps them working; step 8 checklist item |

## Security Considerations

- Detach removes the fork relationship — you can no longer open PRs upstream through the
  fork UI. Manual remote-based PRs still work. Acceptable: this fork does not upstream.
- Repo secrets (`CODESIGN_CERTIFICATE`, `CODESIGN_PASSWORD`) survive rename. They are
  **deleted in Phase 06** (V3 — the CI cert-import is a no-op). Here, only confirm they
  were never printed into a workflow log.
- Enabling Issues opens a public inbound channel — expect spam eventually; labels and
  templates already exist.

## Next steps

→ [Phase 06 — Upstream decoupling](./phase-06-upstream-decoupling.md).
