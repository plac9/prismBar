# prismBar Production Remediation Design

## Status

Approved architectural design for the macOS 27 production remediation pass.

This specification defines the corrective work required before prismBar can be treated as a production candidate. It resolves the verified hard-timeout defect, restores a native macOS material hierarchy, stabilizes display presentation, aligns privacy and security claims with runtime behavior, and defines the evidence required for release.

## Product goal

prismBar is a native macOS 27 menu bar utility that gives people precise, understandable control over movable menu bar items. It must feel like a current system utility, remain responsive when Accessibility services are slow or uncooperative, and expose no private menu data outside the running process.

The production result must provide:

- dependable observation and direct movement of supported menu bar items
- a real end-to-end operation deadline with deterministic cleanup
- one-gesture movement to any valid destination
- native macOS 27 navigation, materials, controls, accessibility, and appearance behavior
- accurate permission, privacy, plugin, and security communication
- stable human-facing display ordering without persistent display identity
- a signed, notarized, directly distributed application with verifiable provenance

## Scope

This pass includes:

1. Replacing timeout races with a propagated monotonic operation deadline.
2. Applying the remaining deadline to every Accessibility object and every input stage.
3. Guaranteeing pointer and button cleanup after any started drag.
4. Replacing decorative full-window effects and repeated content glass with the native macOS 27 material hierarchy.
5. Replacing the clipped raster page mark with contextual system symbols.
6. Preserving deterministic first-seen display order while keeping display identifiers session-private.
7. Correcting privacy and security documentation to match implemented behavior.
8. Adding regression, accessibility, appearance, bundle, signing, and physical acceptance evidence.
9. Replacing the application and menu bar icon assets with the final prism identity and removing inherited thaw artwork.

## Non-goals

- Supporting macOS releases before macOS 27.
- Reproducing inherited visual styling or thaw and ice imagery.
- Supporting arbitrary third-party plugin installation in the first production release.
- Exposing a general Accessibility, input synthesis, process inventory, file, shell, URL, or network capability to plugins.
- Adding analytics, telemetry, cloud sync, crash reporting, or diagnostic upload.
- Persisting stable display identities across launches.

## Chosen approach

The remediation keeps the current clean-room module boundaries and corrects the contracts within them. This is safer and more testable than either wrapping synchronous work in additional task races or replacing the working engine wholesale.

The central design change is a monotonic `OperationDeadline` value created once for each requested move. The coordinator passes that same absolute deadline through initial observation, input preparation and execution, and verification. Every subsystem computes its remaining allowance from the same clock. No subsystem starts new ordinary work after expiry.

The interface design removes custom atmosphere from the content plane. macOS owns navigation, chrome, menus, popovers, controls, focus, and Liquid Glass behavior. prismBar contributes hierarchy, adaptive content surfaces, concise language, contextual symbols, and restrained glacier-blue identity.

## Alternatives rejected

### Keep the task-group timeout races

Rejected because leaving a task-group scope waits for its child tasks. Cancellation is cooperative, so a synchronous or otherwise noncooperative child can cause a nominal timeout to return only after the child completes.

### Add a second detached timeout wrapper

Rejected because returning early would leave work running without a shared deadline. Late Accessibility reads or input events could mutate state after the caller had received a timeout.

### Use one fixed Accessibility timeout on the application object

Rejected because an Accessibility messaging timeout applies to the specific object on which it is set. Child objects discovered during traversal need their own remaining timeout.

### Use glass on every surface

Rejected because Liquid Glass is a functional top layer for navigation and controls. Repeated translucent content cards reduce hierarchy, contrast, and platform fidelity.

### Order displays by private identifier

Rejected because session-random identifiers are intentionally unsuitable for presentation ordering. Sorting them makes labels such as Display 1 unstable across launches.

### Add a plugin manifest digest assertion

Rejected because no independently managed digest exists. Reciprocal code-signing requirements and sealed bundle validation are the implemented integrity boundary. Documentation must describe controls that actually exist.

## Deadline architecture

### Clock and value type

Introduce an injectable monotonic clock abstraction and an immutable `OperationDeadline` value.

The deadline contains an absolute monotonic instant, not a resettable duration. It provides:

- remaining duration, clamped at zero
- an expiry check
- a throwing preflight check
- conversion to a bounded Accessibility messaging timeout

Production uses `ContinuousClock`. Tests use a controlled clock so deadline behavior is deterministic and does not depend on wall-clock time.

The coordinator creates exactly one deadline at the start of `execute`. Initial observation, input, and verification consume the same budget. Verification does not receive a fresh timeout.

### Protocol flow

Deadline awareness becomes part of the engine boundary:

```text
Move request
    -> coordinator creates one monotonic deadline
    -> reader snapshots with deadline
    -> coordinator validates topology and geometry
    -> performer moves with the same deadline
    -> reader verifies with the same deadline
    -> coordinator maps the final typed result
```

The snapshot reader and move performer protocols accept the deadline explicitly. Test doubles must honor or deliberately violate it so the coordinator contract can be tested against both cooperative and noncooperative dependencies.

### Coordinator behavior

`VerifiedMoveCoordinator` no longer races work against sleeping child tasks. It performs sequential typed operations against the shared deadline.

Before each phase it checks expiry. Deadline errors map to `.timedOut`. Existing permission, unavailable surface, topology, observation, and input outcomes remain distinct.

The coordinator does not claim it can forcibly stop arbitrary noncooperative code. Instead, production dependencies are redesigned so every potentially blocking system interaction is bounded at its source. Regression tests prove that the coordinator does not create a false early-return contract backed by still-running work.

## Accessibility deadline enforcement

`NativeMenuBarObservationReader` receives the shared deadline.

Before every Accessibility call it:

1. checks that the deadline has not expired
2. calculates the remaining allowance
3. applies a bounded, nonzero messaging timeout to the exact `AXUIElement` about to be queried
4. performs one Accessibility operation
5. checks the deadline again before continuing traversal

This applies to application elements, extras menu bar elements, descendant containers, and menu bar item elements. A child obtained from an attribute read is configured before its own attributes are read.

The fixed per-application timeout becomes a maximum slice, not a replacement deadline. The timeout used for an object is the lesser of the remaining operation budget and the configured maximum Accessibility slice. Expiry maps to the engine timeout result. Accessibility denial continues to map to permission revocation. Malformed values and communication failures remain typed discovery failures.

Traversal limits remain mandatory:

- maximum applications considered
- maximum depth
- maximum elements per application
- maximum total observations

The reader performs no retry loop after timeout or permission revocation.

## Input deadline and cleanup

`NativeMenuBarMovePerformer` receives the same operation deadline.

Preparation is side-effect-free. It validates permission, surfaces, geometry, event creation, and deadline before posting input. Once event posting begins, the performer follows an explicit state machine:

```text
prepared -> pointer positioned -> button pressed -> dragging -> released -> pointer restored
```

Every ordinary event and every wait has a deadline check immediately before it. Blocking `Thread.sleep` calls are replaced with clock-driven async suspension bounded by the remaining deadline.

After the button-down event is posted, cleanup is unconditional. A deadline, cancellation, or posting-stage failure prevents any further ordinary drag event, but still posts the minimum required mouse-up event and restores the original pointer location. Cleanup is idempotent and records its state locally so a button-up is never omitted and never intentionally duplicated.

The only input allowed after expiry is mandatory cleanup for input already pressed. No new pointer positioning, button-down, midpoint, endpoint, or retry is allowed after expiry.

The original pointer position and pressed-state bookkeeping remain process-local and are never logged.

## Move correctness

Movement remains bound to a fresh topology generation and stable item fingerprint. The source and destination must be on the same validated menu bar surface. Geometry must remain within the reserved menu bar region.

One drag moves an item directly to the requested insertion edge regardless of distance. The engine does not execute a sequence of one-position moves.

After input cleanup, the coordinator observes a fresh snapshot within the remaining deadline. It returns success only when the expected full order is observed. A changed but incomplete result is partial, stale source order is topology changed, and a missing item is unavailable. There is no blind retry against prior coordinates.

## Native macOS 27 interface

### Material hierarchy

Remove the custom full-window gradient, blurred decorative fields, and repeated custom glass cards.

Use native components so macOS supplies current Liquid Glass behavior:

- `NavigationSplitView` for the main window
- standard sidebar selection and toolbar behavior
- the established native `NSStatusItem` and `NSPopover` command surface
- standard menus, popovers, buttons, toggles, pickers, tables, forms, and disclosure groups
- adaptive system window and control backgrounds for the content plane

Static content groups use a reusable adaptive content surface, not a simulated glass material. The surface uses semantic system fill, spacing, corner shape, and separator behavior. It must remain legible with Reduce Transparency and Increase Contrast.

Liquid Glass is reserved for system navigation and interactive controls where macOS applies it. prismBar must not hand-build blur, shine, or layered translucent borders to imitate the system.

### Page identity

Replace the clipped raster `PrismMark` in page headers with contextual SF Symbols on adaptive, non-glass content surfaces:

| Section | Symbol |
|---|---|
| Overview | `sparkles` |
| Menu Bar | `menubar.rectangle` |
| Plugins | `puzzlepiece.extension` |
| Shortcuts | `keyboard` |
| Privacy | `hand.raised` |
| About | `info.circle` |

The prism identity remains in the application icon, sidebar product mark where appropriate, and template menu bar icon. No thaw, melting cube, ice cube, snow, or droplet artwork remains.

### Interaction and accessibility

The menu bar icon must open useful controls with a normal click. Reordering supports direct drag to any valid destination plus equivalent Move Before, Move After, and Move To actions.

Every icon-only control has an accessibility label and help text. Keyboard focus follows visual order. State never relies on color alone. Reduce Motion removes nonessential spatial movement. No fixed user-facing font size bypasses Dynamic Type behavior supported by macOS text styles.

### Product iconography

Replace both production icon surfaces as part of this remediation:

- the application icon is a native macOS 27 Icon Composer asset based on the prism and refracted-light identity
- the menu bar icon is a purpose-drawn monochrome template prism that remains clear at its actual status-item size

The two assets share geometry but are optimized independently for their rendering contexts. The application icon may use adaptive black, deep-water blue, glacier blue, and restrained spectral light. The menu bar icon contains no baked color, background tile, droplet, cube, or miniature application icon.

Asset catalogs, build phases, bundle resources, documentation, snapshots, and source references are audited so no inherited thaw icon can be selected at runtime. Obsolete inherited icon files are removed only after reference and bundle audits prove they are unused.

## Functional command flow

Every command from the status popover and main window follows one observable flow:

```text
user action -> fresh permission and topology validation -> bounded engine operation
    -> fresh verification -> typed result -> specific recovery state
```

The interface does not optimistically mutate the visible order before verification. While an operation is active, conflicting controls for that item are disabled and progress is announced without blocking unrelated navigation or plugin use.

Success updates the shared snapshot once. Failure preserves the last verified arrangement and displays a concise message with the failed item, result category, and one relevant recovery action. A generic exclamation mark without an accessible explanation is not an acceptable failure state. Internal process identity, coordinates, AX values, paths, and raw system errors remain hidden.

## Stable display presentation

Private surface identifiers remain session-random HMAC-derived values and are never shown or persisted.

Presentation order is a separate concern. The topology assembler preserves the first-seen surface order from observations that are already generated from geometry-sorted display tokens. `MenuBarSnapshot.surfaceIDs` retains that order rather than sorting randomized identifiers.

Display 1, Display 2, and later labels are derived only from this stable presentation order. Tests create different session keys over identical geometry and prove that human-facing display order remains unchanged while private identifiers differ.

## Privacy truth

User-facing privacy text must describe actual runtime behavior:

- prismBar observes local menu bar structure while the app is open
- observation occurs on activation, explicit refresh, and requested movement
- the app does not capture the screen
- menu titles, process identity, coordinates, and topology are not uploaded
- the app has no telemetry, analytics, crash reporter, or network feature
- Accessibility status is live state and can change without relaunch

The interface must not claim observation happens only after an explicit request because activation and granted-permission refresh paths also observe.

Production logs contain only static event names, typed result categories, and bounded timing categories. They do not contain menu titles, process names, bundle identifiers, paths, expressions, environment values, coordinates, private identifiers, or original pointer location.

## Plugin and security boundary

The first production plugin remains the sealed, bundled prismCalc XPC service.

Integrity is established through controls that exist in the built product:

- reciprocal exact code-signing requirements
- sealed embedded XPC bundle validation
- exact bundle identifier and Team ID validation
- exact protocol version and declared capability validation
- bounded message, schema, descriptor, and response limits
- serialized request handling
- timeout and circuit-breaker behavior
- Hardened Runtime and library validation

The documentation removes the unsupported manifest-digest claim. No digest is added merely to preserve the old wording.

The plugin protocol exposes no Accessibility operation, process inventory, pointer or keyboard input, generic command execution, file access, URL opening, network access, or host secret. Plugin output is a closed, validated native descriptor vocabulary and never executable content.

## Error handling

Errors remain typed from the system boundary to user-facing recovery:

| Condition | Engine outcome | User recovery |
|---|---|---|
| Shared deadline expires | timed out | Recheck and try once after the system settles |
| Accessibility revoked | permission revoked | Open System Settings and recheck live state |
| Menu bar surface invalid | menu bar unavailable | Refresh after display or menu bar state changes |
| Source topology changed | topology changed | Refresh and rebuild the move plan |
| Item disappears | item unavailable | Refresh the item list |
| Input cannot be prepared or posted | input failed | Show a concise failure with no private detail |
| Observation fails | observation failed | Preserve current UI and offer refresh |
| Plugin hangs or crashes | plugin unavailable | Keep host controls responsive and offer reconnect |

Failures must never leak internal AX values, process identity, coordinates, paths, or unredacted system errors into normal UI or production logs.

## Verification strategy

### Deterministic automated tests

Add tests that prove:

- one absolute deadline is shared across initial read, move, and verification
- the timeout budget is not reset between phases
- a noncooperative fake cannot create a false claim that cancellation stopped it
- every Accessibility object receives a timeout no greater than the remaining budget
- traversal stops after expiry and does not start another Accessibility call
- no ordinary input event is posted after expiry
- mouse-up and pointer restoration occur after expiry when button-down already occurred
- cleanup occurs exactly once on success, cancellation, timeout, and each injected stage failure
- a long-distance move uses one drag and reaches the requested insertion edge
- display presentation order is stable across different session keys
- private display identifiers differ across sessions
- privacy and security release strings contain no prohibited claims or data

Existing unit, integration, hostile-wire, sanitizer, static analysis, license, public-safety, and release-bundle audit gates remain mandatory.

### Visual and accessibility verification

Capture and inspect every primary surface in:

- light appearance
- dark appearance
- Reduce Transparency
- Increase Contrast
- Reduce Motion where movement is present

Verify sidebar behavior, window resizing, keyboard traversal, VoiceOver labels, empty states, denied and granted permission states, plugin unavailable state, long labels, multiple displays, and menu bar click behavior.

No visual sign-off is based only on source review. The rendered application must be inspected.

### Physical acceptance

The final candidate requires a stable signed application in `/Applications` and live macOS 27 acceptance:

1. Signature, designated requirement, bundle identifier, entitlements, Hardened Runtime, and sealed XPC contents match the release policy.
2. Accessibility consent is granted to that exact installed candidate and read back by the running process.
3. Refresh discovers supported items without exposing private values.
4. A one-position move succeeds and verifies.
5. A multi-position direct move succeeds in one drag and verifies.
6. Hide and show behavior succeeds where supported.
7. Permission revocation is detected without relaunch.
8. Plugin result, hang, crash, reconnect, and host responsiveness are accepted.
9. A UI automation soak completes after the required local authentication gate is satisfied.

## Release gates

No implementation is called production-ready until all of the following are true:

- the repository is clean at a signed commit
- the full automated suite passes from that commit
- Address Sanitizer and Thread Sanitizer pass
- static analysis and public-safety scans pass
- license headers, notices, dependency inventory, and MPL obligations pass
- the Release bundle contains only expected executables, libraries, entitlements, and identifiers
- reciprocal host and XPC signing checks pass
- a Developer ID candidate is signed, notarized, stapled, and accepted by Gatekeeper
- the notarized candidate passes physical Accessibility and movement acceptance on macOS 27
- rendered light, dark, transparency, contrast, keyboard, and VoiceOver review passes
- release checksum, SBOM, source revision, and provenance are recorded

Signing with the release identity, installing or replacing an Accessibility-registered application, notarizing, publishing, and distributing remain distinct owner-controlled release actions. This remediation may prepare every artifact and command, but it does not cross those gates without action-time authorization.

## Completion definition

The remediation is complete only when the engine obeys a real end-to-end deadline, late input is impossible except required cleanup, the current signed app recognizes live Accessibility permission, direct movement works across multiple positions, the interface renders as a native macOS 27 application in all required accessibility appearances, plugin failure cannot stall the host, documentation matches implementation, and the exact release candidate has passed automated and physical acceptance.
