---
version: alpha
name: prismBar Prism Deck
description: Native macOS 27 design contract for prismBar command, workspace, and tool surfaces
colors:
  primary: "#248CFF"
  refractedBlue: "#70D6FF"
  refractedCyan: "#38A8FF"
  refractedViolet: "#7A6BFF"
  graphiteCanvas: "#0B1118"
  frostCanvas: "#ECF4FB"
typography:
  pageTitle:
    fontFamily: SF Pro Display
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: -0.01em
  sectionTitle:
    fontFamily: SF Pro Text
    fontSize: 15px
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: SF Pro Text
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.35
  detail:
    fontFamily: SF Pro Text
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.3
  numeric:
    fontFamily: SF Mono
    fontSize: 28px
    fontWeight: 500
    lineHeight: 1.1
rounded:
  control: 8px
  surface: 12px
  prominent: 16px
  pill: 999px
spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
components:
  primary-button:
    textColor: "#FFFFFF"
    backgroundColor: "{colors.primary}"
    rounded: "{rounded.control}"
    padding: "{spacing.sm}"
    typography: "{typography.body}"
  tool-badge:
    textColor: "{colors.graphiteCanvas}"
    backgroundColor: "{colors.frostCanvas}"
    rounded: "{rounded.pill}"
    padding: "{spacing.xs}"
    typography: "{typography.detail}"
  prism-edge-blue:
    backgroundColor: "{colors.refractedBlue}"
    height: 2px
  prism-edge-violet:
    backgroundColor: "{colors.refractedViolet}"
    height: 2px
  prism-edge-cyan:
    backgroundColor: "{colors.refractedCyan}"
    height: 2px
---

# Overview

prismBar should feel like a compact macOS instrument: immediately understandable, precise under pressure, and distinct through refracted-light details rather than decorative chrome. The system owns window materials, Liquid Glass, focus, selection, and control behavior. prismBar contributes a calm information hierarchy, a glacier-blue action color, and rare spectral accents that make the product recognizable without turning utility surfaces into artwork.

# Colors

`primary` is the product action tint for enabled primary controls and selected tool identity. Refracted blue and violet form the prism spectrum. Their one large-scale use is the low-chroma Prism Field canvas behind workspace content. The field stays beneath content, fades toward the semantic canvas base, and extends under the native sidebar so system Liquid Glass has meaningful color to refract. Spectrum colors never replace semantic status colors or text.

Content surfaces, primary text, secondary text, separators, warnings, destructive states, success, and keyboard focus use native semantic macOS values. Graphite and frost are the adaptive Prism Field bases. Reduce Transparency removes the refracted field and uses an opaque semantic content surface.

# Typography

Use semantic prismBar type roles backed by Apple system fonts in shipping SwiftUI code. General Settings offers Standard (100%), Large (125%), Extra Large (150%), and Accessibility (200%) reading sizes because macOS does not expose a user-controlled Dynamic Type text-size setting. Every shipping scene consumes the same local preference; malformed stored values fail back to Standard. The type tokens document hierarchy and design-tool targets. Page titles are compact and confident. Section titles label small groups. Body copy explains one decision at a time. Detail text is used only for secondary state and capability descriptions. Numeric results use monospaced digits and scale with the selected reading size.

# Layout

The menu-bar Prism Deck is a compact command surface with two stable modes: Bar and Tools. Keep one primary task above the fold and preserve a predictable footer for opening the workspace and Settings. The main workspace uses a standard `NavigationSplitView`. Tool experiences open in independent utility windows so they can remain available without keeping Settings or the workspace open.

Use the spacing tokens as rhythm, not as fixed geometry that defeats platform adaptation. Window, popover, Rail, row, icon-column, and control geometry must respond to the selected reading size through 200%. Preserve comfortable click targets, keyboard traversal, and localization growth. Avoid dense dashboard grids in the compact menu-bar surface.

# Elevation & Depth

macOS owns elevation through native windows, menus, popovers, sheets, and Liquid Glass. The workspace has one Prism Field content canvas. Persistent groups use open native sections, separators, list selection, and whitespace. Liquid Glass is reserved for navigation and interactive controls, including draggable Rail chips. Do not stack glass cards or add decorative drop shadows.

# Shapes

Use standard control shapes wherever SwiftUI supplies them. `control` is for small custom hosts around validated plugin controls. `surface` is for bounded content groups. `prominent` is reserved for the empty-state or onboarding hero. `pill` is limited to short capability or health labels. Do not turn every row into a rounded card.

# Motion

Movement should explain state change, not decorate idle surfaces. Reordering may use a short system spring only when it clarifies the verified destination. Permission checks use a calm progress indicator. Reduce Motion replaces spatial and numeric transitions with fades or immediate state changes. Do not add ambient animation, pulsing decoration, continuous icon movement, or animated backgrounds.

# Icon Direction

The application icon is a prism that bends a cool beam into a compact spectrum, expressed with bold layers suitable for Icon Composer. The menu-bar icon is a monochrome template mark derived from the same prism geometry and optimized independently for status-item size. Neither surface uses ice, cubes, melting forms, snow, droplets, or inherited thaw imagery.

# Components

The primary button launches the single most useful next action and should normally be a standard bordered-prominent SwiftUI button using the app tint. The tool badge is a compact label for a capability or verified state. In dark appearance it must use native semantic foreground and fill values rather than the light reference colors in the token block.

The Prism Deck mode control is a standard segmented picker. Menu-item rows use native list behavior and expose direct move, hide, show, and recovery actions. Tool launchers identify the tool, its purpose, current health, and one launch action. Plugin-generated panels are rendered only from the closed, validated host vocabulary.

# Do's and Don'ts

## Do

- Let standard SwiftUI and AppKit components receive macOS 27 Liquid Glass automatically.
- Keep daily menu-bar control in Prism Deck, deeper organization in the workspace, and infrequent preferences in Settings.
- Call user-facing extensions Tools and explain that plugins are the isolated framework underneath.
- Give every icon-only control an accessibility label and help text.
- Respect Reduce Transparency, Increase Contrast, Differentiate Without Color, and Reduce Motion.
- Use specific, actionable failures instead of an unexplained exclamation mark.

## Don't

- Do not embed a working calculator in Settings or the Tools management page.
- Do not advertise arbitrary third-party plugin installation.
- Do not use custom Liquid Glass in persistent content surfaces or stack material cards.
- Do not use thaw, ice, cube, droplet, or melting imagery.
- Do not expose observed menu titles, process identity, paths, coordinates, Accessibility values, or plugin payloads in logs or diagnostics.
- Do not use spectral colors as status semantics or inside dense content surfaces.
