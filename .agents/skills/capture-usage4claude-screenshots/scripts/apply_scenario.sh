#!/usr/bin/env bash
set -euo pipefail

scenario="${1:-}"
case "$scenario" in
  claude|codex|both) ;;
  *) echo "usage: $0 <claude|codex|both>" >&2; exit 2 ;;
esac

# Target the most recently started instance by default.  USAGE4CLAUDE_PID is
# useful when a Debug build and a release build are deliberately running side
# by side for screenshot work.
app_pid="${USAGE4CLAUDE_PID:-}"
if [[ -z "$app_pid" ]]; then
  app_pid="$(pgrep -n -x Usage4Claude || true)"
fi
if [[ -z "$app_pid" ]]; then
  echo "Usage4Claude is not running" >&2
  exit 3
fi

# This intentionally uses the Accessibility tree instead of defaults write:
# changing the live controls updates the running app only, avoiding a restart
# and avoiding mutations to the release app's shared preferences store.
swift - "$app_pid" "$scenario" <<'SWIFT'
import Cocoa
import ApplicationServices

let arguments = CommandLine.arguments
guard arguments.count == 3, let processID = Int32(arguments[1]) else {
    fputs("expected Usage4Claude PID and scenario\n", stderr)
    exit(2)
}

let wanted: [Bool]
switch arguments[2] {
case "claude": wanted = [true, true, true, true, true, false, false, false]
case "codex":  wanted = [false, false, false, false, false, true, true, true]
case "both":   wanted = [true, true, true, false, false, true, true, true]
default:
    fputs("unknown scenario\n", stderr)
    exit(2)
}

let names = [
    "five_hour", "seven_day", "extra_usage", "seven_day_opus",
    "seven_day_sonnet", "codex_primary", "codex_secondary", "codex_extra_usage"
]
let app = AXUIElementCreateApplication(processID)

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return result == .success ? value : nil
}

func children(of element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func role(of element: AXUIElement) -> String {
    attribute(element, kAXRoleAttribute).map { "\($0)" } ?? ""
}

func isSelected(_ element: AXUIElement) -> Bool {
    (attribute(element, kAXSelectedAttribute) as? NSNumber)?.boolValue ?? false
}

func isChecked(_ element: AXUIElement) -> Bool {
    (attribute(element, kAXValueAttribute) as? NSNumber)?.boolValue ?? false
}

func isEnabled(_ element: AXUIElement) -> Bool {
    (attribute(element, kAXEnabledAttribute) as? NSNumber)?.boolValue ?? true
}

func press(_ element: AXUIElement, _ name: String) {
    guard isEnabled(element) else {
        fputs("\(name) is disabled; refusing to assume the click worked\n", stderr)
        exit(5)
    }
    guard AXUIElementPerformAction(element, kAXPressAction as CFString) == .success else {
        fputs("could not click \(name)\n", stderr)
        exit(5)
    }
    Thread.sleep(forTimeInterval: 0.15)
}

func settingsScrollArea() -> AXUIElement {
    guard let window = (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first,
          let root = children(of: window).first,
          let scrollArea = children(of: root).first(where: { role(of: $0) == "AXScrollArea" }) else {
        fputs("Usage4Claude's custom General settings window is not open\n", stderr)
        exit(4)
    }
    return scrollArea
}

func displayModeRadioGroup(in scrollArea: AXUIElement) -> AXUIElement {
    // The segmented icon-size control is also exposed as AXRadioGroup.  The
    // display mode group is therefore third in the raw AX tree.
    let groups = children(of: scrollArea).filter { role(of: $0) == "AXRadioGroup" }
    guard groups.count >= 3 else {
        fputs("display mode radio group was not found\n", stderr)
        exit(4)
    }
    return groups[2]
}

var scrollArea = settingsScrollArea()
var displayMode = displayModeRadioGroup(in: scrollArea)
let displayChoices = children(of: displayMode)
guard displayChoices.count == 2 else {
    fputs("display mode radio buttons were not found\n", stderr)
    exit(4)
}
if !isSelected(displayChoices[1]) {
    press(displayChoices[1], "custom display mode")
    scrollArea = settingsScrollArea()
    displayMode = displayModeRadioGroup(in: scrollArea)
    guard isSelected(children(of: displayMode)[1]) else {
        fputs("custom display mode did not become selected\n", stderr)
        exit(5)
    }
}

func limitButtons(in scrollArea: AXUIElement) -> [AXUIElement] {
    let buttons = children(of: scrollArea).filter { role(of: $0) == "AXButton" }
    guard buttons.count >= 8 else {
        fputs("the eight display-option buttons were not found\n", stderr)
        exit(4)
    }
    return Array(buttons.prefix(8))
}

// Circular item constraints can temporarily disable the last selected item.
// Enable every requested item first, then remove anything the scenario omits.
for index in wanted.indices where wanted[index] {
    let button = limitButtons(in: settingsScrollArea())[index]
    if !isSelected(button) {
        press(button, names[index])
        guard isSelected(limitButtons(in: settingsScrollArea())[index]) else {
            fputs("\(names[index]) did not become selected\n", stderr)
            exit(5)
        }
    }
}

for index in wanted.indices where !wanted[index] {
    let button = limitButtons(in: settingsScrollArea())[index]
    if isSelected(button) {
        press(button, names[index])
        guard !isSelected(limitButtons(in: settingsScrollArea())[index]) else {
            fputs("\(names[index]) remained selected\n", stderr)
            exit(5)
        }
    }
}

// The detail popover must honor the custom selection, rather than its smart
// fallback used by the menu-bar-only option.
scrollArea = settingsScrollArea()
let scrollChildren = children(of: scrollArea)
guard let displayIndex = scrollChildren.firstIndex(where: { CFEqual($0, displayMode) }),
      let menuBarOnly = scrollChildren.dropFirst(displayIndex + 1)
          .first(where: { role(of: $0) == "AXCheckBox" }) else {
    fputs("menu-bar-only checkbox was not found\n", stderr)
    exit(4)
}
if isChecked(menuBarOnly) {
    press(menuBarOnly, "menu-bar-only")
    guard !isChecked(menuBarOnly) else {
        fputs("menu-bar-only remained enabled\n", stderr)
        exit(5)
    }
}

let finalButtons = limitButtons(in: settingsScrollArea())
for index in wanted.indices {
    guard isSelected(finalButtons[index]) == wanted[index] else {
        fputs("final AX state mismatch for \(names[index])\n", stderr)
        exit(5)
    }
}
print("applied \(arguments[2])")
SWIFT
