# Research: Upstream Sync Strategy for Divergent Fork (quangyendn/Usage4Claude)

**Date:** 2026-06-21
**Upstream:** https://github.com/f-is-h/Usage4Claude
**Fork:** https://github.com/quangyendn/Usage4Claude

---

## 1. Branch Topology: Vendor Mirror + Divergent Main

### Model

```
upstream/main  ──────●──●──●──●──────────►  (f-is-h's releases)
                      \        \
upstream-mirror  ──────●──●──●──●──────────►  (local mirror, fast-forward only)
                                 \
main  ──────────────────────────●──●──●──►  (your rebrand, diverges here)
```

**Three permanent branches:**

| Branch | Purpose | Push policy |
|---|---|---|
| `upstream-mirror` | Exact copy of `upstream/main`; never commit here | Force-push allowed (mirror) |
| `main` | Your rebrand; cherry-picks from upstream-mirror | Normal push |
| `upstream-sync/<date>` | Ephemeral; created by CI for human-review PRs | Delete after merge |

### One-time setup

```bash
# Add upstream remote
git remote add upstream https://github.com/f-is-h/Usage4Claude.git
git fetch upstream

# Create the mirror branch that tracks upstream/main exactly
git checkout -b upstream-mirror upstream/main
git push -u origin upstream-mirror

# Confirm your divergent work is on main
git checkout main
```

### Recurring manual sync (when you want to cherry-pick)

```bash
# 1. Update mirror — fast-forward only, no local commits
git fetch upstream
git checkout upstream-mirror
git merge --ff-only upstream/main
git push origin upstream-mirror

# 2. Find commits on upstream not yet in main
git log main..upstream-mirror --oneline

# 3. Cherry-pick individual commits onto main
git checkout main
git cherry-pick <sha1> [<sha2> ...]

# 4. Or cherry-pick a range
git cherry-pick upstream-mirror~5..upstream-mirror
```

---

## 2. GitHub Actions Options for Automated Detection

### Maintained actions (as of 2026)

| Action | Last active | Auto-merges? | Opens PR? | Notes |
|---|---|---|---|---|
| `aormsby/Fork-Sync-With-Upstream-action` | ~2023, minimal maintenance | YES (force-push/merge) | No | Blunt: overwrites your branch. Not suitable for divergent fork |
| `tgymnich/fork-sync` | Archived / unmaintained | YES | No | Dead; skip |
| `github.com/marketplace/actions/upstream-sync` | Active 2024-2025 | Configurable | No | Can skip merge if no changes, but still merges |
| **Hand-rolled with `gh` CLI** | Always current | NO (your choice) | YES | Best fit for this use case |

**Verdict:** All third-party sync actions are designed for forks that want to auto-merge upstream, i.e., they do NOT preserve divergent history. For a rebranded fork, hand-rolled is the correct approach.

The `gh repo sync` CLI command also auto-merges — avoid using it on `main`.

---

## 3. Workflow: Weekly Upstream Watch (No Auto-Merge)

Save as `.github/workflows/upstream-watch.yml`.

```yaml
name: Upstream Watch

on:
  schedule:
    # Every Monday at 08:00 UTC
    - cron: "0 8 * * 1"
  workflow_dispatch: {}   # allow manual trigger

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  watch:
    name: Detect new upstream commits
    runs-on: ubuntu-latest
    timeout-minutes: 10

    env:
      UPSTREAM_REPO: f-is-h/Usage4Claude
      UPSTREAM_BRANCH: main
      MIRROR_BRANCH: upstream-mirror

    steps:
      - name: Checkout fork
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Add upstream remote and fetch
        run: |
          git remote add upstream https://github.com/${{ env.UPSTREAM_REPO }}.git
          git fetch upstream ${{ env.UPSTREAM_BRANCH }}
          git fetch origin ${{ env.MIRROR_BRANCH }}

      - name: Compare upstream vs mirror
        id: diff
        run: |
          # New commits on upstream not yet in our mirror
          NEW=$(git log origin/${{ env.MIRROR_BRANCH }}..upstream/${{ env.UPSTREAM_BRANCH }} --oneline)
          COUNT=$(git rev-list --count origin/${{ env.MIRROR_BRANCH }}..upstream/${{ env.UPSTREAM_BRANCH }})

          echo "new_count=$COUNT" >> $GITHUB_OUTPUT

          if [ "$COUNT" -eq 0 ]; then
            echo "No new upstream commits. Exiting."
            exit 0
          fi

          # Save commit list for issue/PR body (escape for multiline output)
          COMMITS_ESCAPED=$(echo "$NEW" | head -50)
          echo "commits<<EOF" >> $GITHUB_OUTPUT
          echo "$COMMITS_ESCAPED" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

          # Flag if any commit message looks security/fix related
          SECURITY_HITS=$(echo "$NEW" | grep -iE "(fix|security|vuln|patch|cve|crash|bug|sanitiz|escape|inject)" || true)
          if [ -n "$SECURITY_HITS" ]; then
            echo "has_security=true" >> $GITHUB_OUTPUT
            echo "security_hits<<EOF" >> $GITHUB_OUTPUT
            echo "$SECURITY_HITS" >> $GITHUB_OUTPUT
            echo "EOF" >> $GITHUB_OUTPUT
          else
            echo "has_security=false" >> $GITHUB_OUTPUT
          fi

      - name: Fast-forward mirror branch (no merge into main)
        if: steps.diff.outputs.new_count != '0'
        run: |
          git checkout -B ${{ env.MIRROR_BRANCH }} upstream/${{ env.UPSTREAM_BRANCH }}
          git push origin ${{ env.MIRROR_BRANCH }} --force-with-lease

      - name: Create sync branch for PR
        if: steps.diff.outputs.new_count != '0'
        id: branch
        run: |
          DATE=$(date +%Y-%m-%d)
          BRANCH="upstream-sync/$DATE"
          echo "branch=$BRANCH" >> $GITHUB_OUTPUT

          # Branch off main, then cherry-pick upstream-mirror range
          # This is a DRAFT PR — human must review before merging
          git checkout -b "$BRANCH" origin/main
          git push origin "$BRANCH"

      - name: Open PR for human review
        if: steps.diff.outputs.new_count != '0'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          DATE=$(date +%Y-%m-%d)
          BRANCH="${{ steps.branch.outputs.branch }}"
          COUNT="${{ steps.diff.outputs.new_count }}"
          COMMITS="${{ steps.diff.outputs.commits }}"
          HAS_SECURITY="${{ steps.diff.outputs.has_security }}"
          SECURITY_HITS="${{ steps.diff.outputs.security_hits }}"

          SECURITY_SECTION=""
          if [ "$HAS_SECURITY" = "true" ]; then
            SECURITY_SECTION="## SECURITY/FIX COMMITS DETECTED

\`\`\`
$SECURITY_HITS
\`\`\`

**Review these first.**

"
          fi

          LABEL_FLAG=""
          if [ "$HAS_SECURITY" = "true" ]; then
            LABEL_FLAG="--label security"
          fi

          BODY="## Upstream Sync — $DATE

Upstream [\`${{ env.UPSTREAM_REPO }}\`](https://github.com/${{ env.UPSTREAM_REPO }}) has **$COUNT new commit(s)** since last mirror sync.

$SECURITY_SECTION## All new commits

\`\`\`
$COMMITS
\`\`\`

## How to cherry-pick into main

\`\`\`bash
git fetch origin
git checkout main
# cherry-pick individual commits you want:
git cherry-pick <sha>
# or update mirror and pick a range:
git cherry-pick origin/upstream-mirror~${COUNT}..origin/upstream-mirror
\`\`\`

This PR branch (\`$BRANCH\`) was created from \`main\` as a staging area — it has **no changes yet**.
Cherry-pick commits here, push, then merge when satisfied.

> Auto-generated by upstream-watch workflow. Do NOT auto-merge."

          gh pr create \
            --draft \
            --title "chore: upstream sync $DATE ($COUNT new commits)" \
            --body "$BODY" \
            --base main \
            --head "$BRANCH" \
            $LABEL_FLAG || true

      - name: Open issue if PR creation fails (fallback)
        if: steps.diff.outputs.new_count != '0' && failure()
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          COUNT="${{ steps.diff.outputs.new_count }}"
          COMMITS="${{ steps.diff.outputs.commits }}"
          gh issue create \
            --title "Upstream has $COUNT new commits — manual sync needed" \
            --body "New commits on upstream:\n\`\`\`\n$COMMITS\n\`\`\`" \
            --label "upstream-sync"
```

**Key design decisions:**
- Runs weekly (Monday 08:00 UTC) + manual dispatch.
- `upstream-mirror` is updated via force-push — no rebase conflicts.
- A **draft PR** is opened from `main` with no changes; maintainer cherry-picks into that branch.
- Does NOT auto-merge anything into `main`.
- Requires only `GITHUB_TOKEN` (no PAT needed for same-repo PRs).

**Prerequisite:** Create a `security` label in your repo if you want the label auto-applied:
```bash
gh label create security --color d73a4a --repo quangyendn/Usage4Claude
gh label create upstream-sync --color 0075ca --repo quangyendn/Usage4Claude
```

---

## 4. Filtering Security / Fix Commits

### In the workflow (already included above)

Keyword grep on commit messages at detection time:
```
fix|security|vuln|patch|cve|crash|bug|sanitiz|escape|inject
```

Extend the regex in the `SECURITY_HITS` grep line as needed.

### Dependabot on the fork

Enable Dependabot alerts and security updates on your fork independently — upstream's security advisories do NOT propagate to forks automatically. Add `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "swift"    # or "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Go to **Settings > Security > Code security and analysis** in the fork repo and enable:
- Dependency graph
- Dependabot alerts
- Dependabot security updates

### GitHub Security Advisories

Upstream advisories are NOT forwarded to forks. Watch upstream manually:
- Star/Watch `f-is-h/Usage4Claude` with "All Activity" notifications.
- Or use the commit keyword scan above — most patches reference CVE or "fix" in message.

---

## 5. Cherry-Pick vs Merge Tradeoffs for This Fork

### Cherry-pick (recommended for this scenario)

**Pros:**
- Surgically import only the commits you want (bug fixes, security patches).
- Preserves clean `main` history without upstream feature bloat.
- No merge conflicts from divergent rebrand files.
- Each pick is an atomic, reviewable unit.

**Cons:**
- SHA changes — git treats cherry-picked commits as new; future picks may re-detect already-applied changes. Mitigate: keep a `UPSTREAM_SYNC.md` log of last synced SHA.
- If upstream fixes are tangled with features, you may need `git cherry-pick -x --no-commit` then manual edit.

### Merge (upstream-mirror into main)

**Pros:**
- Brings in everything at once; no need to identify individual commits.
- Better when upstream has many small interrelated fixes.

**Cons:**
- Creates a merge commit that interleaves divergent histories — messy log.
- Guaranteed conflicts on any file you've rebranded (app name, icons, strings).
- Each recurring merge compounds conflict risk; maintenance burden grows over time.

### Recommendation

Use **cherry-pick** as the default. Reserve merge only if upstream does a large security refactor across many files where cherry-picking individual commits is impractical. In that case, merge into a scratch branch, resolve conflicts there, then squash-merge into `main`.

**To minimize conflict pile-up:**
- Run the watch workflow weekly; don't let mirror drift more than 2-3 weeks.
- After each sync, tag the last upstream SHA you've reviewed:
  ```bash
  git tag upstream-reviewed/<date> upstream-mirror
  git push origin upstream-reviewed/<date>
  ```
- Keep your rebrand changes isolated in clearly named files/directories so cherry-picked upstream commits hit non-overlapping paths.

---

## Sources

- [aormsby/Fork-Sync-With-Upstream-action](https://github.com/aormsby/Fork-Sync-With-Upstream-action)
- [Strategies for friendly fork management — GitHub Blog](https://github.blog/developer-skills/github/friend-zone-strategies-friendly-fork-management/)
- [Cherry-picks vs backmerges — Runway Blog](https://www.runway.team/blog/cherry-picks-vs-backmerges-whats-the-right-way-to-get-fixes-into-your-release-branch)
- [Sync Forks to Upstream Using GitHub Actions — DEV Community](https://dev.to/github/sync-forks-to-upstream-using-github-actions-gle)
- [GitHub Community: Best Practices for Keeping a Forked Repository Up to Date](https://github.com/orgs/community/discussions/153608)
- [GitHub Docs: Workflow syntax — schedule](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)
- [Fork Sync Action — GitHub Marketplace](https://github.com/marketplace/actions/fork-sync)

---

## Unresolved Questions

1. Does `f-is-h/Usage4Claude` use GitHub Security Advisories or only in-commit disclosures? If the former, check if GHSA notifications reach fork watchers.
2. The `security` label auto-apply in the workflow requires the label to pre-exist — confirm it's created before first workflow run.
3. If upstream renames `main` to something else, the `UPSTREAM_BRANCH` env var in the workflow needs updating.
4. Swift Package Manager dependencies: does the fork pin the same SPM dependencies as upstream? If diverged, Dependabot may surface different alerts than upstream's.
5. The draft PR approach requires a branch with at least one push; the current workflow pushes an empty branch from `main`. Some `gh pr create` versions reject a PR where head == base with no diff — test this behavior in your specific repo before relying on it. Alternative: cherry-pick at least the first upstream commit automatically into the branch.
