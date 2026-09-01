# macOS 27 Compatibility Matrix

## Purpose

This document turns current Apple guidance and public menu bar utility reports into explicit prismBar safeguards. Community reports are treated as risk signals, not proof that prismBar is affected or fixed. Automated evidence and physical signed-app acceptance remain separate.

## Sources reviewed

- [Apple macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Ice issue 954: all menu bar icons become visible](https://github.com/jordanbaird/Ice/issues/954)
- [Ice issue 965: menu bar layout breaks or remains busy](https://github.com/jordanbaird/Ice/issues/965)
- [Ice issue 957: configuration is difficult to find after launch](https://github.com/jordanbaird/Ice/issues/957)
- [Ice issue 955: incorrect secondary-display scaling](https://github.com/jordanbaird/Ice/issues/955)
- [Ice issue 201: moving items while the menu bar automatically hides can leave blank or unresponsive items](https://github.com/jordanbaird/Ice/issues/201)

## Compatibility contract

| macOS 27 signal | Product risk | prismBar safeguard | Current proof | Release gate |
| --- | --- | --- | --- | --- |
| Visibility tools can expose every item after an OS update | A saved approximation can overwrite live menu bar truth | prismBar derives each action from a fresh Accessibility topology and verifies the result with another observation | Topology generation and post-action verification tests pass | Signed launch, relaunch, and upgrade checks are physical acceptance pending |
| Some menu bar sources do not respond to Accessibility | A partial scan can make recovery unavailable or replay against changed coverage | Recovery requires an unchanged unavailable-source count plus exact observed identity, ownership, role, availability, surface, and verified order; any mismatch fails closed | Stable-partial recovery and changed-coverage rejection tests pass; signed installed Development revision `dec3fd5402c804e9274ab2d9ece29bae53bad6f6` moved one application item directly across positions and restored the exact original order with Undo during a physical partial scan | Repeat on the final notarized candidate; changed-coverage physical rejection remains pending |
| Menu bar layout can become broken or indefinitely busy | A slow Accessibility object can stall the app or allow late input | One shared deadline bounds discovery and movement; timeout and cancellation release Command, mouse, and pointer state | Deadline, cancellation, and cleanup tests pass | Repeated signed movement and failure recovery are physical acceptance pending |
| A menu bar-only launch can make configuration undiscoverable | The app appears to run without a usable control surface | A normal status-item click opens Prism Deck; Prism Deck links to the workspace and native Settings scene; Escape and reopen are lifecycle-tested | Native XCUITest covers cold windowless launch, click, dismissal, reopen, workspace, and Settings routing | Installed status-item behavior is physical acceptance pending |
| Secondary displays can produce incorrect scale or geometry | Input may target the wrong display or leave the reserved menu bar region | Movement accepts only one validated display surface, rejects missing reserved menu bar space, and rejects geometry that crosses displays | Geometry and multi-display invariant tests pass | Real multiple-display and display-scale combinations are physical acceptance pending |
| Automatically hidden or full-screen menu bars can become unsafe movement targets | Synthetic drag input may land on an unavailable surface | `MenuBarInputSafetyValidator` fails closed when the target display has no safe reserved menu bar surface or the geometry is outside it | Input-safety rejection tests pass | Auto-hide, full-screen, Spaces, and recovery behavior are physical acceptance pending |
| macOS 27 changes menu and control presentation | Custom chrome can age quickly or reduce accessibility | Native lists, navigation, tabs, materials, separators, controls, and semantic colors own the interface; custom Liquid Glass is limited to interactive elements | Source audits reject repeated decorative glass and legacy material cards; automated accessibility audits cover every shipping scene | Physical text-size and VoiceOver review remain pending; Xcode 27 beta static-text contrast findings are checked through semantic-color policy and visual review |

## Apple interface guidance

The macOS 27 release notes describe updated menu image behavior and semantic tab roles. prismBar therefore does not depend on decorative images in native application menus, and its scene navigation uses native semantic controls. The status item remains a purpose-drawn monochrome template image because it is a status-bar control, not a decorative menu-item image.

Apple also records beta fixes for interactive glass hover behavior. prismBar targets the shipping macOS 27 SDK and uses system-provided glass behavior instead of recreating hover, focus, contrast, or reduced-transparency effects.

## Acceptance discipline

An automated pass proves source contracts and simulated behavior only. It does not prove TCC continuity, live menu bar movement, display geometry, or system appearance on a signed installation. Those claims remain open until the exact notarized revision passes the physical matrix in [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md).

Review this matrix whenever Apple publishes a new macOS 27 seed or release note, or when a reproducible public report identifies a new menu bar failure mode.
