# SwiftUI Canvas Path Drawing Guide

This document captures hard-won lessons from implementing custom icon shapes in
SwiftUI Canvas. It exists because we spent significant time debugging broken
arc directions that looked correct on paper but rendered as star/gear shapes
on screen.

---

## The Core Trap: `clockwise` Is Inverted in SwiftUI Canvas

When drawing arcs with `Path.addArc(center:radius:startAngle:endAngle:clockwise:)`,
the `clockwise` parameter behaves **opposite** to what you would expect if you
are coming from NSBezierPath or from intuition:

| Parameter | NSBezierPath (y-UP, AppKit) | SwiftUI Path (y-DOWN, Canvas) |
|---|---|---|
| `clockwise: true` | visually clockwise ✓ | visually **counter**-clockwise ✗ |
| `clockwise: false` | visually counter-clockwise ✗ | visually **clockwise** ✓ |

**Rule for SwiftUI Canvas: always use `clockwise: false` for concave (inward) corners.**

### Why

Core Graphics `CGPath.addArc` is defined for a mathematical y-UP coordinate
system. When the coordinate system is flipped (y-DOWN, as in SwiftUI Canvas),
the clockwise direction is visually inverted. Apple's documentation notes this:

> "In a flipped coordinate system, specifying a clockwise arc results in a
> counterclockwise arc after the transformation is applied."

SwiftUI Canvas uses a native y-DOWN coordinate system — the same category of
"flipped" system — so the inversion applies.

### What "broken" looks like

Using `clockwise: true` for a concave corner arc causes the arc to sweep 270°
outward instead of 90° inward. A rounded rectangle becomes a 4-pointed star.
A shape with three wrong-direction arcs looks like a gear or explosion. The
shape still *connects* (start/end points are correct), so the path is
geometrically valid — it just sweeps the wrong way around.

---

## Angle Convention in SwiftUI Canvas (y-DOWN)

Angles are measured from the positive x-axis, with positive angles going
**clockwise** on screen (because y points down):

```
         -90° (up)
            │
 180° ──────┼────── 0° (right)
(left)      │
           90° (down)
```

Common arc angles for shape corners:

| Corner | From | To | Direction |
|---|---|---|---|
| Top-right | `-90°` | `0°` | `clockwise: false` |
| Bottom-right | `0°` | `90°` | `clockwise: false` |
| Bottom-left | `90°` | `180°` | `clockwise: false` |
| Top-left | `180°` | `270°` | `clockwise: false` |

For a full circle starting at 12 o'clock going clockwise:
```swift
path.addArc(center: center, radius: radius,
            startAngle: .degrees(-90), endAngle: .degrees(270),
            clockwise: false)
```

---

## NSBezierPath vs SwiftUI Path: Side-by-Side

This project uses both. `IconShapePaths.swift` contains SwiftUI Path methods
(used in Canvas views) and NSBezierPath methods (used by `MenuBarIconRenderer`
for rendering into `NSImage`).

**NSBezierPath (AppKit, y-UP) — `MenuBarIconRenderer` / `ShapeIconRenderer`:**
- 0° = right, 90° = **up**, 180° = left, 270° = **down**
- `clockwise: false` = visually counter-clockwise (angles increase)
- `clockwise: true` = visually clockwise (angles decrease)
- The background shape paths in `ShapeIconRenderer` use `clockwise: false`
  which traces the shape counter-clockwise (correct for fill/even-odd rules)

**SwiftUI Path (Canvas, y-DOWN) — `IconShapePaths` SwiftUI methods:**
- 0° = right, 90° = **down**, 180° = left, 270° = **up**
- `clockwise: false` = visually **clockwise** ← use this for concave corners
- `clockwise: true` = visually **counter**-clockwise

When porting a shape from NSBezierPath to SwiftUI Path:
1. Flip the `clockwise` parameter
2. Negate y-components of angles (90° in y-UP = -90° in y-DOWN for the same
   visual direction), or equivalently keep angles the same but flip `clockwise`

In practice, since most shapes are symmetric, you can keep the same angle
numbers and just flip `clockwise` — and it works.

---

## Hexagon Orientation in y-DOWN

The flat-top hexagon (used for Extra Usage) has vertices at:
`-60°, 0°, 60°, 120°, 180°, 240°` (in y-DOWN)

- `-60°` → upper-right vertex (because `sin(-60°) < 0` = above center in y-DOWN)
- `240°` → upper-left vertex
- Closing edge from 240° back to -60° = flat top edge ✓

Starting from `0°` instead gives a flat-bottom hexagon (upside down vs the
NSBezierPath version). The current `hexagonPath` correctly starts at `-60°`.

---

## Quick Checklist When Adding a New Shape

- [ ] All concave corner arcs use `clockwise: false`
- [ ] Starting vertex for progress arc trimming is at the topmost point
  (angle `-90°` or equivalent) so `trimmedPath(from: 0, to: progress)` starts
  at 12 o'clock
- [ ] Shape inset accounts for stroke `lineWidth / 2` so edges are not clipped
  (current standard: `- 8` constant in square formula, `dx: 3, dy: 3` for circle)
- [ ] If porting from NSBezierPath: flip `clockwise` and verify angle signs

---

## Files to Know

| File | Role |
|---|---|
| `Helpers/IconShapePaths.swift` | All shape paths — SwiftUI Path (for Canvas) and NSBezierPath (for AppKit) |
| `Views/Components/UsageRowComponents.swift` | `MiniProgressIcon` — SwiftUI Canvas, draws shape + percentage text |
| `Helpers/MenuBarIconRenderer.swift` | NSImage rendering for menu bar icon |
| `Helpers/ShapeIconRenderer.swift` | NSImage rendering with percentage and progress arc |
