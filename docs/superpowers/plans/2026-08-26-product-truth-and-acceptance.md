# Product Truth and Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make prismBar privacy, security, licensing, assurance, and release claims match the built application and prove the exact candidate before distribution.

**Architecture:** Align UI copy and security documentation with observed runtime paths and implemented signing boundaries, then enforce those claims with source and bundle audits. Finish with automated, visual, accessibility, signing, notarization, and physical acceptance gates that all point to one signed source revision.

**Tech Stack:** SwiftUI, shell audit scripts, Swift Testing, XCTest UI tests, Xcode 27 beta toolchain, codesign, Gatekeeper, notarytool, SBOM and checksum tooling

**Spec:** `docs/superpowers/specs/2026-08-26-production-remediation-design.md`

## Global Constraints

- The deployment target is exactly macOS 27.0.
- Human-facing product casing is exactly `prismBar`.
- Technical bundle identifiers remain lowercase `com.laclairtech.prismbar` values.
- Distribution is direct Developer ID distribution.
- No analytics, telemetry, crash reporter, updater, remote API, downloaded plugin, or cloud storage may be added.
- No public artifact may include secrets, environment values, private paths, private addresses, real menu content, process identity, or screenshots of private state.
- License and source obligations remain MPL 2.0 compliant.
- Signing, installation replacement, Accessibility re-registration, notarization, publication, and distribution require action-time owner authorization.

---

### Task 1: Align privacy copy with runtime observation

**Files:**
- Modify: `App/Features/Privacy/PrivacyView.swift`
- Modify: `App/Features/Settings/SettingsRootView.swift`
- Modify: `App/Features/Overview/OverviewView.swift`
- Modify: `Tests/prismBarUITests/LaunchTests.swift`
- Modify: `scripts/audit-public-safety.sh`

**Interfaces:**
- Consumes: actual activation, refresh, and movement observation paths
- Produces: shared `PrivacyCopy` constants used by privacy surfaces and source audit

- [ ] **Step 1: Add failing privacy truth assertions**

Add a source test that requires the approved statements and rejects the false phrase:

```bash
rg -q 'on activation, when you refresh, and during requested movement' App/Features/Privacy/PrivacyView.swift
! rg -q 'Accessibility is used only when you request' App
rg -q 'does not capture the screen' App/Features/Privacy/PrivacyView.swift
rg -q 'does not upload menu' App/Features/Privacy/PrivacyView.swift
```

- [ ] **Step 2: Run public-safety audit and verify the stale-copy failure**

```bash
./scripts/audit-public-safety.sh
```

Expected: the new assertion fails on the existing request-only privacy claim.

- [ ] **Step 3: Implement accurate shared privacy copy**

Add a local app constant:

```swift
enum PrivacyCopy {
    static let observation = "prismBar observes local menu bar structure on activation, when you refresh, and during requested movement."
    static let boundary = "It does not capture the screen or upload menu titles, process identity, coordinates, or topology."
}
```

Use it in Privacy, Overview, and Settings where the behavior is described. Keep permission state described as live truth that can change without relaunch.

- [ ] **Step 4: Run source, UI, and public-safety checks**

```bash
./scripts/audit-public-safety.sh
./scripts/test-ui.sh --only prismBarUITests/LaunchTests/testPrivacyTruth
```

Expected: approved copy appears, stale copy is absent, and no private data appears.

- [ ] **Step 5: Commit privacy truth**

```bash
git add App Tests scripts/audit-public-safety.sh
git commit -S -m "privacy: align product copy with observation"
```

### Task 2: Correct plugin integrity documentation

**Files:**
- Modify: `docs/SECURITY-MODEL.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/DEPENDENCIES.md`
- Modify: `scripts/audit-live-signing-boundaries.sh`
- Modify: `scripts/audit-licensing.sh`

**Interfaces:**
- Consumes: reciprocal host and XPC signing requirements already verified by the bundle audit
- Produces: documentation and audits that name only implemented controls

- [ ] **Step 1: Add the failing documentation assertion**

Require the actual boundary and reject the unsupported claim:

```bash
! rg -n 'manifest digest.*allowlist|digest.*allowlist' docs/SECURITY-MODEL.md docs/ARCHITECTURE.md
rg -q 'reciprocal code-signing requirements' docs/SECURITY-MODEL.md
rg -q 'sealed embedded' docs/SECURITY-MODEL.md
rg -q 'protocol version' docs/SECURITY-MODEL.md
```

- [ ] **Step 2: Run licensing and signing audits and verify stale documentation fails**

```bash
./scripts/audit-licensing.sh
./scripts/audit-live-signing-boundaries.sh --documentation-only
```

Expected: documentation-only signing audit fails on the manifest-digest claim.

- [ ] **Step 3: Document the implemented controls**

Replace the digest bullet with:

```markdown
- Host and service enforce reciprocal exact code-signing requirements.
- The host validates the sealed embedded XPC bundle, exact bundle identifier, Team ID, protocol version, and declared capability set.
- Wire messages, descriptors, request concurrency, response size, timeout, and reconnect behavior are bounded.
```

Keep the protocol prohibition against Accessibility, process inventory, input synthesis, files, URLs, networking, and generic commands.

- [ ] **Step 4: Run documentation and signing audits**

```bash
./scripts/audit-licensing.sh
./scripts/audit-live-signing-boundaries.sh --documentation-only
./scripts/audit-public-safety.sh
```

Expected: all three audits pass.

- [ ] **Step 5: Commit security truth**

```bash
git add docs scripts
git commit -S -m "security: document implemented plugin boundary"
```

### Task 3: Update the assurance model for the native interface

**Files:**
- Modify: `docs/assurance-report.template.html`
- Modify: `scripts/generate-assurance-report.sh`
- Modify: `docs/IMPLEMENTATION-PLAN.md`
- Modify: `DESIGN.md`

**Interfaces:**
- Consumes: new `ContentCard`, contextual headers, typed action results, and final icons
- Produces: assurance evidence that no longer cites deleted decorative types

- [ ] **Step 1: Add failing stale-reference checks**

```bash
! rg -n 'PrismBackdrop|PrismLightField|GlassCard|PrismMark' docs scripts
rg -q 'ContentCard' docs/assurance-report.template.html
rg -q 'contextual SF Symbols' docs/assurance-report.template.html
```

- [ ] **Step 2: Generate the report and verify stale references fail**

```bash
./scripts/generate-assurance-report.sh
```

Expected: the assurance generation gate reports old material or page-mark references.

- [ ] **Step 3: Rewrite assurance evidence against current types**

Update the material matrix to name native window background, semantic `ContentCard`, standard glass controls, contextual SF Symbols, and the light, dark, Reduce Transparency, Increase Contrast, and Reduce Motion launch variants. Mark an item passed only when its corresponding automated or rendered evidence exists.

- [ ] **Step 4: Generate and audit the assurance report**

```bash
./scripts/generate-assurance-report.sh
./scripts/audit-public-safety.sh
rg -n 'PrismBackdrop|PrismLightField|GlassCard|PrismMark' build/*.html && exit 1 || true
```

Expected: report generation succeeds and no obsolete type is referenced.

- [ ] **Step 5: Commit assurance alignment**

```bash
git add DESIGN.md docs scripts/generate-assurance-report.sh
git commit -S -m "docs: align assurance with native interface"
```

### Task 4: Run the complete automated production gate

**Files:**
- Modify: `.github/workflows/ci.yml` only if local and hosted gates differ
- Modify: `scripts/ci-verify.sh` only when a required command is absent
- Modify: `docs/IMPLEMENTATION-PLAN.md` with verified results

**Interfaces:**
- Consumes: all implementation commits from the three plans
- Produces: one clean signed source revision with complete automated evidence

- [ ] **Step 1: Record the exact gate commands before execution**

The local gate must invoke:

```bash
./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh
./scripts/ci-verify.sh
./scripts/stress-verify.sh
```

Confirm `ci-verify.sh` includes debug and release tests, Address Sanitizer, Thread Sanitizer, Xcode Debug build, static analysis, Release build, and release-bundle audit.

- [ ] **Step 2: Run the gate from a clean worktree**

```bash
test -z "$(git status --short)"
./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh
./scripts/ci-verify.sh
./scripts/stress-verify.sh
```

Expected: every command exits zero. Preserve the exact failing command and output if any gate fails.

- [ ] **Step 3: Fix any gate failure using its smallest test-first task**

For each failure, first add or tighten the focused regression test, run it to reproduce, make the smallest source correction, rerun the focused test, then restart the complete gate from the first command. Do not weaken an audit to accept an unsafe artifact.

- [ ] **Step 4: Record verified automated evidence**

Update the implementation checklist with the signed commit, test count, sanitizer results, analyzer result, build configurations, public-safety result, license result, bundle audit result, and stress duration. Do not include local absolute paths or private test data.

- [ ] **Step 5: Commit the automated evidence**

```bash
git add .github scripts docs/IMPLEMENTATION-PLAN.md
git commit -S -m "assurance: record production automation gate"
```

### Task 5: Perform rendered and assistive-technology acceptance

**Files:**
- Modify: `Tests/prismBarUITests/LaunchTests.swift` if a rendered regression is uncovered
- Modify: `docs/IMPLEMENTATION-PLAN.md` with non-sensitive acceptance results

**Interfaces:**
- Consumes: Debug application built from the clean signed revision
- Produces: rendered evidence for light, dark, transparency, contrast, motion, keyboard, and VoiceOver behavior

- [ ] **Step 1: Build the UI test candidate**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project prismBar.xcodeproj -scheme prismBar -configuration Debug build-for-testing
```

Expected: build-for-testing exits zero.

- [ ] **Step 2: Run the automated launch variants**

```bash
./scripts/test-ui.sh --all-appearances
```

Expected: Overview, Menu Bar, Plugins, Shortcuts, Privacy, About, and status popover pass in light, dark, Reduce Transparency, Increase Contrast, and Reduce Motion variants.

- [ ] **Step 3: Inspect rendered output**

Check that content has one native background plane, sidebars and interactive controls receive system material, static cards are semantic and opaque when required, headers are not clipped, text remains legible, action failures contain labels and recovery, and the status item opens on normal click.

- [ ] **Step 4: Verify keyboard and VoiceOver semantics**

Tab through navigation and controls in visual order. Invoke Show, Hide, Move To First Position, and Move To Last Position through accessibility actions. Confirm every icon-only control has a label and help text, state does not rely on color, and progress and result changes are announced.

- [ ] **Step 5: Commit any regression and acceptance evidence**

```bash
git add App Tests docs/IMPLEMENTATION-PLAN.md
git commit -S -m "assurance: accept native macOS interface"
```

If no source or documentation changed, do not create an empty commit. Record the verified result in the final handoff.

### Task 6: Prepare the exact release candidate and stop at owner gates

**Files:**
- Modify: `docs/IMPLEMENTATION-PLAN.md` with artifact provenance
- Output only under ignored `build/`: archive, exported app, SBOM, checksums, notarization input

**Interfaces:**
- Consumes: clean signed source revision and successful automated plus rendered acceptance
- Produces: auditable Developer ID release candidate ready for owner-controlled signing, installation, Accessibility registration, notarization, and distribution

- [ ] **Step 1: Confirm the release source state**

```bash
test -z "$(git status --short)"
git log -1 --show-signature --format='%H %G? %s'
```

Expected: clean worktree and a good signature on the exact candidate commit.

- [ ] **Step 2: Build and audit the unsigned Release candidate**

```bash
./scripts/archive-release-candidate.sh
./scripts/audit-release-bundle.sh
```

Expected: bundle identifiers, executables, libraries, entitlements, resources, privacy strings, and plugin boundaries match the allowlists.

- [ ] **Step 3: Generate provenance**

Generate an SPDX SBOM, SHA-256 checksums, source revision record, toolchain record, and archive inventory without credentials or personal paths. Verify each generated artifact with the matching audit script.

- [ ] **Step 4: Stop for action-time authorization**

Present the exact candidate hash and the commands that would sign with Developer ID, install or replace `/Applications/prismBar.app`, re-register Accessibility, submit to Apple notarization, staple, and evaluate with Gatekeeper. Do not run those commands until the owner explicitly authorizes this exact candidate.

- [ ] **Step 5: After authorization, execute physical acceptance**

Verify the exact installed signature and Accessibility readback, one-position movement, one-drag multi-position movement, Hide, Show, live revocation, prismCalc result, plugin hang, crash, reconnect, host responsiveness, and the authenticated UI automation soak. If all pass, notarize, staple, rerun Gatekeeper and bundle audits, then stop again before publication or distribution.

