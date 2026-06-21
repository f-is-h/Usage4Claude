# Phase 09 — Final Verification & Release Dry-Run

## Context links
- plan.md → Acceptance Criteria
- All prior phases

## Overview
End-to-end gate: prove the rebrand is complete, features intact, license compliant,
update channel correct, and a release can be produced under the new name. Requires
Phases 01,03,04,05,06,08 done (07 optional).

## Insights
- Self-signed cert → Gatekeeper will warn on download; acceptable for v1 self-distribution (notarization is OQ4, out of scope).
- `feat/linear-graph` feature must remain present and working post-rebrand (no removal).

## Requirements
- All plan-level acceptance criteria satisfied.

## Steps
1. **Brand grep sweep** (must be clean except LICENSE credit + Phase-01 attribution + CHANGELOG history):
   ```bash
   grep -rn "f-is-h\|fi5h\|com.usage4claude\|usage4claude.pages.dev" \
     Usage4Claude/ scripts/ .github/ --include=*.swift --include=*.strings --include=*.sh --include=*.yml
   grep -rn "Usage4Claude" Usage4Claude/ --include=*.swift --include=*.strings
   ```
2. **License check**: `head -6 LICENSE` shows f-is-h 2025 + Yen NQ 2026; LICENSE present in built `.app`/DMG.
3. **Build + launch**: `bash scripts/build.sh` → DMG `UsagePaceCC-vX.Y.Z.dmg`; mount, launch app, menu bar shows `UsagePaceCC`, no crash.
4. **Feature regression** (no removal): verify usage refresh, popover countdown, smart-refresh modes, Codex usage, notifications, AND the `feat/linear-graph` linear-graph feature all work.
5. **Keychain**: confirm migration path (D3) — fresh creds save/persist across relaunch; if migration code used, test upgrade-in-place.
6. **Update channel**: trigger update check → confirm request hits `api.github.com/repos/quangyendn/Usage4Claude/releases/latest` (Console/Charles/log).
7. **About UI**: shows new name, Yen NQ, "based on f-is-h/Usage4Claude" link, "not affiliated with Anthropic" disclaimer, correct copyright; check ≥2 languages.
8. **Icon**: app + DMG volume show new icon; no asset-catalog warnings.
9. **Upstream-sync**: `gh workflow run upstream-watch.yml`; confirm clean run; `upstream-mirror` exists; Dependabot enabled; UPSTREAM_SYNC.md present.
10. **Release dry-run**: create a DRAFT GitHub release on `quangyendn/Usage4Claude` with the DMG attached (via `gh release create --draft`), verify asset name + notes template; do NOT publish unless user approves.

## Todos
- [ ] brand grep sweep clean
- [ ] LICENSE dual-copyright + ships in artifact
- [ ] build + launch + menu bar name OK
- [ ] all features incl. linear-graph regression-pass
- [ ] keychain migration verified
- [ ] update check hits quangyendn
- [ ] About attribution + disclaimer correct (multi-lang)
- [ ] new icon everywhere
- [ ] upstream-watch dry-run + Dependabot + docs OK
- [ ] draft release produced (not published)

## Success
- Every plan-level acceptance checkbox ticked. App is a clean, license-compliant,
  self-updating-from-fork rebrand with all features intact and a working upstream-sync.

## Risks
- A missed localization key or URL surfaces only at runtime → the multi-language About check + grep sweep are the safety net.
- Gatekeeper warning on self-signed DMG is expected; document for users (OQ4 / notarization deferred).
- Publishing release prematurely — keep DRAFT until user confirms name/icon final.

## Next
On user approval: publish release; optionally execute Phase 07 (website); track final-icon follow-up (D4).
