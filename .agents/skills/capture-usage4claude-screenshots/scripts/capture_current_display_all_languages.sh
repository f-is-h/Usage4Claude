#!/usr/bin/env bash
set -euo pipefail

scenario="${1:-}"
case "$scenario" in
  claude|codex|both) ;;
  *) echo "usage: $0 <claude|codex|both>" >&2; exit 2 ;;
esac

downloads_dir="${DOWNLOADS_DIR:-$HOME/Downloads}"
langs=(en ja zh-CN zh-TW ko fr de)
indices=(1 2 3 4 5 6 7)

for lang in "${langs[@]}"; do
  target="$downloads_dir/detail.${scenario}.${lang}@2x.png"
  if [[ -e "$target" ]]; then
    echo "target already exists: $target" >&2
    exit 3
  fi
done

ensure_settings_window() {
  osascript <<'OSA'
tell application "System Events"
  tell application process "Usage4Claude"
    if (count of windows) > 0 and not (exists scroll area 1 of group 1 of window 1) then
      click button 1 of window 1
      delay 0.2
    end if

    if (count of windows) = 0 then
      if exists pop over 1 of menu bar item 1 of menu bar 2 then
        click menu bar item 1 of menu bar 2
        delay 0.2
      end if

      repeat 5 times
        click menu bar item 1 of menu bar 2
        delay 0.3
        if exists pop over 1 of menu bar item 1 of menu bar 2 then exit repeat
      end repeat
      if not (exists pop over 1 of menu bar item 1 of menu bar 2) then error "Usage4Claude popover did not open"

      set moreMenu to menu button 1 of group 1 of pop over 1 of menu bar item 1 of menu bar 2
      click moreMenu
      delay 0.2
      set actionsMenu to menu 1 of moreMenu
      set opened to false
      repeat with actionItem in menu items of actionsMenu
        if (name of actionItem is not missing value) and ((count of menus of actionItem) = 0) then
          click actionItem
          set opened to true
          exit repeat
        end if
      end repeat
      if not opened then error "General Settings menu item was not found"

      repeat 40 times
        if (count of windows) > 0 and (exists scroll area 1 of group 1 of window 1) then exit repeat
        delay 0.1
      end repeat
    end if

    if not ((count of windows) > 0 and (exists scroll area 1 of group 1 of window 1)) then error "Usage4Claude General settings window was not found"
  end tell
end tell
OSA
}

ensure_settings_and_language() {
  local idx="$1"
  osascript <<OSA
tell application "System Events"
  tell application process "Usage4Claude"
    set s to scroll area 1 of group 1 of window 1
    click radio button ${idx} of radio group 6 of s
    delay 0.5

    if exists pop over 1 of menu bar item 1 of menu bar 2 then
      click menu bar item 1 of menu bar 2
      delay 0.4
    end if

    repeat 5 times
      click menu bar item 1 of menu bar 2
      delay 0.8
      if exists pop over 1 of menu bar item 1 of menu bar 2 then exit repeat
    end repeat
  end tell
end tell
OSA
}

ensure_settings_window
if [[ "${APPLY_REFERENCE_DEBUG_VALUES:-0}" == "1" ]]; then
  "$(dirname "$0")/apply_reference_debug_values.sh"
fi
"$(dirname "$0")/apply_scenario.sh" "$scenario"

for i in "${!langs[@]}"; do
  lang="${langs[$i]}"
  idx="${indices[$i]}"
  ensure_settings_and_language "$idx"
  sleep 0.4
  "$(dirname "$0")/capture_usage4claude_window.sh" "detail.${scenario}.${lang}@2x.png"
done
