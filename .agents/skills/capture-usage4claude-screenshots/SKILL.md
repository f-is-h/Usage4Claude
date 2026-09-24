---
name: capture-usage4claude-screenshots
description: Produce every Usage4Claude interface image used by the READMEs and docs. Renders the real SwiftUI views offscreen with ImageRenderer — no app launch, no screen capture, no synthetic mouse events, no Accessibility permission. Use when asked to refresh README images, add a new documented scene or language, change mock data, adjust image sizing or naming, wire images into the READMEs, or debug the renderer.
---

# Usage4Claude Documentation Images

Everything the READMEs show of the app is rendered, not captured.
`scripts/render_docs_images.sh` compiles the whole app plus
`scripts/docs-images/main.swift` into a command-line tool and draws the real
SwiftUI views into PNGs. It is deterministic, needs no GUI, and does not disturb
whoever is using the machine.

```sh
./scripts/render_docs_images.sh [output-dir]      # default: docs/images
```

One run emits **28 files**: 7 languages × 2 scenes × light/dark. Expect a couple of
minutes — the tool is rebuilt from scratch every time.

Render into a scratch directory first, look at the results, and only then write to
`docs/images/`. Never overwrite the committed images with an unreviewed batch.

## Output And Where It Goes

All images live in `docs/images/`.

| File | Size | Used by |
| --- | --- | --- |
| `hero.<lang>.<variant>@2x.png` | 950×348pt | README first screen |
| `settings.display.<lang>.<variant>@2x.png` | 540×1244pt (CJK) / 540×1257pt (Latin) | README interface section |

- `<lang>` is `en`, `ja`, `zh-CN`, `zh-TW`, `ko`, `fr`, `de`. These follow the existing
  `docs/images` and `README.zh-CN.md` spelling and deliberately differ from
  `AppLanguage`'s raw values (`zh-Hans`, `zh-Hant`). The mapping lives in
  `docsLanguageCode`.
- `<variant>` is `light` or `dark`.
- `@2x` matches `renderer.scale = 2`; always display at the logical point width so the
  image stays crisp without being upscaled.
- Settings heights differ by language because the descriptions wrap differently. That is
  expected; do not treat it as a defect.

Path references differ by README: the root `README.md` uses `docs/images/…`, while
`docs/README.<lang>.md` uses `images/…`.

## README Integration

Pair the variants and let the browser pick:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/hero.zh-CN.dark@2x.png">
  <img src="images/hero.zh-CN.light@2x.png" width="948" alt="Usage4Claude">
</picture>
```

GitHub's README content area is about 948px wide inside the 1012px container.

- **Hero**: `width="948"`, at the very top, in place of a large app icon. The icon already
  appears twice inside the image; repeating it above only pushes the product below the fold.
- **Settings**: `width="500"`. The page renders full height (~1250pt) rather than being
  clipped to the real 550pt window, so every card is visible — including ones a user would
  have to scroll for. Narrower than 500 makes the body text too small to read.

To preview, serve a mock README page over HTTP (`python3 -m http.server`) and open it in
the browser pane. `file://` renders as a static snapshot that page tools cannot drive.
Check dark mode **in that page**, never from the standalone PNG.

## How The Pipeline Is Wired

Four non-obvious things make it work; breaking any one yields blank or broken output.

1. **The entry file must be named `main.swift`.** Swift only allows top-level code there.
2. **Sparkle must come from the SPM artifact.** `MenuBarManager` imports it, and the copy
   embedded in `Usage4Claude.app/Contents/Frameworks` has its `Headers`/`Modules` stripped
   by Xcode. The script globs DerivedData for `Sparkle.xcframework/macos-arm64_x86_64`.
3. **`@main` is stripped from a copy of `ClaudeUsageMonitorApp.swift`.** The original is
   never modified.
4. **The binary runs from inside the app bundle** (`Contents/MacOS/`), which is what makes
   `Bundle.main` resolve to the app so `Assets.xcassets` and the seven `.lproj` folders load.

The script picks the app bundle by **modification time**, and rebuilds when any source is
newer than the binary. Do not change this to sort by name: `build/` accumulates version
directories, the alphabetically last one is not necessarily the newest, and rendering
against a stale bundle silently produces images with outdated strings and assets.

## Adding A Scene

In `scripts/docs-images/main.swift`, inside the language loop:

1. Add mock data to `MockUsage` if needed (see the data rules).
2. Set `UserSettings.shared` to the state the scene needs.
3. **Render to a bitmap with `renderImage(...)` immediately, before touching settings again.**
4. Compose and `write(...)` with the `<name>.<code>.<variant>@2x.png` convention.

Reset any setting the previous scene changed. Scenes run in sequence and share one
`UserSettings`, so a scene that forgets to reset inherits the last one's state.

Adding a language means extending `docsLanguageCode` and `heroLabels`. The hero captions
live in the renderer, not in the app's `Localizable.strings` — that file is for strings
the UI actually shows.

## Pitfalls

Each of these cost real debugging time.

### Views read settings lazily

SwiftUI views read `UserSettings.shared` **when they render**, not when they are
constructed. Building two views under different settings and rendering them together makes
both use whatever is in effect at render time — the first side-by-side hero came out with
two pace graphs for this reason. Always `renderImage(...)` per scene, then compose bitmaps.

### Never judge a render from a standalone PNG thumbnail

Dark-variant PNGs are transparent and draw white content; viewers composite transparency
onto white, so white text, hairlines and the monochrome icon all look **missing**. Small
elements are just as deceptive — a 20pt icon in a 950pt canvas is easy to misread.
This produced several rounds of chasing bugs that did not exist.

Use the bundled previewer before concluding anything is wrong. It needs no dependencies —
this is a Swift repo, `swift` runs a single file directly. Do **not** install Pillow or
ImageMagick for this.

```sh
S=.agents/skills/capture-usage4claude-screenshots/scripts/preview_on_background.swift

# whole image on GitHub's dark background (use ffffff for light)
swift $S docs/images/hero.zh-CN.dark@2x.png /tmp/check.png 0d1117

# top 50pt only, enlarged 3x — for the menu bar icon and other small elements
swift $S docs/images/hero.zh-CN.dark@2x.png /tmp/check.png 0d1117 50
```

### `ImageRenderer` cannot draw AppKit-backed controls

They render as a yellow "unsupported" block. `Usage4Claude/Helpers/DocsRenderMode.swift`
holds the stand-ins, all inert in the shipping app:

- `DocsRenderMode.isActive` — the flag.
- `DocsScrollView` — `ScrollView` renders its content as **blank**, with no error. Out of
  scroll mode the content lays out fully and the enclosing frame clips it.
- `DocsSegmentedPicker` — replaces `.pickerStyle(.segmented)`. Size it to its content;
  `NSSegmentedControl` does not stretch to fill the row.
- `UsageDetailView.menuButtonLabel(rotated:)` — replaces the three-dot `Menu`.

When writing a stand-in, copy what the control **looks like on screen**, not what its
source says. That `Menu` label carries `.rotationEffect(.degrees(90))` which AppKit
ignores, so the replica must not rotate.

`SettingsView` also drops its fixed height under `DocsRenderMode` so the whole page renders.

### Monochrome menu bar icons need two fixes

The template icon is an alpha mask and the app leaves tinting to macOS. Offscreen there is
no system tinting, and the mask mixes two colour sources: rings use dynamic
`NSColor.labelColor`, digits use a hardcoded `NSColor.black`. Under a dark appearance the
rings turn white while the digits stay black.

Both halves are required:

- Generate with `NSApp.appearance` pinned to `.aqua` (`monochromeMenuBarIcon`) for a
  uniformly black mask.
- Tint in SwiftUI with `.renderingMode(.template)` + `foregroundStyle`.

`colorInvert()` flips opaque regions too and turns the rings into solid blocks. Tinting the
`NSImage` itself (`lockFocus` + `sourceAtop`, or rebuilding a bitmap rep) yields an image
that exports to PNG correctly but renders empty through SwiftUI.

### Shadows belong on an opaque background shape

Applying `.shadow` to content shadows **every** element in it. With a transparent content
area each card, radio dot and checkbox casts its own shadow and the window reads as several
floating pieces. `WindowChrome` paints an opaque window background and puts the shadow on
the shape behind it; `PopoverChrome` draws the arrow and card as one `Shape` for the same
reason — separate views let the shadow trace the arrow's slanted edges.

### The dual-provider layout needs debug mode

`isMultiProviderActive` normally requires real accounts for both providers. Under `DEBUG`
it also accepts `debugModeEnabled == true` plus a custom display set containing both
providers' limit types. Use that instead of faking credentials.

### The renderer shares the real app's UserDefaults

`Bundle.main` is the app bundle, so the process reads and writes the release app's
preference domain. Every setting it touches is snapshotted and restored in a `defer`;
**add new settings to that tuple** or the user's app is left in screenshot state.

Light/dark is pinned with `-AppleInterfaceStyle Light|Dark` on the command line instead of
being written. `NSArgumentDomain` outranks everything and never touches disk, so output
does not depend on the machine's current appearance.

## Mock Data Rules

Numbers are chosen, not arbitrary. They live in `MockUsage`.

- **The pace graph must demonstrate itself.** Its x axis is elapsed window time and the
  diagonal is an even burn rate, so put one point clearly above the diagonal and one clearly
  below, separated horizontally. `resetsAt` drives x: `elapsedRatio = 1 - remaining / window`.
- **Vary the percentages.** A column of identical numbers reads as unfilled placeholder data.
- **Anchor reset times to the current hour** (`MockUsage.anchor`). Using `Date()` directly
  makes the minutes differ on every run, so every re-render produces a meaningless diff.
  Renders within the same hour are identical; across hours they still differ. Pinning it
  completely would need the views to pass an injected `now` down to `UsagePaceGraphMath` —
  the parameter exists, the views just do not use it.
- **Codex's 7-day reset is deliberately off the hour.** That window comes from
  `reset_after_seconds` so it lands on an arbitrary minute, and the UI formats it with
  minute precision while Claude's hour-precision `resets_at` does not. A round `:00` there
  looks like an inconsistent format.

## Scene Inventory

**Hero** — two groups side by side in one PNG, each a menu bar icon between two hairlines
with the popover hanging below. Left: Claude, ring graph, colour menu bar icon with app
icon. Right: Claude + Codex, pace graph, monochrome icon, percentages only. The pair
carries the caption text.

No wallpaper, no clock, no traffic lights, no fake system chrome anywhere — it ages badly
and this is a product illustration, not a screen capture. The only synthetic parts are the
hairlines and the popover/window chrome that AppKit would otherwise provide.

**Settings** — the Display tab at full height, in `WindowChrome`. Reset the settings to a
representative default first (colour theme, icon + percentage, medium size, smart display,
ring graph); otherwise the shot inherits the hero's monochrome/pace state.

## Retired

`scripts/` in this skill now holds only `preview_on_background.swift`.
The CleanShot capture flow that used to live here is gone, along with
`capture_usage4claude_window.sh`, `capture_current_display_all_languages.sh`,
`apply_scenario.sh` and `apply_reference_debug_values.sh`. It drove the real cursor,
needed Accessibility permission for the agent process, and was fragile by its own
admission. If a scene is missing, extend the renderer rather than reviving it.
