# prismDeck Rail and Applications Design

## Status

Direction A was approved by Patrick LaClair on 2026-09-01 after reviewing three visual directions. This written specification is pending final owner review before implementation planning. It adopts Rail plus an Applications drawer, with Prism Cards subordinate to the menu-bar workflow.

## Product decision

prismDeck is the compact daily control surface for prismBar. It is not a launcher, Settings replacement, or plugin dashboard. A normal status-item click must immediately answer three questions:

1. Is prismBar ready to control the menu bar?
2. What is currently on the menu bar or tucked away?
3. What direct, verified action can the user take now?

Rail remains the unique spatial representation of menu-bar order. The Applications drawer adds a legible, searchable management view for people who identify an item by application rather than position. Both surfaces operate on the same authoritative snapshot and action coordinator.

## Goals

- Make the real menu-bar applications visible and understandable inside prismDeck.
- Preserve one-action arbitrary-position movement through Rail.
- Add fast per-application Show, Hide, First, and Last actions without requiring adjacent moves.
- Connect application-list selection to Rail so the two representations never feel unrelated.
- Keep partial discovery, protected macOS anchors, action verification, and Undo truthful.
- Reserve a restrained Prism Cards shelf without reviving a plugin-first or standalone-calculator experience.
- Keep the status-item workflow fast, keyboard complete, VoiceOver complete, and bounded on macOS 27.

## Non-goals

- Persisting menu-item identity, labels, icons, ordering, or application inventory across launches.
- Moving Clock, Siri, Control Center, or any other macOS-owned item.
- Replacing the full Menu Bar workspace, bulk organization, diagnostics, or future Scenes.
- Re-linking prismCalc or any Prism Card before the core physical acceptance gates pass.
- Showing empty, disabled, or promotional plugin controls.
- Adding network access, telemetry, screen capture, OCR, dynamic plugin loading, or third-party installation.

## Information architecture

prismDeck keeps a single vertically scrolling content area inside the AppKit-owned popover. The stable order is:

1. Compact readiness header.
2. Topology truth and partial-scan warning.
3. Rail.
4. Applications drawer, open by default.
5. Current action receipt and recovery.
6. Prism Cards shelf only when at least one shipping Card is genuinely available.
7. Compact footer actions.

The popover remains 440 points wide. Its preferred height may grow from 500 to at most 620 points when screen geometry permits. The content scrolls rather than pushing the popover outside the visible screen.

## Readiness header

The header contains the prismBar status icon, exact `prismDeck` title, one concise readiness label, and Refresh. It does not repeat multiple shield icons or long permission explanations.

- Ready: `Menu bar ready` with semantic success treatment.
- Partial: `Menu bar ready · partial scan` with an orange warning affordance.
- Permission unavailable: the existing focused Accessibility recovery surface replaces management content.
- Loading: a bounded progress state replaces stale topology actions.

Refresh remains unavailable while permission is absent or a refresh is already running.

## Rail

Rail remains visible whenever an authoritative snapshot exists.

- It presents one selected display at a time.
- `On Bar` and `Tucked Away` remain separate horizontal lanes divided by Prism Gate.
- Application items show locally resolved application icons when available and a safe semantic fallback otherwise.
- Application items retain drag, context-menu, keyboard, and VoiceOver First, Last, Previous, Next, Hide, and Show actions.
- macOS-owned items remain visible as fixed anchors with no movement affordances.
- A selected application receives one semantic highlight that does not obscure action verification or accessibility focus.
- The item remains attached to its authoritative position until a fresh observation verifies movement.

Rail selection is UI-only process memory. It clears when the selected item disappears, changes display, or Accessibility trust is lost.

## Applications drawer

The Applications drawer is a native disclosure section that starts open for each prismBar process session. Its title includes the number of application-owned menu items on the selected display.

### Search

A native search field filters only the current in-memory application rows. Search text:

- is not logged, persisted, exported, or sent across XPC;
- clears when prismDeck is dismissed;
- performs localized case-insensitive matching against the bounded display name already rendered by Rail;
- never searches paths, bundle contents, processes, or the filesystem.

### Rows

Rows are grouped as `On Bar` and `Tucked Away`, preserving current Rail order inside each group. A row contains:

- locally resolved application icon or semantic fallback;
- bounded display name;
- current section and position;
- one primary Show or Hide action;
- a compact menu containing Move to First Position and Move to Last Position when each destination is valid.

Unavailable application items remain visible but disabled with a concise reason. Self-owned controls, dividers, controllers, and macOS-owned anchors do not appear in the Applications drawer; they remain represented in Rail where their spatial role matters.

Clicking or keyboard-selecting a row selects and reveals the corresponding Rail chip. It does not move or hide anything. Rail drag remains the only free-form direct-manipulation gesture; the drawer is the explicit command surface.

### Empty and filtered states

- No application items: `No manageable applications are visible on this display.`
- No search results: `No applications match this search.`
- Partial scan: existing observed rows remain actionable, and the drawer repeats no per-source identity.

## Actions, receipts, and Undo

Every Applications action uses the existing AppModel action coordinator. The drawer never mutates local ordering optimistically.

```text
row command
  -> existing move or section planner
  -> protected input
  -> fresh topology verification
  -> typed receipt
  -> Rail and drawer re-render from verified snapshot
```

During an action, the affected row and Rail chip show bounded progress and conflicting commands are disabled. The current receipt appears below Applications. Undo is prominent only when `canRecoverLastAction` is true for the current topology. A stable partial scan may recover only under the existing exact coverage and topology contract; any mismatch fails closed and offers Refresh.

## Prism Cards shelf

Prism Cards is a native collapsed disclosure shelf below Applications. It is compiled into the shipping prismDeck surface only when the shipping host links a validated bundled Card registry and at least one Card is genuinely available.

- With zero available Cards, the shelf is absent—there is no `Coming Soon`, disabled plugin menu, or promotional placeholder.
- Cards expose compact inline capabilities rather than launching generic standalone utilities.
- prismCalc may later appear as `Quick Calculate`, using explicit input and host-rendered values inside the shelf.
- Opening the independent prismCalc application remains an optional explicit secondary action, never the Card's primary purpose.
- Cards never receive menu topology, selected application identity, Accessibility objects, PID inventory, paths, files, secrets, or network authority.

The Prism Cards implementation milestone begins only after the installed core passes the required permission, movement, recovery, status-item, relaunch, display, Space, full-screen, sleep, wake, logout, and reboot gates. This specification reserves the surface but does not waive that sequence.

## Footer

The footer contains:

- Tuck Away or Reveal when the hidden-section divider is available;
- Open prismBar as the labeled workspace action;
- Settings and Quit inside a compact overflow menu.

Undo belongs with the current receipt, not in the footer. Destructive reset remains in the full workspace and is not promoted into the daily compact surface.

## State ownership and components

`PrismDeckView` owns ephemeral deck presentation state: selected item, application search text, and Applications disclosure state. It consumes `AppModel` as the sole action and topology authority.

`PrismRailView` accepts an optional selected-item binding and emits selection without owning application commands.

A focused Applications component derives immutable row presentations from the selected display and current snapshot. It invokes existing AppModel move methods and does not receive Accessibility clients or perform input itself.

Pure presentation and filtering logic lives outside SwiftUI views so it can be tested with synthetic identifiers and names. No new service, entitlement, dependency, background process, URL scheme, or persistence model is introduced.

## Privacy and security

- Application names and icons are displayed locally from the existing live snapshot and local workspace lookup.
- No application inventory, display name, icon, order, selected item, or search query enters production logs, diagnostics, UserDefaults, files, XPC, analytics, or network traffic.
- Tests use synthetic applications and identifiers only.
- Selection and search clear on popover dismissal or trust loss.
- All movement remains host-only and protected by current signing, stable-install, Accessibility, display-safety, deadline, ownership, and post-action verification gates.
- The public-safety, secret, bundle, entitlement, and privacy audits must remain unchanged or become stricter.

## Accessibility and macOS 27 behavior

- Native DisclosureGroup, search field, buttons, menus, scrolling, focus, and semantic colors own interaction and appearance.
- Rail and Applications expose equivalent action names and results.
- Each row announces application name, section, position, availability, and available actions without depending on color.
- Selecting a row moves accessibility focus to or exposes the corresponding Rail item without automatically performing an action.
- Dynamic Type, VoiceOver, Increase Contrast, Reduce Transparency, Differentiate Without Color, Reduce Motion, and full keyboard navigation are physical acceptance gates.
- System Liquid Glass is limited to interactive controls and the popover presentation boundary; persistent content does not stack decorative glass cards.

## Failure handling

- Permission loss replaces all privileged controls immediately and clears selection, search, and recovery state.
- Partial discovery remains explicitly partial while observed rows stay usable under fresh verification.
- Missing or changed items clear stale selection and reject stale commands.
- Timeouts, unavailable geometry, ownership changes, display changes, and post-action mismatches produce the existing bounded typed results.
- The interface never invents success, retries synthetic input, or silently falls back to adjacent movement.

## Testing contract

Implementation is test-first.

### Pure tests

- Applications presentation includes only application-owned items for the selected display.
- Rows preserve visible and hidden Rail order and positions.
- Search is localized, case-insensitive, and produces bounded empty states.
- First, Last, Show, and Hide availability uses existing verified-movement invariants.
- System, self-owned, controller, divider, unavailable, cross-display, and stale items fail closed.
- Selection clears when topology, display, or trust invalidates it.

### App and UI tests

- prismDeck opens from the status item with no workspace window.
- Rail and Applications are both present from one authoritative snapshot.
- Selecting an Applications row identifies the matching Rail item without movement.
- Show, Hide, First, Last, direct Rail drag, receipt, and Undo flows remain accessible.
- Search filtering and dismissal clearing work without exposing real application data in fixtures or artifacts.
- Prism Cards is absent when no shipping Card is linked.
- Escape dismisses prismDeck and repeated status-item click reopens it.

### Physical macOS 27 acceptance

- Exact signed installed revision and live Accessibility trust are verified first.
- Status-item click opens prismDeck while the workspace is closed.
- Real application inventory appears in both Rail and Applications without logging or committed screenshots containing observed labels.
- A multi-position Rail drag and Applications First or Last command each complete in one action and verify the exact observed result.
- Hide, Show, and Undo restore expected topology.
- Reopen, relaunch, signed upgrade, multiple displays, Spaces, full-screen, automatic menu-bar hiding, sleep, wake, logout, and reboot are exercised separately.
- Private screenshots and an HTML audit remain under ignored `build/`; public evidence contains only bounded pass/fail metadata and exact revision provenance.

## Implementation sequence

1. Add pure Applications presentation and filtering models with synthetic tests.
2. Add selection linkage to Rail with tests.
3. Build the native Applications drawer and row commands.
4. Recompose prismDeck hierarchy, receipt, Undo, and footer.
5. Extend app, UI, accessibility, and visual audits.
6. Run the complete automated security and release-verification pipeline.
7. Install the exact signed Development revision and complete the core physical prismDeck matrix.
8. Revisit Prism Cards only after the core acceptance sequence is directly evidenced.

## Completion rule

The redesign is not complete because mockups render or tests pass. It is complete only when the exact signed `/Applications/prismBar.app` revision opens prismDeck from the physical status item, shows authoritative Rail and Applications state, completes verified application commands and recovery, passes the specified macOS 27 accessibility variants, and leaves no observed application information in tracked or public artifacts.
