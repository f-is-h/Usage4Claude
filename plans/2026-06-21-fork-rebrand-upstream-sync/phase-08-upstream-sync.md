# Phase 08 — Upstream-Sync Mechanism
<!-- status: done | completed: 2026-06-21 -->

## Context links
- plan.md → Open Questions 5
- research/researcher-01-upstream-sync.md (verbatim workflow + topology)

## Overview
Establish the vendor-mirror + divergent-main topology, a weekly watch workflow that
opens a draft PR (no auto-merge) flagging fix/security/CVE commits, Dependabot, and
a docs file for the recurring cherry-pick procedure. Independent of rebrand; can run
anytime after Phase 01. Touches only `.github/`, branches, docs.

## Insights (verified current state)
- `origin` = `git@github.com:quangyendn/Usage4Claude.git`; `upstream` = `https://github.com/f-is-h/Usage4Claude.git` ALREADY configured.
- Branches present: `main`, `feat/linear-graph` (current), `remotes/upstream/main`. NO `upstream-mirror` yet.
- A prior merge commit `f3446b9 "Merge upstream/main"` already exists on the branch → `main` already contains some upstream history. The mirror/cherry-pick model still works; just note `main` is not a clean rebrand-only line. Going forward prefer cherry-pick over merge to avoid further interleaving.
- Research §371 caveat: empty draft PR (head==base, no diff) may be rejected by `gh pr create` — must test on this repo.

## Requirements
- No auto-merge into `main` ever.
- `upstream-mirror` fast-forward-only mirror of `upstream/main`.
- Workflow uses only `GITHUB_TOKEN` (same-repo PR; no PAT).

## Files
- `.github/workflows/upstream-watch.yml` (from research §3, verbatim, adapted for empty-PR caveat)
- `.github/dependabot.yml` (from research §4)
- `docs/UPSTREAM_SYNC.md` (procedure + last-synced-SHA log)

## Steps
1. **One-time branch setup** (local + push):
   ```bash
   git fetch upstream
   git checkout -b upstream-mirror upstream/main
   git push -u origin upstream-mirror
   git checkout main   # or feat/linear-graph per current work
   ```
2. **Create labels** (gh):
   ```bash
   gh label create security --color d73a4a --repo quangyendn/Usage4Claude
   gh label create upstream-sync --color 0075ca --repo quangyendn/Usage4Claude
   ```
   (Ignore "already exists" errors.)
3. **Add `.github/workflows/upstream-watch.yml`** — copy research §3 verbatim. Then adapt the empty-PR caveat (OQ5): in "Create sync branch for PR", auto-cherry-pick the first new upstream commit into the branch so the PR has a diff:
   ```bash
   git checkout -b "$BRANCH" origin/main
   FIRST=$(git rev-list --reverse origin/${MIRROR_BRANCH}..upstream/${UPSTREAM_BRANCH} | head -1)
   git cherry-pick -x "$FIRST" || git cherry-pick --abort   # if conflict, leave branch empty + note in PR body
   git push origin "$BRANCH"
   ```
   Keep the issue-fallback step for the conflict/empty case.
4. **Add `.github/dependabot.yml`** (swift + github-actions, weekly) per research §4.
5. **Enable repo security** (manual, GitHub UI → Settings → Code security): Dependency graph, Dependabot alerts, Dependabot security updates. Document in UPSTREAM_SYNC.md.
6. **Write `docs/UPSTREAM_SYNC.md`**: topology diagram, recurring cherry-pick commands (research §1), cherry-pick-preferred rationale (§5), last-synced-SHA log table, note about pre-existing `f3446b9` merge, and the `upstream-reviewed/<date>` tag convention.
7. **Dry-run**: `gh workflow run upstream-watch.yml` (workflow_dispatch); inspect run + any draft PR/issue. Since `main` already merged upstream once, expect possibly 0 new commits → verify the no-op path exits cleanly.

## Todos
- [ ] upstream-mirror branch created + pushed — USER TODO (outward): `git checkout -b upstream-mirror upstream/main && git push -u origin upstream-mirror`
- [ ] security + upstream-sync labels created — USER TODO (outward): `gh label create security --color d73a4a --repo quangyendn/Usage4Claude` and `gh label create upstream-sync --color 0075ca --repo quangyendn/Usage4Claude`
- [x] upstream-watch.yml added (with empty-PR cherry-pick adaptation)
- [x] dependabot.yml added
- [ ] repo security features enabled (manual) — USER TODO (outward): GitHub UI → Settings → Code security → enable Dependency graph, Dependabot alerts, Dependabot security updates
- [x] docs/UPSTREAM_SYNC.md written (incl. last-synced-SHA log + f3446b9 note)
- [ ] workflow_dispatch dry-run passes (no-op or valid PR) — USER TODO (outward): `gh workflow run upstream-watch.yml --repo quangyendn/Usage4Claude`; inspect run log and any draft PR/issue created

## Success
- `git ls-remote origin upstream-mirror` returns a ref.
- Manual workflow run completes; on new commits opens a labeled draft PR with a diff; on none, exits cleanly.
- Dependabot status visible in repo Insights.
- UPSTREAM_SYNC.md gives a junior dev a copy-paste cherry-pick recipe.

## Risks
- Empty-PR rejection (OQ5) — mitigated by auto-cherry-pick first commit; falls back to issue on conflict.
- Force-push to `upstream-mirror` is intended (mirror) but never to `main`. Workflow only force-with-lease's the mirror.
- If upstream renames default branch, `UPSTREAM_BRANCH` env needs update (research OQ3).
- Pre-existing merge `f3446b9` means future cherry-picks may re-detect already-applied changes (empty cherry-picks) — note in docs; use `git cherry-pick --skip` when that happens.

## Next
Phase 09 verifies workflow + Dependabot as part of release readiness.
