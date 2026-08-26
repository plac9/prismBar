---
colors:
  primary: "#58AFFF"
  glacier: "#58AFFF"
  deepWater: "#0B3558"
  frost: "#EAF6FF"
  success: "#34C759"
  warning: "#FF9F0A"
  danger: "#FF453A"
rounded:
  compactControl: 8
  control: 12
  panel: 18
spacing:
  compact: 6
  standard: 12
  section: 20
  content: 24
typography:
  display:
    fontFamily: "SF Pro Rounded"
    fontWeight: 600
  body:
    fontFamily: "SF Pro"
    fontWeight: 400
  data:
    fontFamily: "SF Mono"
    fontWeight: 400
---

# prismBar Design Contract

## Product posture

prismBar is a quiet macOS utility that restores control without turning the menu bar into another dashboard. It should feel like a first-party system surface: immediate, calm, precise, and transparent about authority.

## Experience principles

1. **Permission is a state, not a wall.** Explain why access is needed, show the exact current state, offer one primary action, and recheck without requiring a relaunch.
2. **The menu is the command center.** A normal click on the status item opens useful controls. No mystery clicks and no inert icon.
3. **Direct manipulation first.** Drag an item to any valid destination in one gesture. Buttons and keyboard commands are equivalent recovery paths.
4. **Glass has hierarchy.** Use system Liquid Glass for navigation and controls. Do not stack decorative translucent cards or put glass on every content surface.
5. **Color communicates sparingly.** Glacier blue is the brand accent. Success, warning, and danger remain semantic system colors with text and symbols.
6. **Privacy is visible.** Permission and About surfaces plainly state that prismBar does not capture the screen or upload menu content.

## Surface hierarchy

- The menu bar status item is monochrome and template-rendered.
- The menu popover provides section state, recent activity, plugin panels, Settings, and Quit.
- The main window uses `NavigationSplitView` for Overview, Menu Bar, Plugins, Shortcuts, Privacy, and About.
- Settings use native controls and layout behavior. Custom styling is limited to semantic content surfaces, brand accents, and system-supported interactive glass controls.
- Onboarding is a focused window with one decision per step.

## Materials

- Window chrome, sidebars, toolbars, menus, popovers, buttons, and navigation adopt macOS 27 system Liquid Glass automatically.
- Content backgrounds use system window and control backgrounds.
- Custom glass effects are allowed only for a distinct floating control group that cannot be expressed with a standard component.
- Reduce Transparency replaces materials with opaque semantic system surfaces.
- Increase Contrast and Differentiate Without Color remain fully functional.

## Color

The named hex values define brand intent and asset production. Runtime UI prefers adaptive system colors and derives brand colors for the current appearance. No user-facing state relies on color alone.

- `glacier`: selection tint and restrained brand emphasis
- `deepWater`: dark artwork depth, never body text
- `frost`: light artwork highlight, never forced as a background
- semantic state: system green, orange, and red with symbol and label

## Typography

- Navigation and controls use system text styles.
- Product moments may use system rounded design.
- Coordinates, shortcut sequences, version identifiers, and diagnostic codes use monospaced system text.
- No fixed user-facing font sizes and no forced uppercase.

## Motion

- Reordering uses spring motion only when it clarifies the final position.
- Permission checks use a calm progress indicator and announce their result.
- Reduce Motion replaces spatial transitions with fades or immediate state changes.
- No ambient animation, pulsing decoration, or continuous icon motion.

## Accessibility

- Every icon-only control has a label, help text, and keyboard equivalent where appropriate.
- Minimum target size is 28 by 28 points for macOS controls, with larger primary controls.
- Focus order follows visual order.
- Drag operations have Move To, Move Before, and Move After accessibility actions.
- Permission state changes are announced through an accessibility notification.
- Text and non-text contrast meet WCAG AA.

## Icon direction

The application icon is a prism that bends a cool beam into a compact spectrum, expressed with simple bold layers for Icon Composer. It must not contain an ice cube, melting cube, snow, droplets, or thaw imagery.

The menu bar icon is a template symbol derived from the prism silhouette. It must remain legible at 16 points, use no embedded color, and indicate open state through system selection behavior rather than a second illustration.

## Do

- Prefer `MenuBarExtra`, `NavigationSplitView`, `ToolbarItem`, `Form`, `Table`, `Grid`, and standard button styles.
- Let the system provide glass, hover, pressed, focus, vibrancy, and window behaviors.
- Show useful empty, unavailable, permission, and recovery states.
- Use concise verbs: Hide, Show, Move, Recheck, Open Settings, Copy Result.

## Do not

- Paint a custom gradient behind the entire application.
- simulate Liquid Glass with blur stacks, borders, shadows, and translucent cards
- use orange inherited from the reference product
- show raw process names, AX identifiers, PIDs, or internal errors in the normal interface
- reduce the app to a generic form with no hierarchy or identity
- duplicate an action in multiple adjacent controls without a clear primary path
