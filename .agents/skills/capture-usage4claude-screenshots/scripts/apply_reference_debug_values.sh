#!/usr/bin/env bash
set -euo pipefail

# Target the most recently started instance by default.  Set
# USAGE4CLAUDE_PID explicitly when a Debug build and release build coexist.
app_pid="${USAGE4CLAUDE_PID:-}"
if [[ -z "$app_pid" ]]; then
  app_pid="$(pgrep -n -x Usage4Claude || true)"
fi
if [[ -z "$app_pid" ]]; then
  echo "Usage4Claude is not running" >&2
  exit 3
fi

# Reference documentation screenshots use deterministic Debug percentages.
# This intentionally drives the live AX slider controls, never defaults write.
swift - "$app_pid" <<'SWIFT'
import Cocoa
import ApplicationServices

guard CommandLine.arguments.count == 2, let processID = Int32(CommandLine.arguments[1]) else {
    fputs("expected Usage4Claude PID\n", stderr)
    exit(2)
}

let names = [
    "Claude 5-Hour", "Claude 7-Day", "Claude Extra Usage", "Claude Opus 7-Day",
    "Claude Sonnet 7-Day", "Codex Primary", "Codex Secondary", "Codex Extra Usage"
]
let referenceValues = [66, 88, 66, 66, 66, 66, 88, 88]
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

func sliderValue(_ slider: AXUIElement) -> Int? {
    guard let value = attribute(slider, kAXValueAttribute) as? NSNumber else { return nil }
    return Int(value.doubleValue.rounded())
}

guard let window = (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first,
      let root = children(of: window).first,
      let scrollArea = children(of: root).first(where: { role(of: $0) == "AXScrollArea" }) else {
    fputs("Usage4Claude's custom General settings window is not open\n", stderr)
    exit(4)
}

let sliders = children(of: scrollArea).filter { role(of: $0) == "AXSlider" }
guard sliders.count >= referenceValues.count else {
    fputs("the eight Debug percentage sliders were not found; use a Debug build with Debug Mode enabled\n", stderr)
    exit(4)
}

for index in referenceValues.indices {
    let slider = sliders[index]
    let target = referenceValues[index]
    guard AXUIElementSetAttributeValue(slider, kAXValueAttribute as CFString, NSNumber(value: target)) == .success else {
        fputs("could not set \(names[index]) to \(target)\n", stderr)
        exit(5)
    }
    Thread.sleep(forTimeInterval: 0.1)
    guard sliderValue(slider) == target else {
        fputs("\(names[index]) did not become \(target)\n", stderr)
        exit(5)
    }
}

print("applied reference Debug usage values: \(referenceValues.map(String.init).joined(separator: ", "))")
SWIFT
