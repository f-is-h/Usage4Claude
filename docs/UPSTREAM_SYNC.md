# Upstream Sync — Procedure & Reference

**Fork:** `quangyendn/Usage4Claude`
**Upstream:** `f-is-h/Usage4Claude`
**Last updated:** 2026-06-21

---

## Branch Topology

```
upstream/main  ──────●──●──●──●──●──────────────►  (f-is-h releases)
                      \           \
upstream-mirror  ──────●──●──●──●──●──────────────►  (ff-only mirror, never commit here)
                                     \
main  ────────────────────────────────●──●──●──►  (fork rebrand; diverges here)
                                          |
                              upstream-sync/YYYY-MM-DD  ──► (ephemeral review branch)
                              (created by CI, deleted after merge/close)
```

### Three permanent branches

| Branch | Purpose | Push policy |
|--------|---------|-------------|
| `upstream-mirror` | Exact fast-forward-only copy of `upstream/main` | Force-push allowed (mirror semantics) |
| `main` | Fork rebrand; receives cherry-picked upstream fixes | Normal push; NEVER auto-merged from upstream |
| `upstream-sync/<date>` | Ephemeral; created by CI for human-review PRs | Delete after merge or close |

**Key invariant:** `upstream-mirror` is NEVER merged into `main` directly. Commits flow via cherry-pick, individually reviewed by a human.

---

## One-Time Setup (User Runs These)

Run these commands once to bootstrap the `upstream-mirror` branch and GitHub labels.

### 1. Ensure remotes are configured

```bash
git remote -v
# Expected:
#   origin   git@github.com:quangyendn/Usage4Claude.git (fetch)
#   upstream https://github.com/f-is-h/Usage4Claude.git (fetch)

# If upstream is missing:
git remote add upstream https://github.com/f-is-h/Usage4Claude.git
```

### 2. Create and push the upstream-mirror branch

```bash
git fetch upstream
git checkout -b upstream-mirror upstream/main
git push -u origin upstream-mirror

# Return to your working branch
git checkout main   # or feat/linear-graph if active
```

Verify:

```bash
git ls-remote origin upstream-mirror
# Should print a SHA and refs/heads/upstream-mirror
```

### 3. Create GitHub labels

These labels must exist before the first workflow run; otherwise the workflow step that applies them will fail (the PR is still created, but unlabeled).

```bash
gh label create security      --color d73a4a --description "Security or vulnerability fix" --repo quangyendn/Usage4Claude
gh label create upstream-sync --color 0075ca --description "Automated upstream sync PR"   --repo quangyendn/Usage4Claude
gh label create dependencies  --color 0075ca --description "Dependency updates"            --repo quangyendn/Usage4Claude
# Ignore "already exists" errors — safe to re-run
```

### 4. Enable Dependabot and security features in GitHub UI

Go to **Settings > Code security and analysis** on `quangyendn/Usage4Claude` and enable:

- [x] Dependency graph
- [x] Dependabot alerts
- [x] Dependabot security updates

Dependabot is configured via `.github/dependabot.yml` (already committed). It monitors GitHub Actions pinned versions weekly.

### 5. First workflow dry-run (manual)

After the branch and labels are created:

```bash
gh workflow run upstream-watch.yml --repo quangyendn/Usage4Claude
```

Then watch the run:

```bash
gh run list --workflow=upstream-watch.yml --repo quangyendn/Usage4Claude
gh run view <run-id> --repo quangyendn/Usage4Claude
```

Expected behavior on first run after `f3446b9` merge: **zero new commits** (no-op exit). If upstream has moved ahead since then, a draft PR will be opened.

---

## Recurring Manual Cherry-Pick Recipe

Use these commands whenever you want to manually sync without waiting for the weekly workflow.

### Step 1 — Update the mirror

```bash
git fetch upstream
git checkout upstream-mirror
git merge --ff-only upstream/main   # fast-forward only; error if not possible
git push origin upstream-mirror
```

### Step 2 — Review new commits

```bash
# Commits on upstream not yet in main
git log main..upstream-mirror --oneline

# See full diff of everything new
git diff main...upstream-mirror
```

### Step 3 — Cherry-pick commits you want into main

```bash
git checkout main

# Pick one commit:
git cherry-pick -x <sha>

# Pick a range (oldest-first):
git cherry-pick -x <oldest-sha>^..<newest-sha>

# Pick the last N commits from upstream-mirror:
git cherry-pick -x upstream-mirror~N..upstream-mirror
```

The `-x` flag appends `(cherry picked from commit <sha>)` to the commit message, creating an audit trail.

### Step 4 — Handle already-applied commits (f3446b9 caveat)

The merge commit `f3446b9` (2026-06-21) already brought some upstream history into `main`. When cherry-picking a range that overlaps this merge, git will detect the commits as empty:

```
error: The previous cherry-pick is now empty, possibly due to conflict resolution.
```

Skip empty cherry-picks with:

```bash
git cherry-pick --skip
```

Or use `--allow-empty` if you explicitly want to record the intent:

```bash
git cherry-pick -x --allow-empty <sha>
```

### Step 5 — Tag the last reviewed upstream SHA

```bash
# After cherry-picking, tag the upstream-mirror HEAD you reviewed through:
git tag upstream-reviewed/$(date +%Y-%m-%d) upstream-mirror
git push origin upstream-reviewed/$(date +%Y-%m-%d)
```

This tag does NOT reflect the cherry-picked commit on `main` (SHA changes after cherry-pick), only that you reviewed upstream up to this point.

---

## Automated Workflow: upstream-watch.yml

**File:** `.github/workflows/upstream-watch.yml`

**Trigger:** Every Monday 08:00 UTC + `workflow_dispatch` (manual).

**What it does:**

1. Fetches `upstream/main`, `origin/upstream-mirror`, and `origin/main`.
2. Counts new commits on upstream not yet in the mirror (`origin/upstream-mirror..upstream/main`).
3. **Zero new commits** → exits cleanly (no-op).
4. **New commits found:**
   a. Fast-forwards `upstream-mirror` to `upstream/main` via force-with-lease.
   b. Creates an `upstream-sync/<date>` branch off `origin/main`.
   c. Cherry-picks the **first** commit in `origin/main..upstream/main` into that branch as a diff seed — avoids the `gh pr create` head==base rejection. (The range is computed against `origin/main`, not the mirror, because the mirror fast-forward in step a already advances `origin/upstream-mirror` to equal `upstream/main`, which would make the mirror-based range empty.)
   d. Opens a **DRAFT PR** titled `chore: upstream sync <date> (<N> new commits)`.
   e. Applies label `upstream-sync` always; also applies `security` if any commit message matches `fix|security|vuln|patch|cve|crash|bug|sanitiz|escape|inject`.
5. **Fallback:** If the PR creation fails (e.g., cherry-pick conflict left branch at base), falls back to opening a GitHub Issue listing the new commits.

**No auto-merge ever.** The PR stays draft until a human reviews and merges.

**Permissions used:** `contents: write` (push mirror), `issues: write`, `pull-requests: write`. Only `GITHUB_TOKEN` — no PAT required.

### Customizing the schedule

Edit the `cron` line in `.github/workflows/upstream-watch.yml`:

```yaml
on:
  schedule:
    - cron: "0 8 * * 1"   # Monday 08:00 UTC — change as needed
```

### Changing upstream branch name

If `f-is-h/Usage4Claude` renames its default branch, update the env var:

```yaml
env:
  UPSTREAM_BRANCH: main   # change to new branch name
```

---

## Cherry-Pick vs Merge — Rationale

**Cherry-pick is the default strategy for this fork.**

| Criterion | Cherry-pick | Merge |
|-----------|-------------|-------|
| Selectivity | Import only what you need | Imports everything |
| History cleanliness | Clean; each pick is atomic | Merge commits interleave histories |
| Conflict surface | Small (per-commit) | Large (all-at-once) |
| Rebrand safety | Minimal overlap with renamed files | High risk: upstream touches same files |
| Audit trail | `-x` flag records origin SHA | Merge commit records range |

**When to prefer merge:** If upstream ships a large security refactor across many interrelated files where individual cherry-picks are impractical, merge into a scratch branch (`upstream-merge-scratch`), resolve conflicts there, then squash-merge into `main`.

**Cadence recommendation:** Run sync at least every 2-3 weeks. Letting `upstream-mirror` drift more than a month increases conflict surface significantly.

---

## Last Synced SHA Log

Record each sync pass here so future cherry-picks know the reviewed baseline.

| Date | Upstream SHA reviewed through | Method | Notes |
|------|------------------------------|--------|-------|
| 2026-06-21 | `f3446b9` (fork commit, not upstream SHA) | `git merge upstream/main` | Pre-existing merge on `feat/linear-graph`; upstream/main HEAD at time of merge. Exact upstream SHA unknown — check `git log --merges --oneline` for details. |

**To find the upstream SHA at the time of f3446b9:**

```bash
git show f3446b9 --format="%P" | tr ' ' '\n' | tail -1
```

This prints the second parent (the upstream HEAD at merge time).

**Template for future log entries:**

```
| YYYY-MM-DD | <upstream-mirror HEAD sha> | cherry-pick | Picked: <sha1>, <sha2>; skipped: <sha3> (already in f3446b9) |
```

---

## Troubleshooting

### "fatal: 'upstream-mirror' is not a commit" on first workflow run

The `upstream-mirror` branch does not exist yet. Complete the one-time setup in the section above before running the workflow.

### gh pr create fails: "No commits between main and upstream-sync/..."

The cherry-pick in the workflow auto-seeds the branch to prevent this. If it still occurs (cherry-pick was aborted due to conflict), the workflow falls back to opening an Issue instead. Manually cherry-pick and open a PR from that branch.

### Cherry-pick is empty (already applied via f3446b9)

```bash
git cherry-pick --skip
```

### Force-push to upstream-mirror fails (lease mismatch)

Another process updated `origin/upstream-mirror` concurrently. Re-fetch and re-run:

```bash
git fetch origin upstream-mirror
```

The workflow uses `--force-with-lease` to catch this safely.

### Dependabot PRs appear for github-actions pinned SHAs

This is expected. Review and merge Dependabot PRs for action version bumps (e.g., `actions/checkout@v4` → newer SHA). These are low-risk and recommended.
