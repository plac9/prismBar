# prismBar Release Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the already-verified prismBar core into a fail-closed Developer ID release workflow with safe installation, exact evidence, and an honest physical macOS 27 acceptance boundary.

**Architecture:** Keep credentials outside the repository and make release scripts consume only an isolated Keychain path, an exact certificate SHA-1 fingerprint, and a Keychain profile name. Add a read-only readiness command that validates every local prerequisite without printing sensitive values, then add a transactional installer that accepts only the current revision's notarized distribution evidence and preserves a recoverable rollback bundle. Existing archive, notarization, assurance, and physical-acceptance scripts remain the sources of release truth.

**Tech Stack:** Bash 3.2-compatible shell, macOS Security framework command-line tools, Xcode 27 `codesign`, `notarytool`, `stapler`, `spctl`, `diskutil`, `jq`, `ditto`, Git, Developer ID distribution.

**Spec:** `docs/IMPLEMENTATION-PLAN.md`, Phase 10.

## Global Constraints

- Human-facing product name is exactly `prismBar`; bundle identifier remains `com.laclairtech.prismbar`.
- macOS 27 or later, Apple silicon only, with Xcode selected through `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- Never read credentials from arguments, environment variables, source files, logs, or the login/System Keychains.
- Never print certificate subjects, Keychain paths, notary profile details, submission identifiers, local paths, or environment values from readiness checks.
- Release credentials must already exist in a dedicated nonsymlink Keychain containing exactly one approved Developer ID identity and the named notary profile.
- Preserve the existing installed app until the notarized replacement has passed provenance, signature, stapling, Gatekeeper, and bundle audits.
- No publication, GitHub remote creation, push, price decision, or distribution occurs without Patrick's owner gate.
- Physical acceptance remains one observed confirmation per gate; automation must never infer success from unit tests or metadata.
- Follow red-green-refactor for every script behavior and use synthetic paths and identities in fixtures.

---

### Task 1: Privacy-safe release readiness

**Files:**
- Create: `tests/ReleaseWorkflowTests/release_readiness_contract.sh`
- Create: `scripts/release-readiness.sh`
- Modify: `scripts/ci-verify.sh`

- [x] **Step 1: Write a failing contract test**

The test requires strict positional options, safe token validation, the existing isolated-Keychain validator, clean-main and exact revision-bound CI/UI evidence checks, a non-interactive notary credential probe, stable redacted status labels, and rejection of raw credential flags or environment-secret access.

- [x] **Step 2: Run the contract and confirm the readiness script is missing**

Run: `tests/ReleaseWorkflowTests/release_readiness_contract.sh`

Expected: failure stating that the readiness workflow is missing.

- [x] **Step 3: Implement the minimum read-only readiness command**

Interface:

```bash
./scripts/release-readiness.sh \
  --keychain-profile prismBar-notary \
  --signing-keychain /absolute/dedicated.keychain-db \
  --signing-identity 40_CHARACTER_SHA1
```

It must fail before archive creation unless the repository is clean `main`, the toolchain and security audits pass, exact-revision CI JSON and UI HTML exist, the isolated identity validates, and `notarytool history` authenticates using only the dedicated Keychain profile. Output is limited to generic pass/fail gate names.

- [x] **Step 4: Re-run the focused contract, then the complete release-contract suite**

Run: `tests/ReleaseWorkflowTests/release_readiness_contract.sh` and each executable under `tests/ReleaseWorkflowTests/`.

Expected: every contract passes without exposing fixture values.

---

### Task 2: Transactional shipping installation

**Files:**
- Create: `tests/ReleaseWorkflowTests/install_release_contract.sh`
- Create: `scripts/install-release-candidate.sh`
- Modify: `scripts/ci-verify.sh`

- [x] **Step 1: Write failing source and fixture contracts**

Require an exact current-revision DMG plus evidence JSON, nonsymlink inputs/outputs, notarized and stapled evidence, matching hashes and embedded revision, Developer ID Team/identifier validation, `stapler`, `codesign`, `spctl`, and release-bundle audits. Require a same-volume staged replacement, timestamped rollback in `build/InstallRollback`, and automatic restoration if post-install verification fails.

- [x] **Step 2: Run the contract and confirm the installer is missing**

Run: `tests/ReleaseWorkflowTests/install_release_contract.sh`

Expected: failure stating that the shipping installer is missing.

- [x] **Step 3: Implement the minimum fail-closed installer**

The installer accepts only `--disk-image PATH --evidence PATH`. It mounts read-only without browsing, validates the candidate before stopping prismBar, stages it beside `/Applications/prismBar.app`, moves any existing app to the ignored rollback directory, promotes the staged bundle, validates the installed executable against evidence, and restores the previous bundle on failure. It does not use `sudo`, delete rollback bundles, or launch the app automatically.

- [x] **Step 4: Run focused fixture tests and the complete release-contract suite**

Expected: invalid evidence and unsafe paths fail before `/Applications` mutation; simulated promotion failure restores the fixture app; the valid synthetic fixture completes.

---

### Task 3: Reconcile release documentation and evidence boundaries

**Files:**
- Modify: `docs/IMPLEMENTATION-PLAN.md`
- Modify: `docs/RELEASE.md` if present
- Modify: `README.md` only if release behavior is currently described there

- [x] **Step 1: Audit documentation against executable workflow names and Phase 10 gates**

Run: `rg -n 'Developer ID|notari|InstallRollback|physical|publish|App Store|prismBar' README.md docs scripts`.

- [x] **Step 2: Document the readiness and transactional install sequence**

State clearly that credentials are provisioned out of band, readiness is read-only, physical observations cannot be automated, App Store distribution is not supported for the Accessibility engine, and publishing remains owner-gated.

- [x] **Step 3: Run licensing, public-safety, release-bundle source audit, and documentation contracts**

Expected: all checks pass and no release claim is marked complete without direct evidence.

---

### Task 4: Verify and land the operator-owned changes

**Files:** all files changed by Tasks 1-3.

- [x] **Step 1: Run the complete repository verification with Xcode 27**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/ci-verify.sh`.

Expected: revision-bound CI evidence is generated and every automated gate passes.

- [x] **Step 2: Generate and inspect the exact-revision assurance evidence supported without release credentials**

Run the existing assurance workflow against the new CI result. Preserve honest blocked states for notarization, installed shipping provenance, clean-account Gatekeeper, public source, and physical acceptance.

- [x] **Step 3: Review diff, secret scan, Git status, and signed commit**

Stage only named files and create a small signed conventional commit on `codex/release-finalization`.

- [ ] **Step 4: Stop at the owner merge gate**

Present the exact diff and verification evidence. Do not merge, push, publish, notarize, or distribute until Patrick approves the reviewed branch.

---

### Task 5: Execute the credentialed release and physical acceptance after owner gates

- [ ] **Step 1: Run readiness using the externally provisioned dedicated Keychain**
- [ ] **Step 2: Archive the clean merged `main` revision**
- [ ] **Step 3: Notarize, staple, package, and validate the app and DMG**
- [ ] **Step 4: Install through `install-release-candidate.sh` and confirm exact installed provenance**
- [ ] **Step 5: Record all 19 physical macOS 27 observations individually**
- [ ] **Step 6: Test Gatekeeper from a clean macOS 27 account**
- [ ] **Step 7: Reconcile the final threat model, MPL source revision, assurance report, neuroFlow, and Aegis**
- [ ] **Step 8: Obtain Patrick's publication, pricing, license-presentation, repository, and artifact approval**

Expected: Tasks 5.1-5.8 remain explicitly blocked until the dedicated Keychain is provisioned, Tasks 1-4 are merged to `main`, physical actions are actually observed, and Patrick grants the relevant owner gates.
