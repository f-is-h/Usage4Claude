#!/usr/bin/env bash
set -euo pipefail

target_name="${1:-}"
if [[ -z "$target_name" ]]; then
  echo "usage: $0 <output-filename.png>" >&2
  exit 2
fi

downloads_dir="${DOWNLOADS_DIR:-$HOME/Downloads}"
target_path="$downloads_dir/$target_name"
if [[ -e "$target_path" ]]; then
  echo "target already exists: $target_path" >&2
  exit 3
fi

before_latest="$(find "$downloads_dir" -maxdepth 1 -type f -name 'CleanShot *@2x.png' -print0 | xargs -0 ls -t 2>/dev/null | head -n 1 || true)"

find_bounds() {
  swift -e 'import CoreGraphics
if let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
  for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    if owner.contains("Usage4Claude"), layer == 101,
       let b = w[kCGWindowBounds as String] as? [String: Any],
       let x = b["X"] as? Int, let y = b["Y"] as? Int,
       let width = b["Width"] as? Int, let height = b["Height"] as? Int {
      print("\(x) \(y) \(width) \(height)")
      exit(0)
    }
  }
}
exit(1)'
}

bounds=""
for _ in {1..30}; do
  if bounds="$(find_bounds)"; then
    break
  fi
  sleep 0.1
done

if [[ -z "$bounds" ]]; then
  echo "Usage4Claude popover window was not found" >&2
  exit 5
fi

read -r x y width height <<< "$bounds"
center_x=$((x + width / 2))
center_y=$((y + height / 2))

swift -e "import CoreGraphics; import Darwin; let p = CGPoint(x: $center_x, y: $center_y); CGWarpMouseCursorPosition(p); usleep(250000); CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)"

/usr/bin/open 'cleanshot://capture-window?action=save'
sleep 0.8

swift -e "import CoreGraphics; import Darwin
let p = CGPoint(x: $center_x, y: $center_y)
CGWarpMouseCursorPosition(p)
usleep(400000)
let src = CGEventSource(stateID: .hidSystemState)
CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(200000)
CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(80000)
CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)"

after_latest=""
for _ in {1..50}; do
  after_latest="$(find "$downloads_dir" -maxdepth 1 -type f -name 'CleanShot *@2x.png' -print0 | xargs -0 ls -t 2>/dev/null | head -n 1 || true)"
  if [[ -n "$after_latest" && "$after_latest" != "$before_latest" ]]; then
    break
  fi
  sleep 0.1
done

if [[ -z "$after_latest" || "$after_latest" == "$before_latest" ]]; then
  echo "no new CleanShot @2x PNG appeared in $downloads_dir" >&2
  exit 4
fi

mv -n "$after_latest" "$target_path"
echo "$target_path"
