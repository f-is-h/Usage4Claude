# Release Notes

面向用户的发布说明。发版时 CI 提取**当前版本段落**（`## [X.Y.Z]` 到下一个 `## [` 之间），
同时用于两处：

- **Sparkle 应用内更新弹窗**（注入 `appcast.xml` 的 `<description>`）
- **GitHub Release 正文**（拼接 `.github/RELEASE_TEMPLATE.md` 的固定段落）

因此这里**只写用户可感知的现象**：口语化、去技术词，可在条目末尾致谢
`(thanks @author, #N)`。完整技术变更（含内部重构、CI、安全加固）记录在
[CHANGELOG.md](./CHANGELOG.md)，那份不进 Sparkle。

> 版本号权威源仍是 CHANGELOG.md（与 Xcode `MARKETING_VERSION` 校验一致）。
> 发版时本文件必须有对应的 `## [X.Y.Z]` 段落，否则 Sparkle / Release 正文会为空。

## [3.5.0] - 2026-09-24

### Added
- **Pace graph**: A new graph style shows each limit against how much of its window has passed, next to a line for even use. Above the line means you are using it faster than time is passing. Weekly limits can count weekdays only. Switch in Settings → Display → Graph Style (thanks @quangyendn and @ericnondahl, #85; proposed by @yenpvn, #20)
- **Custom notification thresholds**: Choose when you get notified: one threshold for the 5-hour limit and up to two each for weekly limits and extra usage, anywhere from 50% to 100%
- **Menu bar icon follows the used/remaining toggle**: Clicking the limit list now flips the menu bar icon too, with the same animation
- **Clearer temporary errors**: When a refresh fails, a small indicator appears next to the title instead of a banner that resized the window. Click it to see what went wrong and when the shown data was fetched

### Changed
- **Settings in five tabs**: Display, Data, Accounts, General and About, instead of one long page
- **Codex credits shown as a balance**: The credits icon now shows how many credits you have left, instead of a percentage that could only read 0 or 100
- **Codex reset announcement**: The badge now sits next to the Codex title, and clicking it shows the expected time and the announcement

### Fixed
- **"Too many requests" errors**: Smart refresh could send extra requests in quick bursts, get rate limited, and then keep retrying every minute. It now sends one request per refresh and waits longer after being rate limited (thanks @ericnondahl, #86; reported by @you3fen, #90)
- **Codex asking you to sign in again**: This happened most with ChatGPT's Advanced Security turned on. Codex now keeps its sign-in across restarts and renews it before asking you (thanks @ViRb3, #87, #88)
- **Codex usage disappearing after a network hiccup**: Codex now keeps showing your last usage, the same way Claude does
- **Unreadable numbers on a dark menu bar**: The menu bar icon now adapts its colors when the wallpaper makes the menu bar dark
- **Missed Codex reset announcements**: The badge now shows up as soon as a reset is announced, including announcements without a time
- **Onboarding failing after browser sign-in**: Signing in from the welcome window now completes, Codex can be added there too, and sign-in windows no longer cover your browser
- **Flickering icons and stray marks**: The Claude and Codex icons no longer blink when toggling, and an empty ring no longer flashes a dot

## [3.4.1] - 2026-09-04

### Fixed
- **Icons missing from the menu bar menu on macOS 27**: macOS 27 began hiding menu icons by default, which emptied the right-click menu of its icons and took the new-version badge with them
- **"Test Connection" signing you out of Codex**: Running the connection test could overwrite your saved Codex sign-in with an empty one and log the account out for good. If this has happened to you, signing in again from Settings fixes it
- **Being told to run diagnostics when the only fix was signing in again**: If a Claude sign-in was revoked or had expired, the app suggested running a connection test, which cannot restore it. It now says to sign in again
- **Connection test blaming your credentials when nothing was wrong**: For accounts signed in with OAuth, the test checked a kind of login those accounts do not use, so it always reported a failure and told people to re-authenticate accounts that were working perfectly well (reported by @pkakr, #84)
- **"Open Log Folder" opening an empty folder**: The app was never writing the log file that button points at. It now keeps a small log there, capped so it cannot grow on your disk, and the diagnostic report includes a recent excerpt (reported by @vyrti, #79)

### Added
- **Diagnostics can now tell when the app was shut down from outside**: If Usage4Claude disappears without warning, the next launch reports whether it quit normally or was killed by something else, such as the system reclaiming memory. That was the missing piece for reports of it vanishing on its own (reported by @vyrti, #79)

## [3.4.0] - 2026-09-04

### Added
- **Menu bar icon size**: Pick Compact, Standard or Prominent in Settings → General → Display. Menu bar height and eyesight vary, so the icons no longer come in one fixed size
- **Codex reset announcement badge (Beta)**: A badge appears next to the Codex ring when OpenAI has publicly announced a pending global usage reset. It shows announcements only, never a prediction, and can be turned off in settings

### Changed
- **Brief network errors no longer blank the popover**: A rate limit or dropped connection now keeps your last usage on screen with a small notice on top, instead of replacing everything with an error page (thanks @KurtGood, #75)

### Fixed
- **Free Tier and Team accounts wrongly told to sign in again**: Plans without a usage dashboard were reported as a credential problem, sending people to re-enter credentials that were fine. They now get a clear message explaining the plan does not provide usage data (thanks @yairixStudio, #80; reported by @genu, #74 and @Yohan-Janolin, #83)
- **Signing in to Codex failing with a connection error**: The browser could come back to a closed door if the sign-in window was recreated mid-flow. If it still gets stuck, you can now paste the callback link to finish (thanks @realjoenguyen, #77)
- **Accounts signed out after switching during a refresh**: Switching accounts while usage was refreshing could write one account's renewed credentials into another's, signing both out for good. Renewed credentials now always go back to the account that requested them
- **"Go to Settings" button missing outside English and Chinese**: The button now appears for sign-in errors in every language
- **Menu bar icon resizing when data loaded**: The icon no longer changes size the moment usage data arrives

## [3.3.0] - 2026-07-14

### Added
- **German localization**: Full German UI translation, README, and language switcher entry (thanks @schaitl, #66)
- **Per-model weekly usage rows**: Show weekly usage for any number of models (e.g. Opus, Sonnet, Fable), no longer limited to two fixed slots (thanks @Springs-Tea, #67)
- **Claude OAuth manual paste fallback**: When browser sign-in gets stuck, paste the callback link to complete sign-in (thanks @jessicalynn, #68)

### Fixed
- **Codex usage window mislabeling**: The 5-hour/7-day usage windows are no longer mislabeled
- **Missed usage warning notifications**: Notifications now show even while the app is open
- **Codex sign-in expiring unexpectedly**: Fixed an issue that could log some Codex accounts out too early
- **Menu bar icon not updating**: The icon now updates immediately when switching between light and dark mode
