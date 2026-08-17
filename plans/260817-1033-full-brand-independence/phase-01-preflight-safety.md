# Phase 01 — Pre-flight Safety Net & Confirm Gate

## Context links

- Plan: [plan.md](./plan.md)
- Research: [researcher-01 — GitHub detach/rename](./research/researcher-01-github-detach-rename.md)
- Scout: [scout-01 — residual branding surface](./scout/scout-01-residual-branding-surface.md)

## Overview

Build the rollback surface, snapshot everything the detach will destroy, then stop
and get an explicit user go/no-go. **Nothing irreversible happens in this phase.**

## Key Insights

- Live check shows the detach blast radius is near-zero: 0 stars, 0 watchers, Issues
  disabled, 0 PRs, 0 releases, 0 child forks. The backup is cheap insurance, not a rescue op.
- The genuinely dangerous operation in this plan is the **`main` force-push** (Phase 02),
  not the detach. `origin/main` is in sync with local `main` → overwriting it is a
  remote-history rewrite.
- Backups must live on **origin**, not just locally — a local-only tag is not a backup.

## Requirements

- Backup tag + backup branch pushed to `origin` before any history rewrite.
- Machine-readable snapshot of repo metadata (stars, labels, branches, releases,
  settings) stored under the plan dir.
- Explicit, blocking user confirmation covering both irreversible acts (force-push, detach).

## Architecture

```
origin/main (current)
   ├─► tag    backup/main-pre-takeover-2026-08-17   (immutable snapshot)
   └─► branch backup/main-pre-takeover              (browsable, restorable)
plans/260817-1033-full-brand-independence/backup/
   ├── repo-metadata.json    gh repo view --json …
   ├── labels.json           gh label list --json
   ├── branches.txt          gh api …/branches
   ├── stargazers.txt        gh api …/stargazers
   └── issues-prs.json       gh issue/pr list --state all
```

## Related code files

| Path | Action | Note |
|---|---|---|
| `plans/260817-1033-full-brand-independence/backup/` | create | New dir for `gh` exports |
| (no source files touched) | — | Phase is git/`gh` only |

## Implementation Steps

1. Confirm clean tree: `git status --porcelain` — expect only `.codex/`, `.serena/`,
   `plans/260817-*` untracked. Stash or commit anything else first.
2. `git fetch --all --prune`; confirm `origin/main == main` (`git rev-parse main origin/main`).
3. Create the backup ref pair off the **current** `main`:
   ```bash
   git tag backup/main-pre-takeover-$(date +%Y-%m-%d) main
   git branch backup/main-pre-takeover main
   git push origin backup/main-pre-takeover-$(date +%Y-%m-%d) backup/main-pre-takeover
   ```
4. Verify both landed remotely: `git ls-remote origin 'refs/tags/backup/*' 'refs/heads/backup/*'`.
5. Export repo metadata (see commands in Verification). Commit the `backup/` dir on the
   rebrand branch so it travels with the plan.
6. Record current grep baselines into the backup dir (used as before/after evidence in Phase 04):
   ```bash
   git grep -o "Usage4Claude"            -- . ':!plans' ':!build' | wc -l   # expect 666
   git grep -o "f-is-h/Usage4Claude"     -- . ':!plans' ':!build' | wc -l   # expect 196
   git grep -o "quangyendn/Usage4Claude" -- . ':!plans' ':!build' | wc -l   # expect 22
   ```
7. **CONFIRM GATE — present to the user, wait for an explicit "yes" before Phase 02 starts.**

## Todo list

- [ ] Clean/verify working tree; `git fetch --all --prune`
- [ ] Create + push `backup/main-pre-takeover-<date>` tag
- [ ] Create + push `backup/main-pre-takeover` branch
- [ ] Verify both refs via `git ls-remote`
- [ ] Export repo metadata, labels, branches, stargazers, issues/PRs to `backup/`
- [ ] Record grep baselines (666 / 196 / 22)
- [ ] Commit `backup/` dir
- [ ] **[USER][BLOCKING]** Present the confirm gate; get explicit approval

## The Confirm Gate (verbatim script to show the user)

> Two irreversible actions ahead. Approve each explicitly.
>
> **A. Force-push `main`** (Phase 02) — `origin/main` history is overwritten by the
> `feat/rebrand-usagepacecc` line. 4 commits currently unique to `main` disappear from
> the main line. Audit says only `.serena/` (agent tooling, present on disk untracked)
> is genuinely lost; the linear-graph feature is already on the rebrand branch as a
> superset. Recoverable from `backup/main-pre-takeover`.
>
> **B. Leave fork network** (Phase 05) — PERMANENT. Cannot be undone, ever. Destroys
> fork-network metadata, stars, watchers, issues, PRs, wiki. Verified current state:
> **0 stars, 0 watchers, Issues disabled, 0 PRs, 0 releases, 0 child forks** — so actual
> loss is ≈ nothing. Not reversible even so.
>
> Proceed with A? Proceed with B?

## Confirm Gate — ANSWERED (2026-08-17)

| Item | Answer |
|---|---|
| **A. Force-push `main`** (Phase 02) | **APPROVED** |
| **B. Leave fork network** (Phase 05) | **APPROVED** — proceed with detach, then rename |

Observed grep baselines (supersede the phase-file estimates):
`Usage4Claude` = **666** (matches), `f-is-h/Usage4Claude` = **196** (matches),
`quangyendn/Usage4Claude` = **23** (plan said 22 — `docs/UPSTREAM_SYNC.md` and
`docs/CODE_SIGNING.md` landed after the scout baseline). **Phase 04 must use 23.**

## Success Criteria

- [ ] `git ls-remote origin | grep backup/main-pre-takeover` returns 2 refs (tag + branch)
- [ ] `plans/260817-1033-full-brand-independence/backup/` contains 5 export files, committed
- [ ] Grep baselines recorded
- [ ] User has answered A and B explicitly (recorded in the plan dir or the session)

## Verification commands

```bash
git rev-parse main origin/main backup/main-pre-takeover            # all equal
git ls-remote origin 'refs/tags/backup/*' 'refs/heads/backup/*'

B=plans/260817-1033-full-brand-independence/backup; mkdir -p $B
gh repo view quangyendn/Usage4Claude --json name,description,homepageUrl,isFork,parent,\
stargazerCount,forkCount,watchers,hasIssuesEnabled,hasWikiEnabled,visibility,diskUsage,defaultBranchRef \
  > $B/repo-metadata.json
gh label list  --repo quangyendn/Usage4Claude --json name,color,description > $B/labels.json
gh api repos/quangyendn/Usage4Claude/branches --jq '.[].name'              > $B/branches.txt
gh api repos/quangyendn/Usage4Claude/stargazers --jq '.[].login'           > $B/stargazers.txt
{ gh issue list --repo quangyendn/Usage4Claude --state all --json number,title,state 2>&1;
  gh pr    list --repo quangyendn/Usage4Claude --state all --json number,title,state; } > $B/issues-prs.json
```

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Backup pushed from the wrong ref | High | Step 2 asserts `main == origin/main` before tagging; step 4 re-verifies remotely |
| User approves the gate without reading | Medium | Gate text states the concrete verified numbers, not vague warnings |
| Uncommitted local work lost during later rewrites | Medium | Step 1 hard-stops on a dirty tree |
| `gh` exports fail silently (Issues disabled → error) | Low | Redirect stderr into the export (`2>&1`) so the disabled state is recorded, not hidden |

## Security Considerations

- Exports contain only public metadata. No tokens, no `.p12`, no secrets.
- Do **not** export repo secrets or Actions variables into the plan dir.
- `.gitignore` already excludes `*.p12` / `*.cer` — keep it that way.

## Next steps

→ [Phase 02 — Branch takeover](./phase-02-branch-takeover.md). Do not start until the
confirm gate returns yes on item A.
