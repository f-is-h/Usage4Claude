---
name: capture-usage4claude-screenshots
description: Automate Usage4Claude interface screenshots with CleanShot X on macOS. Use when Codex needs to capture localized Usage4Claude menu-bar popover screenshots, switch Usage4Claude display/language settings, save files such as detail.claude.en@2x.png, or troubleshoot CleanShot/window-capture automation that depends on macOS Accessibility, osascript, CoreGraphics mouse movement, and the Usage4Claude Debug app.
---

# Capture Usage4Claude Screenshots

## Overview

Capture Usage4Claude popover screenshots by matching the user's manual CleanShot workflow: enter CleanShot window capture mode, hover the real mouse over the Usage4Claude popover, click, and rename the newly saved file in Downloads.

This workflow is fragile because CleanShot's window selector reacts to the real mouse position. Do not rely on app-relative Computer Use clicks for the final selection; use CoreGraphics to move the mouse to the window center and post a real click.

## Preflight

Confirm these before capturing:

- Use the Debug Usage4Claude instance when the user requests it.
- Verify `Codex` has macOS Accessibility permission. `Computer Use` alone is not enough for shell-launched `osascript`.
- Verify this succeeds before starting CleanShot:

```sh
osascript -e 'tell application "System Events" to get count of application processes'
```

If it fails with `not allowed assistive access` or `不允许辅助访问`, stop and ask the user to add Codex to System Settings > Privacy & Security > Accessibility.

## Configure Usage4Claude

Set the screenshot state in Usage4Claude settings before capture.

- Claude-only: enable Claude 5-Hour, 7-Day, Extra Usage, 7D Opus, and 7D Sonnet; disable all Codex items.
- Codex-only: enable all 3 Codex limits; disable all Claude items.
- Mixed: enable Claude's first 3 limits and all 3 Codex limits.
- Switch language only inside Usage4Claude settings. Do not change language by writing `UserDefaults` or by external app-level language overrides.
- Keep the Usage4Claude screenshot setting that prevents the popover from closing.

After changing settings, open the main Usage4Claude popover and inspect it with Computer Use. The screenshot should show the intended language and display items before CleanShot starts.

## Required Screenshot Matrix

Every full screenshot pass usually needs all supported languages for these three scenarios:

- `detail.claude.<lang>@2x.png`: Claude-only, with `five_hour`, `seven_day`, `extra_usage`, `seven_day_opus`, `seven_day_sonnet`.
- `detail.codex.<lang>@2x.png`: Codex-only, with `codex_primary`, `codex_secondary`, `codex_extra_usage`; no Claude types.
- `detail.both.<lang>@2x.png`: Claude + Codex, with Claude's first 3 types (`five_hour`, `seven_day`, `extra_usage`) and all 3 Codex types.

Supported screenshot filename language codes:

- `en` -> app language `en`
- `ja` -> app language `ja`
- `zh-CN` -> app language `zh-Hans`
- `zh-TW` -> app language `zh-Hant`
- `ko` -> app language `ko`
- `fr` -> app language `fr`

If the user asks for "all languages", capture in this order: `en`, `ja`, `zh-CN`, `zh-TW`, `ko`, `fr`.

When only one group is requested, do that group first and wait for user confirmation before continuing to the next scenario.

## Capture Workflow

Use the bundled script for the final capture whenever possible:

```sh
scripts/capture_usage4claude_window.sh detail.claude.en@2x.png
```

The script:

1. Records the current latest CleanShot file in `~/Downloads`.
2. Finds the on-screen Usage4Claude popover bounds with `CGWindowListCopyWindowInfo`.
3. Moves the real cursor to the popover center with `CGWarpMouseCursorPosition`.
4. Opens `cleanshot://capture-window?action=save`.
5. Moves the cursor to the popover center again and posts real mouse down/up events.
6. Detects the newly saved CleanShot file and renames it to the requested filename.

If the target file already exists, choose a temporary test name or ask before replacing it. Do not silently overwrite screenshots.

For repeatable language captures, open the settings window once, configure the requested display scenario there, then switch languages through the settings language radio group and capture the current popover:

```sh
scripts/capture_current_display_all_languages.sh claude
```

This required language workflow assumes the current display options already match the requested scenario. It only switches the app language via the settings UI and captures `detail.<scenario>.<lang>@2x.png`. Use this for language changes; do not switch languages by editing defaults.

## Manual Fallback

If the script needs to be reproduced manually, use these pieces.

Find the Usage4Claude popover bounds:

```sh
swift -e 'import CoreGraphics; if let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] { for w in windows { let owner = w[kCGWindowOwnerName as String] as? String ?? ""; if owner.contains("Usage4Claude") { print(owner, w[kCGWindowLayer as String] ?? "", w[kCGWindowBounds as String] ?? "") } } }'
```

Open CleanShot window capture and click the popover center:

```sh
center_x=<center_x_from_bounds>
center_y=<center_y_from_bounds>
osascript -e 'do shell script "/usr/bin/open '\''cleanshot://capture-window?action=save'\''"'
swift -e "import CoreGraphics; import Darwin; let p = CGPoint(x: $center_x, y: $center_y); CGWarpMouseCursorPosition(p); usleep(400000); let src = CGEventSource(stateID: .hidSystemState); CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap); usleep(200000); CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap); usleep(80000); CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)"
```

Replace `center_x` and `center_y` with the actual center from the current bounds.

## Verification

After capture:

- Compare `~/Downloads` before and after to identify the new file.
- Open the new image with `view_image` and confirm it is Usage4Claude, not Codex or Script Editor.
- Confirm the language and display mode match the requested scenario.
- Rename only the verified screenshot.

## Known Pitfalls From The First Run

Keep this short record in mind before debugging from scratch:

- Terminal having Accessibility permission does not prove Codex has it. The same `osascript` command can succeed in Terminal and fail inside Codex until Codex is added to Accessibility.
- `Computer Use` being enabled in Accessibility is not enough for shell-launched `osascript`; Codex itself also needs permission.
- Earlier experiments changed language by writing `UserDefaults` and restarting the app. Do not use that for real screenshot passes. The required workflow is to switch language in Usage4Claude settings itself.
- Computer Use clicks are useful for inspecting and interacting with app UI, but app-relative clicks are not reliable for CleanShot's system-level window picker.
- `System Events click at {x, y}` can return a Usage4Claude AX object while CleanShot still captures the wrong window. CleanShot window mode depends on the real cursor hover target, so move the cursor with CoreGraphics before clicking.
- Always record the latest Downloads file before capture. One earlier attempt found a new file that was not the intended screenshot, and another captured Codex instead of Usage4Claude.
- Do not overwrite an existing target like `detail.claude.en@2x.png` during testing. Use a `.test` filename unless the user explicitly approves replacement.
- If `screencapture -W` remains running, CleanShot is still waiting for window selection. Cancel it promptly before continuing.
- Usage4Claude can occasionally become unresponsive when rapidly automated through restart/open cycles. Do not force-kill it repeatedly. If the app stops responding to Computer Use or LaunchServices returns `-1712`, stop the batch, let the user restart the app, then continue with a gentler per-language flow.

Common failure signs:

- A screenshot of Codex means the final click did not use real mouse hover over Usage4Claude.
- A stuck `screencapture -W` process means CleanShot is still waiting for window selection. Cancel with Escape or stop only the stuck helper process that this workflow started.
- `osascript` failing while Terminal works means Codex, not Terminal, lacks Accessibility permission.
- `menu bar 2 ... invalid index` immediately after launch means the status item is not ready yet; wait and retry instead of looping rapid restarts.
