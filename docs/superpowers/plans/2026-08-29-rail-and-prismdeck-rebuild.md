# Rail and prismDeck Rebuild Plan

**Goal:** Make Rail the fast, spatial, trustworthy center of prismBar and make prismDeck the smallest complete daily control surface around it.

**Architecture:** Keep `MenuBarSnapshot` authoritative. Add pure Rail layout and keyboard-movement resolvers in `prismBarCore`, then render those values in SwiftUI. Drag previews identify a requested destination but never reorder the authoritative snapshot. All actions continue through the existing receipt and recovery engine.

## Visual direction

- **Subject:** direct control of the physical macOS menu bar.
- **Single job:** place an item exactly where the user wants it and confirm that macOS accepted the change.
- **System palette:** window background, primary and secondary labels, separator, system blue tint, semantic green, orange, and red. The Prism spectrum is reserved for the Rail gate and never substitutes for status color.
- **Type:** San Francisco Display for the product and Rail heading, San Francisco Text for controls, and monospaced digits only for counts and positions.
- **Layout:** one display context, one continuous Rail editor, two explicit lanes, one receipt strip, and a quiet utility footer.
- **Signature:** the Prism Gate, a narrow refracted seam between the On Bar and Tucked Away lanes that makes the visibility boundary spatially legible.

```text
+--------------------------------------------------+
| prismDeck       Display 1        accessibility  |
| 14 items                                  refresh|
|                                                  |
| ON BAR       [A] [B] [C] [D]                     |
|                 PRISM GATE                       |
| TUCKED AWAY  [E] [F]                             |
|                                                  |
| Verified / blocked receipt                 Undo  |
| Open prismBar                      Settings Quit |
+--------------------------------------------------+
```

## Acceptance

- One selected display is explicit and stable across refreshes.
- Visible and hidden items are derived from a tested pure layout value.
- A drag can request any position or cross the visibility boundary in one action.
- Snapshot order stays fixed until a fresh observation verifies the move.
- Keyboard and VoiceOver expose previous, next, first, last, hide, and show.
- Undo appears only for a topology-compatible ledger entry.
- Reduce Transparency, Increase Contrast, Differentiate Without Color, Reduce Motion, keyboard focus, and VoiceOver remain usable.
- The compact surface contains no plugin launcher or prismCalc control.

## Sequence

1. Add failing tests for Rail layout and keyboard movement.
2. Implement the pure resolvers.
3. Rebuild Rail around the tested values and Prism Gate.
4. Rebuild prismDeck hierarchy around Rail, receipts, and recovery.
5. Run focused tests, package tests, unsigned arm64 build, and policy audits.
6. Capture the signed installed surface and produce the required HTML visual audit during the physical verification phase.
