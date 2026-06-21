# Icon Notes

## App icon (current)

The UsagePaceCC app icon is an **original bespoke design** (a blue→purple gradient
sparkline / area-chart on a dark rounded-square), installed 2026-06-21. It replaces
the earlier temporary recolor placeholder.

Generated from a single 1024×1024 master into all sizes:

| Path | Description |
|------|-------------|
| `Usage4Claude/Resources/Assets.xcassets/AppIcon.appiconset/*.png` | All AppIcon sizes (16–1024) — Dock/Finder/About |
| `docs/images/AppIcon.icns` | App bundle icon (ICNS) |
| `docs/images/DmgIcon.icns` | DMG volume icon (ICNS) |
| `docs/images/icon@2x.png` | 512px source PNG |

To regenerate after changing the master: resize the master to 1024×1024, then `sips -z <size> <size>`
into each AppIcon filename, and rebuild the `.icns` with an `.iconset` dir + `iconutil -c icns`.

## Menu-bar template icon — PENDING follow-up

`AppIconReverse.imageset/icon.reverse@2x.png` is a **template image**
(`template-rendering-intent: template`) used by `MenuBarIconRenderer.swift` for the
monochrome menu-bar icon. Templates use ONLY the alpha silhouette (color is ignored,
the system tints it).

The bespoke app icon above is a filled rounded-square, so it is **not** suitable as a
template (it would render as a solid blob in the menu bar). `AppIconReverse` was
therefore left as-is and still needs a dedicated **monochrome glyph** — ideally just
the sparkline shape on a transparent background — for a polished menu-bar appearance.

- [x] Bespoke AppIcon installed (Dock/Finder/About/DMG)
- [ ] **Pending:** dedicated monochrome menu-bar glyph for `AppIconReverse` (sparkline-only silhouette, transparent bg)
