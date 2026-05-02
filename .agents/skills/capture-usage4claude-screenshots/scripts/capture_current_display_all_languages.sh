#!/usr/bin/env bash
set -euo pipefail

scenario="${1:-}"
case "$scenario" in
  claude|codex|both) ;;
  *) echo "usage: $0 <claude|codex|both>" >&2; exit 2 ;;
esac

downloads_dir="${DOWNLOADS_DIR:-$HOME/Downloads}"
langs=(en ja zh-CN zh-TW ko fr)
indices=(1 2 3 4 5 6)

for lang in "${langs[@]}"; do
  target="$downloads_dir/detail.${scenario}.${lang}@2x.png"
  if [[ -e "$target" ]]; then
    echo "target already exists: $target" >&2
    exit 3
  fi
done

ensure_settings_and_language() {
  local idx="$1"
  osascript <<OSA
tell application "System Events"
  tell application process "Usage4Claude"
    if (count of windows) = 0 then
      click menu item 3 of menu 1 of menu bar item 2 of menu bar 1
      repeat 40 times
        if (count of windows) > 0 then exit repeat
        delay 0.1
      end repeat
    end if

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

for i in "${!langs[@]}"; do
  lang="${langs[$i]}"
  idx="${indices[$i]}"
  ensure_settings_and_language "$idx"
  sleep 0.4
  "$(dirname "$0")/capture_usage4claude_window.sh" "detail.${scenario}.${lang}@2x.png"
done
