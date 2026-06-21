# Phase 05 — Rebrand: Icons & Visual Assets

## Context links
- plan.md → D4 (new icon decision)
- Scout §3

## Overview
Replace/refresh the app icon and packaging icons to visually distinguish the fork.
Depends only on Phase 02 (name). Can run parallel to Phase 04. The dynamic
menu-bar icon (drawn at runtime) is feature behavior — keep as-is (no removal).

## Insights (verified paths)
- AppIcon set: `Usage4Claude/Resources/Assets.xcassets/AppIcon.appiconset/` (16-1024 PNGs + Contents.json)
- Variants: `AppIconReverse.imageset/`, `CodexIcon.imageset/`, `CodexIconReverse.imageset/` (Codex icons are feature assets — KEEP unless rebranding their look too; default keep)
- Source icons: `docs/images/AppIcon.icns`, `icon@2x.png`, `icon.reverse@2x.png`, `DmgIcon.icns`, `icon.psd`(/.reverse.psd)
- Website icons: `website/favicon.ico`, `website/images/icon.png`
- Runtime icon renderers (DO NOT touch — feature): `App/MenuBarIconRenderer.swift`, `Helpers/ShapeIconRenderer.swift`, `Helpers/IconShapePaths.swift`

## Requirements (D4)
- Default: produce a recolored/placeholder variant of the existing icon so the fork is visually distinct and ships now; flag "commission final icon" as follow-up.
- Alternative: full new icon design.

## Files
- `Assets.xcassets/AppIcon.appiconset/*` (replace all sizes + verify Contents.json)
- `Assets.xcassets/AppIconReverse.imageset/*` (replace if reverse variant kept)
- `docs/images/AppIcon.icns`, `icon@2x.png`, `icon.reverse@2x.png`, `DmgIcon.icns` (regenerate)
- `website/favicon.ico`, `website/images/icon.png` (Phase 07 can also handle)

## Steps
1. Per D4, produce the master 1024×1024 icon (new or recolored).
2. Generate all AppIcon sizes (16,32,64,128,256,512,1024 @1x/@2x). Use `iconutil` or an icon-gen script; keep `Contents.json` filenames matching.
3. Regenerate `.icns` (`iconutil -c icns icon.iconset -o AppIcon.icns`) and `DmgIcon.icns`.
4. Update `docs/images/` source PNGs/PSD references.
5. (If not deferring website) update favicon + website icon.
6. Build → confirm new icon in Finder/Dock-less menu bar app + DMG volume icon.

## Todos
- [x] master icon produced (D4 path chosen — TEMPORARY recolor placeholder; bespoke design is user follow-up)
- [x] AppIcon.appiconset regenerated, Contents.json valid
- [x] reverse variant updated (if kept)
- [x] .icns + DmgIcon.icns regenerated
- [x] docs/images source assets updated
- [ ] website icons updated or deferred to Phase 07 <!-- DEFERRED: Phase 07 is out of initial scope; handle in Phase 07 when website work is resumed -->
- [x] build shows new icon

## Success
- App bundle shows new icon; DMG (Phase 06) uses new volume icon.
- No broken/missing image refs in asset catalog (build has no asset warnings).

## Risks
- Asset catalog filename/size mismatch → build warning or blank icon. Validate Contents.json.
- Reusing upstream icon recolored is a temporary measure — track final-design follow-up so the fork is not visually confusable with upstream long-term.

## Next
Phase 06 (build/CI) consumes DmgIcon; Phase 09 verifies.
