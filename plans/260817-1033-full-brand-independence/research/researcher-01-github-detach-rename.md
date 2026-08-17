## Research Report: GitHub Fork Detachment, Repo Rename, and MIT Obligations for `Usage4Claude` → `UsagePaceCC`

### Summary
GitHub now offers a self-service "Leave fork network" button (Danger Zone in repo Settings) that permanently detaches a fork if it's public, under 1GB, and has no child forks — a Support ticket is only a fallback for repos that don't qualify. Renaming the repo creates automatic redirects for git/clone/API/web traffic, but GitHub Actions, GitHub Pages, and any hardcoded URLs (Sparkle appcast, Homebrew cask, raw.githubusercontent asset links) are NOT reliably redirected and must be updated manually. MIT only requires preserving the copyright notice + license text in copies of the code; it says nothing about naming/trademark, so renaming to "UsagePaceCC" is legally fine under MIT but could still raise brand-confusion concerns with the upstream author if not handled carefully.

### Key Findings

1. **Detaching a fork — self-service, in-app**
   - Path: repo **Settings → Danger Zone → "Leave fork network"**.
   - Requirements to qualify for self-service: fork is public, under 1GB, and has no child forks of its own. [GitHub Docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/detaching-a-fork)
   - Flow: click "Leave fork network" → check "I have read and understand these effects" → type the repo name to confirm → click "Leave fork network" again.
   - **Permanent and irreversible** — cannot reconnect to the fork network afterward.
   - **Lost on detach**: issues, pull requests, wikis, stars, watchers, comments, child forks, and other fork-network metadata are NOT retained by the new standalone repo.
   - **Preserved**: all git commit metadata (history, authors) is preserved; commits may still count toward contribution graphs if they meet GitHub's normal criteria.
   - Older/legacy path (repos that don't qualify — private, >1GB, or has child forks): must file a request via **GitHub Support** ("Fork" category ticket) asking them to detach the repository from its fork network; docs don't specify required ticket wording beyond identifying the repo and requesting detachment — treat this as the fallback only.
   - What changes for the *repo owner* practically after leaving the fork network: the repo stops showing "forked from f-is-h/Usage4Claude" banner, it's no longer counted in upstream's fork count, PRs can no longer be opened upstream directly from it via the "fork" relationship UI (still possible to PR by adding as remote manually), Issues/Discussions tabs are unaffected by detach itself (those are per-repo settings, not fork-network state) — but note detach does NOT restore/create Issues/Discussions if currently disabled; it only removes fork-network linkage.
   - Search indexing / discoverability: no documented change to GitHub code search visibility from detaching; detaching mainly affects UI relationship badges and metadata, not search ranking.
   - Unresolved: docs page fetched doesn't explicitly confirm behavior of existing PR/issue links between the two repos post-detach (i.e., do cross-repo PR links from upstream still resolve). Treat as needing live verification post-action.

2. **Renaming the repository**
   - GitHub auto-creates a redirect from `old-owner/old-name` to `new-owner/new-name` for: web UI, `git clone/fetch/push` over the old URL, and REST/GraphQL API calls. [GitHub Docs — Renaming a repository](https://docs.github.com/en/enterprise-server@3.18/repositories/creating-and-managing-repositories/renaming-a-repository) / [GitHub Blog — Repository redirects](https://github.blog/news-insights/product-news/repository-redirects-are-here/)
   - **Breaks / not auto-redirected**:
     - **GitHub Actions**: workflows referencing an action hosted at the old repo name fail with "repository not found" — GitHub explicitly does not redirect Action references.
     - **GitHub Pages**: Pages sites/URLs (github.io or custom domain) are NOT redirected; any docs site hosted via Pages breaks and must be manually reconfigured.
     - **Redirect is fragile**: if anyone (including a different user) later creates a new repo at the *old* name, the redirect breaks immediately and silently — no notification to the renaming owner.
   - Must manually update/verify:
     - Sparkle appcast URL (if the macOS app's auto-updater points at a GitHub raw/release URL under the old name) — raw.githubusercontent.com links generally do resolve through repo redirects, but release *asset download* URLs and Sparkle's own appcast XML feed itself, if hosted as a GitHub Release asset, should be re-verified post-rename since Sparkle clients cache the appcast URL locally in already-shipped app builds — old installs will keep hitting the old URL until they update.
     - Homebrew cask formula (`brew tap`/cask URL) — must be updated to new repo path; existing installed casks won't self-update the source URL.
     - Any hardcoded API endpoints in the app's own update-checker code (as distinct from Sparkle) — search codebase for `f-is-h/Usage4Claude` or `Usage4Claude` string literals used in URLs.
     - README/CI badges (workflow status badges use org/repo path in URL — broken image if not updated, though redirects generally cover simple badge shields since they hit the API/raw path).
   - Practical implication for this project: **the app's own auto-updater / any hardcoded GitHub URLs in Swift source must be grepped and updated manually before/at rename time** — this is the highest-risk break since already-distributed binaries can't be retroactively fixed.

3. **MIT license obligations after rebrand + rename**
   - MUST preserve: the original copyright notice and the full MIT permission/warranty text "in all copies or substantial portions of the Software" — i.e., keep the upstream author's copyright line in the LICENSE file (and/or file headers if originally present) even after renaming/rebranding. [MIT License text](https://gist.github.com/fbaierl/1d740a7925a6e0e608824eb27a429370), [GitHub Community Discussion #47161](https://github.com/orgs/community/discussions/47161)
   - Common/accepted practice: add your own copyright line *alongside* (before or after) the original — do not delete/replace the original author's line.
   - Optional: attribution in README ("based on / forked from f-is-h/Usage4Claude"), CHANGELOG credit, NOTICE file — not legally required by MIT but good practice and reduces confusion/goodwill risk.
   - **Pitfall — trademark/name is NOT covered by MIT.** MIT license grants rights to the *code*, not to the project *name* or *brand*. Renaming to "UsagePaceCC" is unrestricted by MIT itself, but if the upstream project name/logo were trademarked (not indicated here) separate trademark law could apply — irrelevant risk for this repo since there's no evidence of a registered trademark on "Usage4Claude", but worth noting as a general boundary. [Hacker News discussion — Microsoft forked MIT repo, changed copyright (controversy example)](https://news.ycombinator.com/item?id=29683471) illustrates the reputational (not legal) risk of altering/removing original copyright — reinforces "don't touch the original notice."

4. **Ordering: detach-then-rename vs rename-then-detach**
   - No GitHub doc explicitly states an ordering requirement; the two actions are independent settings (fork-network membership vs. repo name) and can technically be done in either order or same session.
   - **Recommended: detach first, then rename.**
     - Reasoning (not explicitly documented, inferred from mechanics): "Leave fork network" self-service eligibility depends on repo state (public, <1GB, no child forks) — doing it while the repo still has the old, well-known name and existing star/fork history is lower-risk since nothing about naming affects detach eligibility, so order doesn't affect *success* of detach.
     - The stronger reason to detach first: once detached, the repo is no longer shown as "forked from f-is-h/Usage4Claude" in GitHub's UI/API, which removes ambiguity before you also change the name — doing rename first while still shown as a fork could produce a confusing transitional state (new brand name + still-visible "forked from" banner) for any users/observers during the gap.
     - Detach is irreversible regardless of order, so there's no technical rollback benefit either way — the ordering choice here is about presentation clarity, not risk mitigation of the operations themselves.

### Recommendations
1. Grep the codebase now for hardcoded `f-is-h/Usage4Claude`, `Usage4Claude`, and any Sparkle appcast / raw.githubusercontent URLs before doing anything else — fix these in a release *before* renaming so already-shipped builds keep working via GitHub's URL redirect as a safety net.
2. Detach fork first (Settings → Danger Zone → Leave fork network), confirm eligibility (public, <1GB, no child forks) — this repo should qualify.
3. Then rename repo (Settings → repo name field) to reflect "UsagePaceCC".
4. Immediately after rename: update Homebrew cask, any Pages config, Actions references, README badges, and app's own update-checker endpoint; ship a new release with corrected appcast URL so existing installs migrate off the old URL.
5. In LICENSE file: keep original `f-is-h`/upstream copyright line intact, add a new line for the rebrand's own copyright — do not delete/replace the original.
6. Add a README note crediting the upstream project (optional but recommended, not an MIT requirement).

### Sources
- [GitHub Docs — Detaching a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/detaching-a-fork)
- [GitHub Docs — Detaching a fork (Enterprise Cloud)](https://docs.github.com/en/enterprise-cloud@latest/pull-requests/how-tos/work-with-forks/detaching-a-fork)
- [GitHub Community Discussion #157487 — Unable to Contact Support, Need to Detach Fork](https://github.com/orgs/community/discussions/157487)
- [github/docs Issue #42055 — "Detaching a fork" page doesn't mention "Leave fork network" button](https://github.com/github/docs/issues/42055)
- [github/docs Issue #36165 — Fork detaching docs should refer to the new "leave fork network" feature](https://github.com/github/docs/issues/36165)
- [GitHub Docs — Renaming a repository](https://docs.github.com/en/enterprise-server@3.18/repositories/creating-and-managing-repositories/renaming-a-repository)
- [GitHub Blog — Repository redirects are here!](https://github.blog/news-insights/product-news/repository-redirects-are-here/)
- [GitHub Community Discussion #54182 — Access to renamed Github repository](https://github.com/orgs/community/discussions/54182)
- [MIT License text (gist)](https://gist.github.com/fbaierl/1d740a7925a6e0e608824eb27a429370)
- [GitHub Community Discussion #47161 — If I made a fork, can I change name in MIT License?](https://github.com/orgs/community/discussions/47161)
- [Hacker News #29683471 — Microsoft forked MIT licensed repo and changed the copyright](https://news.ycombinator.com/item?id=29683471)

### Uncertainties
- Whether existing cross-repo PR/issue links between upstream and this fork continue to resolve after detach was not confirmed from primary docs — verify empirically post-action or check with a small test PR reference before relying on it.
- Exact required wording for a GitHub Support fork-detach ticket (fallback path) was not found in docs — only relevant if the repo somehow fails self-service eligibility (unlikely given repo is small and public).
- No explicit GitHub statement on ordering (detach vs rename) — recommendation above is inferred from mechanics, not a documented best-practice guide.
- Sparkle-specific redirect behavior for GitHub Release *asset* URLs after rename was not independently verified against GitHub's redirect docs (general redirect docs cover repo/API/git, not explicitly release-asset download links) — test this specifically before relying on old Sparkle appcast URLs continuing to work for existing installs.
