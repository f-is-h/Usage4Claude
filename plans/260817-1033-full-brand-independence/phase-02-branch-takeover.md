# Phase 02 — Branch Takeover: `main` = Rebrand Line

## Context links

- Plan: [plan.md](./plan.md) (see "Branch Takeover Audit" — audit is pre-computed)
- Depends on: [Phase 01](./phase-01-preflight-safety.md) — confirm gate item A must be YES

## Overview

Make `feat/rebrand-usagepacecc` the new `main`, locally and on `origin`. Prove first
that nothing on the old `main` is lost. `origin/main` is in sync with local `main`, so
this is a **force-push / remote history rewrite**.

## Key Insights

- `git cherry` flags 3 of 4 `main`-only commits as unmatched by patch-id — **misleading**.
  Patch-id mismatch ≠ content missing. The rebrand branch carries the same features via
  different commits (it diverged at `356c15c` and re-landed the work alongside the Codex
  provider additions).
- Content audit (already run during planning):
  - `LinearUsageGraphView.swift` exists on **both**; rebrand version is a superset
    (adds `.codexPrimary`, `.codexSecondary`, `.codexExtraUsage` cases).
  - `GraphDisplayType` occurrence counts identical on both branches
    (`UserSettings.swift` ×3, `GeneralSettingsView.swift` ×1).
  - `cfa427a` matches by patch-id (`git cherry` shows `-`).
  - 11 `docs/images/*.png` that look main-only are pure renames into `docs/images/old/`.
- **Only genuine main-only tracked content: `.serena/` (6 files)** — agent tooling,
  currently present on disk as untracked. Nothing else. **Decision V5 is settled: do NOT
  re-track them.** The takeover drops them from `main`, and `.gitignore` keeps them out.
- Re-run the audit anyway before pushing; the branch may have moved since planning.

## Requirements

- Re-verified content audit, output captured, before any rewrite.
- `main` fast-forwarded/reset to the rebrand line; `origin/main` force-pushed with lease.
- `.gitignore` contains `.serena/` and `.codex/`; the 6 `.serena/` files stay untracked.
- Default branch on GitHub stays `main` (no default-branch switch needed).

## Architecture

```
before:  origin/main ── ca794fb ─ 9ed35b9 ─ cfa427a ─ 6e677c4      (4 unique)
         origin/feat/rebrand-usagepacecc ── … ─ edc6155            (superset content)
                 both fork from 356c15c

after:   origin/main ── … ─ edc6155                                (= rebrand line)
         origin/backup/main-pre-takeover ── 6e677c4                (old line, preserved)
         feat/rebrand-usagepacecc                                  (kept or deleted, see step 8)
```

Method: **reset + force-push-with-lease**, not merge. A merge would drag the 4 old
commits back into history and re-introduce `.serena/` unintentionally.

## Related code files

| Path | Action | Note |
|---|---|---|
| `.gitignore` | modify | Add `.serena/` and `.codex/` — decided (V5), not conditional |
| (no source files touched) | — | Pure git-ref operation |

## Implementation Steps

1. Re-run the audit and capture output to the plan dir:
   ```bash
   git fetch --all --prune
   git cherry -v feat/rebrand-usagepacecc main
   diff <(git ls-tree -r --name-only main) \
        <(git ls-tree -r --name-only feat/rebrand-usagepacecc) | grep '^<'
   ```
   Expect exactly: 6 × `.serena/*` and 11 × `docs/images/*.png`.
2. Prove the image files are renames, not deletions:
   ```bash
   git diff --stat -M main..feat/rebrand-usagepacecc -- docs/images/ | grep '{ => old}' | wc -l   # 11
   ```
3. Prove feature parity on the graph work:
   ```bash
   git grep -c GraphDisplayType main -- Usage4Claude/ 
   git grep -c GraphDisplayType feat/rebrand-usagepacecc -- Usage4Claude/     # identical
   git diff main..feat/rebrand-usagepacecc -- Usage4Claude/Views/Components/LinearUsageGraphView.swift
   # expect additive-only: codexPrimary / codexSecondary / codexExtraUsage cases
   ```
4. Ignore the agent-local tooling directories (**decided — V5**; do not re-track the 6
   `.serena/` files):
   ```bash
   printf '\n# Local agent tooling\n.serena/\n.codex/\n' >> .gitignore
   git add .gitignore
   git commit -m "chore: ignore local agent tooling directories"
   ```
   Commit this on `feat/rebrand-usagepacecc` **before** step 6, so the new `main` carries it.
5. Verify neither directory is tracked and both are ignored:
   ```bash
   git ls-files .serena .codex          # → empty
   git check-ignore -v .serena/ .codex/ # → both matched by .gitignore
   ```
6. Move `main`:
   ```bash
   git checkout main
   git reset --hard feat/rebrand-usagepacecc
   ```
7. **[IRREVERSIBLE-ish]** Force-push with lease:
   ```bash
   git push --force-with-lease=main:$(git rev-parse origin/main) origin main
   ```
   `--force-with-lease` aborts if `origin/main` moved since the fetch in step 1.
8. Keep `feat/rebrand-usagepacecc` for now (cheap safety). Delete it only after Phase 05
   verification passes: `git push origin --delete feat/rebrand-usagepacecc`.
9. Confirm GitHub still shows `main` as default branch:
   `gh api repos/quangyendn/Usage4Claude --jq .default_branch` → `main`.
10. Confirm `upstream-watch.yml` now appears in the workflow list (it lived only on the
    rebrand branch before): `gh workflow list --repo quangyendn/Usage4Claude`.

## Todo list

- [ ] Re-run and capture the 3 audit commands (steps 1–3)
- [ ] Confirm main-only delta == `.serena/` only (images are renames)
- [ ] Add `.serena/` + `.codex/` to `.gitignore`; commit (V5 — no decision left to make)
- [ ] Verify `git ls-files .serena .codex` is empty and `git check-ignore` matches both
- [ ] `git checkout main && git reset --hard feat/rebrand-usagepacecc`
- [ ] **[IRREVERSIBLE]** `git push --force-with-lease` to `origin main`
- [ ] Verify default branch still `main`
- [ ] Verify `upstream-watch.yml` now registered as a workflow
- [ ] Leave `feat/rebrand-usagepacecc` in place until Phase 05 passes

## Success Criteria

- [ ] `git rev-parse main origin/main feat/rebrand-usagepacecc` → three identical SHAs
- [ ] `git ls-tree -r --name-only origin/backup/main-pre-takeover | grep '^\.serena'` → 6 files (old line intact)
- [ ] `git check-ignore -v .serena/ .codex/` matches both; `git ls-files .serena .codex` empty
- [ ] `gh api repos/quangyendn/Usage4Claude --jq .default_branch` → `main`
- [ ] `gh workflow list` shows both `Build and Release` and the upstream watch workflow
- [ ] Audit output captured in the plan dir

## Verification commands

```bash
git rev-parse main origin/main feat/rebrand-usagepacecc | uniq | wc -l   # → 1
git log --oneline -1 origin/main                                         # → edc6155-or-later
git log --oneline -1 origin/backup/main-pre-takeover                     # → 6e677c4
diff <(git ls-tree -r --name-only origin/backup/main-pre-takeover) \
     <(git ls-tree -r --name-only origin/main) | grep '^<' | grep -v '^< \.serena'   # → empty*
```
\* modulo the `docs/images/` rename pairs, which show as `<`/`>` line pairs.

## Rollback

```bash
git checkout main
git reset --hard origin/backup/main-pre-takeover
git push --force-with-lease origin main
```
Valid until someone else force-pushes over `origin/main`. The backup tag from Phase 01
is immutable and remains the last-resort source.

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Force-push destroys work not captured by the audit | High | Phase 01 backup tag+branch on origin; audit re-run immediately before push; rollback recipe above |
| `--force-with-lease` bypassed by a stale fetch | Medium | `git fetch --all --prune` in step 1 immediately precedes the push; lease pinned to the fetched SHA |
| Merge used instead of reset → old commits + `.serena/` sneak back | Medium | Method is explicitly reset; step 1 audit re-checked post-push |
| Branch protection rejects force-push | Low | None configured today; if it appears, temporarily disable, push, re-enable — record the toggle |
| Deleting the rebrand branch too early | Low | Step 8 defers deletion to post-Phase-05 |

## Security Considerations

- Force-push requires push rights only; no token scope change.
- Do not disable branch protection permanently to make the push convenient.

## Next steps

→ [Phase 03 — Xcode rename](./phase-03-xcode-rename.md). All subsequent work happens
on `main`.
