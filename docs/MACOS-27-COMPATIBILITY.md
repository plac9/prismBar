# macOS 27 Compatibility Matrix

## Purpose

This document turns current Apple guidance and public menu bar utility reports into explicit prismBar safeguards. Community reports are treated as risk signals, not proof that prismBar is affected or fixed. Automated evidence and physical signed-app acceptance remain separate.

## Sources reviewed

- [Apple macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple SwiftUI documentation: `dynamicTypeSize`](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize)
- [Apple Developer Forums: macOS 27 Accessibility and PostEvent authorization divergence](https://developer.apple.com/forums/thread/842985)
- [Ice issue 954: all menu bar icons become visible](https://github.com/jordanbaird/Ice/issues/954)
- [Ice issue 965: menu bar layout breaks or remains busy](https://github.com/jordanbaird/Ice/issues/965)
- [Ice issue 957: configuration is difficult to find after launch](https://github.com/jordanbaird/Ice/issues/957)
- [Ice issue 955: incorrect secondary-display scaling](https://github.com/jordanbaird/Ice/issues/955)
- [Ice issue 201: moving items while the menu bar automatically hides can leave blank or unresponsive items](https://github.com/jordanbaird/Ice/issues/201)

## Compatibility contract

| macOS 27 signal | Product risk | prismBar safeguard | Current proof | Release gate |
| --- | --- | --- | --- | --- |
| Accessibility can appear enabled while separate PostEvent authority remains denied | The app can observe menu-bar structure but cannot complete its verified Command-drag | Readiness requires both `AXIsProcessTrusted` and `CGPreflightPostEventAccess`; the user-initiated recovery action requests both public authorities | A Developer ID-signed physical macOS 27 experiment remained Connected after settling and full relaunch, rediscovering 16 items after the PostEvent-aware request and direct user consent | Repeat on the exact notarized revision and preserve the signed physical evidence |
| Visibility tools can expose every item after an OS update | A saved approximation can overwrite live menu bar truth | prismBar derives each action from a fresh Accessibility topology and verifies the result with another observation | Topology generation and post-action verification tests pass; installed Development revision `96be5046ab3b00cb15572d7feb3e8fc4bdce1520` preserved live Accessibility trust and order through signed upgrade and relaunch | Repeat launch, relaunch, and upgrade checks on the final notarized candidate |
| Some menu bar sources do not respond to Accessibility | A partial scan can make recovery unavailable or replay against changed coverage | Recovery requires an unchanged unavailable-source count plus exact observed identity, ownership, role, availability, surface, and verified order; anchored movement also requires its section divider to remain observable and retries a transient scan that loses it | Stable-partial recovery, changed-coverage rejection, and missing-divider retry tests pass; signed installed Development revision `ec5345f26baadfe9f673bf78c6761ae5da822bf5` moved 1Password directly from position 2 to position 5 while retaining all eight Rail items, then restored the exact original order with Undo | Repeat on the final notarized candidate; changed-coverage physical rejection remains pending |
| Menu bar layout can become broken or indefinitely busy | A slow Accessibility object can stall the app or allow late input | One shared deadline bounds discovery and movement; timeout and cancellation release Command, mouse, and pointer state | Deadline, cancellation, and cleanup tests pass | Repeated signed movement and failure recovery are physical acceptance pending |
| A menu bar-only launch can make configuration undiscoverable | The app appears to run without a usable control surface | A normal status-item click opens Prism Deck; Prism Deck links to the workspace and native Settings scene; Escape and reopen are lifecycle-tested | Native XCUITest covers cold windowless launch, click, dismissal, reopen, workspace, and Settings routing | Installed status-item behavior is physical acceptance pending |
| Secondary displays can produce incorrect scale or geometry | Input may target the wrong display or leave the reserved menu bar region | Movement accepts only one validated display surface, rejects missing reserved menu bar space, and rejects geometry that crosses displays | Geometry and multi-display invariant tests pass | Real multiple-display and display-scale combinations are physical acceptance pending |
| Automatically hidden or full-screen menu bars can become unsafe movement targets | Synthetic drag input may land on an unavailable surface | `MenuBarInputSafetyValidator` fails closed when the target display has no safe reserved menu bar surface or the geometry is outside it | Input-safety rejection tests pass | Auto-hide, full-screen, Spaces, and recovery behavior are physical acceptance pending |
| macOS 27 changes menu and control presentation | Custom chrome can age quickly or reduce accessibility | Native lists, navigation, tabs, materials, separators, controls, and semantic colors own the interface; custom Liquid Glass is limited to interactive elements | Source audits reject repeated decorative glass and legacy material cards; automated accessibility audits cover every shipping scene | Physical text-size and VoiceOver review remain pending; Xcode 27 beta static-text contrast findings are checked through semantic-color policy and visual review |
| macOS does not provide a user-controlled Dynamic Type text-size setting | Users who need larger text can be left with fixed-size utility UI or clipped controls | General Settings provides local 100%, 125%, 150%, and 200% semantic type; every shipping scene shares the preference and adapts fixed geometry | Core preference, semantic typography, responsive-layout, and native UI tests cover invalid storage and the 200% surface | Inspect the exact signed candidate at all four sizes on physical macOS 27; record the larger-text gate only after unclipped keyboard and pointer operation |

## Apple interface guidance

The macOS 27 release notes describe updated menu image behavior and semantic tab roles. prismBar therefore does not depend on decorative images in native application menus, and its scene navigation uses native semantic controls. The status item remains a purpose-drawn monochrome template image because it is a status-bar control, not a decorative menu-item image.

Apple also records beta fixes for interactive glass hover behavior. prismBar targets the shipping macOS 27 SDK and uses system-provided glass behavior instead of recreating hover, focus, contrast, or reduced-transparency effects.

SwiftUI exposes `dynamicTypeSize` on macOS, but Apple documents that macOS has no user-controlled Dynamic Type setting and does not automatically change text size. prismBar therefore provides an explicit local preference while retaining system fonts, semantic hierarchy, accessibility labels, and native controls.

## Acceptance discipline

An automated pass proves source contracts and simulated behavior only. It does not prove TCC continuity, live menu bar movement, display geometry, or system appearance on a signed installation. Those claims remain open until the exact notarized revision passes the physical matrix in [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md).

Review this matrix whenever Apple publishes a new macOS 27 seed or release note, or when a reproducible public report identifies a new menu bar failure mode.
