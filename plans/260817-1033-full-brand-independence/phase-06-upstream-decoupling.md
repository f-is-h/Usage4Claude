# Phase 06 — Upstream Decoupling (Manual-Only Watch) + Signing Cleanup

**Final in-scope phase.** The plan is "done" when this phase passes; Phases 07 and 08 are
deferred.

## Context links

- Plan: [plan.md](./plan.md)
- Scout: [scout-01 §E, §G](./scout/scout-01-residual-branding-surface.md)
- Existing docs: `/Users/yennq/Projects/opensrc/Usage4Claude/docs/UPSTREAM_SYNC.md`,
  `/Users/yennq/Projects/opensrc/Usage4Claude/docs/CODE_SIGNING.md`
- Depends on: [Phase 05](./phase-05-github-identity.md) (repo renamed)

## Overview

Two concerns, both **repo-side cleanup that removes machinery pretending to do something
it does not**:

**A — Upstream decoupling.** Keep the upstream remote and the sync machinery, but downgrade
the weekly cron to **`workflow_dispatch` only** ("thỉnh thoảng check"), and rewrite
`docs/UPSTREAM_SYNC.md` for an occasional-manual model under the new repo identity.

**B — Signing cleanup (decision V3).** CI imports a code-signing certificate that
`scripts/build.sh` then ignores. Remove the no-op step, delete the two now-unused secrets,
and correct `docs/CODE_SIGNING.md` to say plainly that builds are ad-hoc-signed. This is
the *repo* half of the signing work — creating the actual certificate and publishing the
first release stays in the deferred [Phase 07](./phase-07-signing-release.md).

## Key Insights

- The user wants the option, not the noise. Deleting `upstream-watch.yml` would throw away
  working machinery; keeping cron creates weekly draft-PR churn on a repo that now diverges
  heavily. `workflow_dispatch`-only is the correct middle.
- Removing `schedule:` also removes GitHub's 60-day inactivity auto-disable behavior for
  scheduled workflows — one less silent failure mode.
- Post-Phase-03, the fork's source dir is `UsagePaceCC/` while upstream stays
  `Usage4Claude/` → **every** future cherry-pick touching source files conflicts on path.
  This must be documented now, with the concrete recipe, or the mechanism rots.
- `upstream-mirror` already exists on origin; labels `security` + `upstream-sync` already
  exist; only `dependencies` is missing.
- `UPSTREAM_SYNC.md` has 13 old-brand refs and 9 `quangyendn/Usage4Claude` refs. Phase 04
  Pass A already fixed the `quangyendn/…` ones; this phase rewrites the prose.
- Upstream repo name is `f-is-h/Usage4Claude` and stays — never rewrite `UPSTREAM_REPO`.
- **Signing (V3):** `release.yml` imports `CODESIGN_CERTIFICATE`/`CODESIGN_PASSWORD` into a
  keychain, then calls `scripts/build.sh`, which forces `CODE_SIGN_IDENTITY="-"` — so the
  import has never affected a single artifact. It is pure ceremony, and worse, it keeps two
  live secrets around for nothing. The decision is **(a) remove**, not "make it real": a
  self-signed certificate gives a CI artifact no Gatekeeper benefit over ad-hoc signing.
- `docs/CODE_SIGNING.md` currently implies CI produces signed builds. That is false today
  and stays false. Saying so plainly is the point of the doc edit — this is the third time
  the ambiguity has been carried forward.

## Requirements

### A — Upstream decoupling

- No `schedule:` block in `upstream-watch.yml`; `workflow_dispatch` retained.
- `env.UPSTREAM_REPO` still `f-is-h/Usage4Claude` (correct, do not touch).
- `docs/UPSTREAM_SYNC.md` reflects: new repo name, manual-only cadence, path-rename
  cherry-pick recipe, `dependencies` label creation.
- A manual dispatch run passes on the renamed repo.

### B — Signing cleanup

- No cert-import step in `.github/workflows/release.yml`.
- `CODESIGN_CERTIFICATE` and `CODESIGN_PASSWORD` deleted from the repo's secrets.
- `docs/CODE_SIGNING.md` states plainly that builds are ad-hoc-signed
  (`scripts/build.sh` forces `CODE_SIGN_IDENTITY="-"`) and that **Gatekeeper will warn
  users**, who must right-click → Open on first launch.
- `scripts/build.sh` is **unchanged** — it already does the right thing.
- A release-workflow run still succeeds after the step is removed.

## Architecture

```
on:
- schedule:                 ← DELETE
-   - cron: "0 8 * * 1"     ← DELETE
  workflow_dispatch: {}     ← KEEP (sole trigger)
```

Everything below the trigger (mirror ff, sync branch, draft PR, label logic, issue
fallback) stays unchanged.

New sync model documented:

```
occasionally (user-initiated)
  gh workflow run upstream-watch.yml --repo quangyendn/UsagePaceCC
    → 0 new upstream commits  → no-op
    → N new commits           → draft PR upstream-sync/<date>, labelled
  human triages; cherry-picks with path remap; logs the reviewed SHA
```

## Related code files

| Path | Action | Change |
|---|---|---|
| `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/upstream-watch.yml` | modify | remove `schedule:` + cron (top of file); keep `workflow_dispatch` |
| `/Users/yennq/Projects/opensrc/Usage4Claude/docs/UPSTREAM_SYNC.md` | rewrite | header repo names, topology diagram, one-time-setup → "already done", cadence section, path-remap recipe, sync log |
| `/Users/yennq/Projects/opensrc/Usage4Claude/.github/dependabot.yml` | verify | Actions ecosystem weekly — keep; confirm `dependencies` label referenced |
| `/Users/yennq/Projects/opensrc/Usage4Claude/.github/workflows/release.yml` | modify | **delete** the "Import code signing certificate" step (and any `CODESIGN_*` env wiring feeding it) |
| `/Users/yennq/Projects/opensrc/Usage4Claude/docs/CODE_SIGNING.md` | rewrite (partial) | state ad-hoc signing + Gatekeeper warning as fact; drop the CI-signing narrative and the secrets setup section |
| `/Users/yennq/Projects/opensrc/Usage4Claude/scripts/build.sh` | **no change** | already forces `CODE_SIGN_IDENTITY="-"` — leave it |

## Implementation Steps

1. Edit `.github/workflows/upstream-watch.yml`: delete the `schedule:` key and its cron
   entry, leaving:
   ```yaml
   on:
     workflow_dispatch: {}
   ```
   Leave `env.UPSTREAM_REPO: "f-is-h/Usage4Claude"` and `UPSTREAM_BRANCH: "main"` alone.
   Add a one-line comment: manual-only by design.
2. Validate the YAML: `gh workflow view upstream-watch.yml --repo quangyendn/UsagePaceCC`
   after pushing, or `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/upstream-watch.yml'))"`.
3. Create the missing label:
   ```bash
   gh label create dependencies --color 0075ca --description "Dependency updates" \
     --repo quangyendn/UsagePaceCC   # ignore "already exists"
   ```
4. Rewrite `docs/UPSTREAM_SYNC.md`:
   - Header: `**Fork:** quangyendn/UsagePaceCC` / `**Upstream:** f-is-h/Usage4Claude` /
     updated date.
   - Topology diagram: label the fork line `main (UsagePaceCC)`.
   - "One-Time Setup" → **"Setup (already completed)"**, with a verification block instead
     of instructions: `upstream-mirror` exists, labels exist, security features enabled.
   - Replace "Automated Workflow / weekly" with **"On-Demand Upstream Check"**:
     ```bash
     gh workflow run upstream-watch.yml --repo quangyendn/UsagePaceCC
     gh run list --workflow=upstream-watch.yml --repo quangyendn/UsagePaceCC
     ```
     Suggested cadence: whenever you feel like it; every 1–3 months is fine. State plainly
     that there is **no schedule** and nothing will remind you.
   - **New section — "Path renames since the fork diverged"**:
     | Upstream path | Fork path |
     |---|---|
     | `Usage4Claude/…` | `UsagePaceCC/…` |
     | `Usage4Claude.xcodeproj` | `UsagePaceCC.xcodeproj` |
     | `Usage4Claude*.xcscheme` | `UsagePaceCC*.xcscheme` |
     Recipe:
     ```bash
     git cherry-pick -x -X find-renames <sha>
     # if it still conflicts on path:
     git format-patch -1 <sha> --stdout \
       | sed 's|a/Usage4Claude/|a/UsagePaceCC/|g; s|b/Usage4Claude/|b/UsagePaceCC/|g' \
       | git apply --3way
     ```
     Record the Phase 03 step-8 dry-run result here.
   - **New section — "Divergence reality"**: the fork adds Codex provider support,
     rebranding, and a renamed source tree; upstream fixes touching those areas will rarely
     apply cleanly. Prefer re-implementing small fixes by hand over fighting a cherry-pick.
   - Keep: cherry-pick-vs-merge rationale, troubleshooting, last-synced-SHA log table.
   - Fix the "Customizing the schedule" section → delete it (no schedule exists).
5. Commit: `docs: switch upstream watch to manual dispatch and rewrite sync guide`. Push.
6. **[USER]** Dispatch a verification run:
   ```bash
   gh workflow run upstream-watch.yml --repo quangyendn/UsagePaceCC
   gh run list  --workflow=upstream-watch.yml --repo quangyendn/UsagePaceCC --limit 1
   gh run view <run-id> --repo quangyendn/UsagePaceCC --log
   ```
   Expected: no-op if upstream has not moved, else a draft PR labelled `upstream-sync`.
   If a draft PR is created, close or triage it — do not leave it dangling.
7. Confirm the schedule is gone: `gh api repos/quangyendn/UsagePaceCC/actions/workflows`
   → the upstream watch workflow has no scheduled trigger; no future scheduled runs listed.

### B — Signing cleanup (V3)

8. Locate and delete the cert-import step in `.github/workflows/release.yml`:
   ```bash
   grep -n "CODESIGN_\|security create-keychain\|import\|codesign" .github/workflows/release.yml
   ```
   Remove the whole step (its `name`, `run`, and the `env:` block passing
   `CODESIGN_CERTIFICATE` / `CODESIGN_PASSWORD`). Leave every other step untouched, and do
   **not** touch `scripts/build.sh`. Verify nothing else references the secrets:
   ```bash
   git grep -n "CODESIGN_" -- .github/ scripts/    # → 0 hits after the edit
   ```
9. Rewrite the signing story in `docs/CODE_SIGNING.md` so it matches reality:
   - Lead with the fact: **all builds — local and CI — are ad-hoc-signed.**
     `scripts/build.sh` forces `CODE_SIGN_IDENTITY="-"`; there is no Developer ID and no
     notarization.
   - **Gatekeeper will warn users.** First launch requires right-click → Open (or
     System Settings → Privacy & Security → Open Anyway). State this without hedging — it
     is what every downloader will hit.
   - Delete the "set up `CODESIGN_CERTIFICATE`/`CODESIGN_PASSWORD` secrets" instructions;
     they now describe a step that no longer exists.
   - Keep the "Future: proper distribution signing" section as the explicit path out
     (Apple Developer ID + notarization), marked as not-done.
   - Fix the stale repo note at L98–100: the repo is `quangyendn/UsagePaceCC` and the
     `.xcodeproj` **is** renamed (Phase 03). Phase 04 swept only the brand tokens in this
     file and deliberately left this note to you.
   - Note that `project.pbxproj` still names `UsagePaceCC-CodeSigning` for **local Xcode GUI
     builds only**, and that the certificate does not exist yet — creating it is the
     deferred Phase 07. `scripts/build.sh` and CI are unaffected by its absence.
10. Commit: `ci: drop no-op code-signing certificate import` +
    `docs: state ad-hoc signing plainly in CODE_SIGNING.md`. Push.
11. Confirm the release workflow still runs green with the step gone — the next push to
    `main` covers this, or dispatch it explicitly:
    ```bash
    gh run list --workflow=release.yml --repo quangyendn/UsagePaceCC --limit 1
    ```
12. **[USER]** Delete the now-unused secrets (do this **after** step 11 proves the workflow
    no longer needs them):
    ```bash
    gh secret delete CODESIGN_CERTIFICATE --repo quangyendn/UsagePaceCC
    gh secret delete CODESIGN_PASSWORD    --repo quangyendn/UsagePaceCC
    gh secret list --repo quangyendn/UsagePaceCC    # neither appears
    ```

## Todo list

### A — Upstream decoupling

- [ ] Remove `schedule:` + cron from `upstream-watch.yml`; add "manual-only" comment
- [ ] Validate workflow YAML
- [ ] Create `dependencies` label
- [ ] Rewrite `docs/UPSTREAM_SYNC.md` (header, topology, setup→verify, on-demand section)
- [ ] Add "Path renames since divergence" section with the remap recipe
- [ ] Add "Divergence reality" section
- [ ] Delete the "Customizing the schedule" section
- [ ] Commit + push
- [ ] **[USER]** Manual dispatch run; triage any draft PR
- [ ] Verify no scheduled trigger remains

### B — Signing cleanup

- [ ] Delete the cert-import step from `.github/workflows/release.yml`
- [ ] `git grep "CODESIGN_" -- .github/ scripts/` → 0
- [ ] `scripts/build.sh` left untouched (confirm it still forces `CODE_SIGN_IDENTITY="-"`)
- [ ] Rewrite `docs/CODE_SIGNING.md`: ad-hoc signing stated plainly, Gatekeeper warning
      stated plainly, secrets-setup instructions removed, stale repo note fixed
- [ ] Commit + push; confirm `release.yml` still runs green
- [ ] **[USER]** `gh secret delete CODESIGN_CERTIFICATE` + `CODESIGN_PASSWORD`

## Success Criteria

- [ ] `grep -c "cron" .github/workflows/upstream-watch.yml` → 0
- [ ] `grep -c "workflow_dispatch" .github/workflows/upstream-watch.yml` → 1
- [ ] `env.UPSTREAM_REPO` still `f-is-h/Usage4Claude`
- [ ] `gh label list` shows `security`, `upstream-sync`, `dependencies`
- [ ] `docs/UPSTREAM_SYNC.md` contains zero `quangyendn/Usage4Claude`; names `quangyendn/UsagePaceCC`
- [ ] One successful manual dispatch run recorded
- [ ] Path-remap recipe present and validated against a real upstream commit
- [ ] `git grep "CODESIGN_" -- .github/ scripts/` → 0 hits
- [ ] `gh secret list` shows neither `CODESIGN_CERTIFICATE` nor `CODESIGN_PASSWORD`
- [ ] `docs/CODE_SIGNING.md` says builds are ad-hoc-signed and Gatekeeper warns; no
      instructions for secrets that no longer exist
- [ ] `release.yml` runs green without the import step
- [ ] **Plan-level:** with this phase green, the plan is done. 07 and 08 stay deferred.

## Verification commands

```bash
grep -n "on:\|cron\|workflow_dispatch\|UPSTREAM_REPO" .github/workflows/upstream-watch.yml
git grep -c "quangyendn/Usage4Claude" -- docs/UPSTREAM_SYNC.md   # → no match
gh label list --repo quangyendn/UsagePaceCC
gh workflow run upstream-watch.yml --repo quangyendn/UsagePaceCC
gh run list --workflow=upstream-watch.yml --repo quangyendn/UsagePaceCC --limit 1

git grep -n "CODESIGN_" -- .github/ scripts/          # → 0
grep -n 'CODE_SIGN_IDENTITY' scripts/build.sh          # → still forces "-"
grep -in "ad-hoc\|gatekeeper" docs/CODE_SIGNING.md     # → both stated
gh secret list --repo quangyendn/UsagePaceCC
```

## Rollback

Each concern is its own commit → `git revert` isolates them. Restoring the cron is one
line if the manual model proves too easy to forget. Restoring the cert-import step means
reverting the CI commit **and** re-creating both secrets — the secret values are not
recoverable from git, so only delete them after step 11 proves the workflow is green.

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Upstream security fix goes unnoticed for months | Medium | Accepted trade-off (explicit user decision). Mitigate by naming a rough cadence in the doc; Dependabot still covers Actions deps automatically |
| Manual dispatch fails because upstream was renamed/archived | Low | Fails loudly on a user-initiated run — the intended detection point. Doc's troubleshooting covers it |
| Cherry-picks become unusable due to path divergence | Medium | Path-remap section + `format-patch | sed | git apply --3way` fallback; "re-implement by hand" guidance |
| Doc rewrite drops the sync log | Low | Explicitly listed as "keep" in step 4 |
| Removing the import step breaks the release build | Low | The step is provably a no-op (`build.sh` forces `-`); step 11 runs the workflow before the secrets are deleted |
| Secrets deleted while something still needs them | Low | Step 12 is gated on step 11 being green; `git grep "CODESIGN_"` → 0 first. Values are unrecoverable once deleted — order matters |
| Users hit Gatekeeper with no explanation | Medium | The whole point of the doc rewrite: state the warning and the right-click → Open workaround plainly. Release notes repeat it when the deferred Phase 07 ships |

## Security Considerations

- Slower upstream security uptake is the real cost of decoupling — state it plainly in the
  doc so future-you does not assume coverage.
- Workflow permissions stay `contents/issues/pull-requests: write` with `GITHUB_TOKEN` only.
  No PAT. Do not widen.
- The workflow only ever opens **draft** PRs; never enable auto-merge on upstream-sync PRs.
- Deleting `CODESIGN_CERTIFICATE` / `CODESIGN_PASSWORD` **reduces** exposure: two live
  secrets that nothing consumes are pure liability. Confirm they were never echoed into a
  workflow log before deleting, and treat the underlying `.p12` (if one exists locally) as
  a credential to destroy or store offline.
- Ad-hoc signing is honest, not secure: it provides no provenance guarantee. Do not let
  `docs/CODE_SIGNING.md` imply otherwise.

## Next steps

**This is the last in-scope phase — the plan is complete when it passes.** Mark `plan.md`
status `completed`.

Deferred, not part of this run:
→ [Phase 07 — Code-signing cert + first release](./phase-07-signing-release.md) *(deferred)*
→ [Phase 08 — Website rebrand](./phase-08-website.md) *(deferred)*
