# Security Model

## Security objective

prismBar must provide useful menu bar control without becoming a route for information escape, privilege transfer, arbitrary code execution, or silent user monitoring.

## Protected assets

- the user's menu bar contents and application inventory
- Accessibility consent and the authority it grants
- keyboard and pointer event integrity
- local core preferences
- application signing and release credentials
- dormant plugin protocol integrity before any future reintroduction
- process-local action and recovery state
- build, CI, and release provenance

## Trust boundaries

| Boundary | Trusted side | Untrusted or less-trusted side | Control |
|---|---|---|---|
| Accessibility | signed prismBar host | every other local process | host-only AX access, no delegation |
| Dormant XPC design | future host protocol validator | future plugin service input and availability | excluded from the shipping target; reciprocal signing and protocol limits required before reintroduction |
| Dormant plugin renderer | future host-owned native views | future plugin-provided descriptors | excluded from the shipping target; closed element vocabulary and validation preserved in source |
| Preferences | typed domain layer | corrupted or stale stored data | bounded reading-size enum, validation, safe defaults; no stored value grants authority |
| Recovery ledger | trusted host memory | stale topology and information disclosure | verified snapshots, compatibility checks, ten-entry bound, trust-loss clearing, no persistence or XPC |
| Release | signed source revision | build machine and artifacts | clean build, SBOM, signature, notarization, stapling, hash publication |
| Public repository | reviewed source | contributions and automation | no secrets, dependency review, provenance, branch review |

## Threats and mitigations

### Accessibility privilege confused deputy

**Threat:** A plugin asks the host to inspect or manipulate arbitrary UI using the host's Accessibility consent.

**Mitigations:**

- Plugin protocol contains no AX operation, application inventory, PID, coordinate, click, key event, or generic command capability.
- Host does not expose a generic invocation endpoint.
- Menu bar commands originate from host-owned UI and are validated against a fresh host-owned topology.
- Plugin identifiers cannot be used as menu item identifiers.

The shipping core contains no plugin process or plugin invocation surface, so this boundary is not active in the release artifact.

### Malicious or substituted plugin

**Threat:** A modified XPC service connects to the host or an unrelated process connects to the service.

**Mitigations:**

- Only sealed embedded services are discoverable.
- Host and service set reciprocal code-signing requirements.
- The host validates the sealed embedded XPC bundle, exact bundle identifier, Team ID, protocol version, and declared capability set.
- Wire messages, descriptors, request concurrency, response size, timeout, and reconnect behavior are bounded.
- Hardened Runtime and library validation remain enabled.
- No third-party install directory is scanned.

These controls describe preserved future-facing code. The core release prevents this threat more directly by embedding no XPC service and linking no plugin framework.

### Descriptor abuse

**Threat:** A plugin sends oversized, recursive, misleading, or executable UI data.

**Mitigations:**

- Maximum message size, nesting depth, element count, label length, history count, and update rate are enforced.
- Unknown element types and semantic roles fail closed.
- URLs are not accepted in generic descriptors.
- Host supplies standard control appearance and accessibility behavior.
- Plugin output is never parsed as HTML, script, format string, predicate, selector, or file path.

### Information disclosure through logs or diagnostics

**Threat:** Menu item names, processes, paths, expressions, environment values, or user data appear in logs, crash reports, or test artifacts.

**Mitigations:**

- Production logging uses static event names, action IDs, result categories, and timing buckets.
- Privacy-sensitive values use redacted OSLog interpolation or are omitted.
- Diagnostic export is absent from version 1.
- Tests scan built strings and logs for forbidden synthetic canaries and local paths.
- No third-party crash reporter is linked.

### Recovery state disclosure or replay

**Threat:** Before and after topology snapshots reveal application inventory, survive longer than intended, cross into a plugin, or replay against an incompatible menu bar.

**Mitigations:**

- The recovery ledger exists only in host-process memory and holds at most ten verified entries.
- Receipts and snapshots do not conform to a persistence contract and are never written to `UserDefaults`, files, logs, diagnostics, or XPC messages.
- Accessibility revocation, signing-identity change, and process termination invalidate recovery state.
- Recovery requires the same unavailable-source count, observed item identities, ownership, roles, availability, display surfaces, and verified after-order. Stable partial scans may recover only their observed layout; any coverage or topology change fails closed.
- A recovery attempt is a new protected action and must be verified before the interface reports success.
- Persistent Scenes remain disabled until a separate privacy design addresses stable cross-launch identity.

### Input injection or unintended control

**Threat:** Stale coordinates or topology changes cause a generated event to affect the wrong target.

**Mitigations:**

- Plans bind to a topology generation and stable element fingerprint.
- Execution revalidates immediately before input.
- Movement is bounded to the menu bar region and expected modifier sequence.
- The engine releases every synthesized modifier and button state in a `defer` path.
- A fresh observation proves the requested final order.
- Failure never retries blindly against stale coordinates.

### Permission spoofing and stale consent

**Threat:** The UI claims access while the current signed executable lacks it, or repeatedly prompts from an unstable build path.

**Mitigations:**

- `AXIsProcessTrusted` is the source of truth for every check.
- Permission state is not persisted as authoritative.
- The request button is unavailable until stable-install validation succeeds for production builds.
- App activation triggers a fresh check.
- Protected calls independently handle `apiDisabled`, invalid element, and cannot-complete results.
- Diagnostics derive signing identity locally and never transmit it.

### Supply-chain compromise

**Threat:** A dependency, build script, CI action, or release machine injects code or leaks credentials.

**Mitigations:**

- No third-party runtime dependencies in the first release.
- Swift packages use checked-in resolution when dependencies are eventually added.
- CI permissions are read-only by default and actions are pinned by commit digest.
- CI installs SwiftLint only from the official versioned release archive after verifying its reviewed SHA-256 digest; a moving Homebrew formula cannot select the linter version.
- Public-history checks permit the owner no-reply address and GitHub's generic synthetic PR-merge committer only; personal author or committer addresses remain rejected.
- Signing credentials remain in Apple tooling or 1Password and are never printed.
- Release builds come from a clean signed commit and generate an SBOM and checksums.
- Release automation requires an explicit dedicated keychain containing exactly one valid code-signing identity and the approved certificate fingerprint. Login and system keychains are rejected so signing cannot fall back to interactive personal credentials or unrelated identities.
- Release readiness validates the isolated identity, exact-revision CI and visual evidence, source audits, and named notarization profile without printing Keychain paths, certificate details, profile details, submission history, environment values, or credentials.
- Shipping installation accepts only the current revision's notarized DMG and evidence from the ignored release directory. It validates both artifacts before replacing the app, preserves the previous bundle in ignored rollback storage, quarantines a rejected replacement, and restores the prior bundle when post-install verification fails.
- Routine UI tests and visual captures force local ad-hoc signing, so development automation cannot search the login Keychain or request its password.
- Dormant plugin tests use DEBUG-only ad-hoc trust seams for isolated protocol testing. Neither those seams nor the plugin service are present in the shipping application target.
- The release bundle audit rejects any embedded XPC service or linked plugin runtime in the core release.
- Binary contents, entitlements, linked libraries, and network strings are audited before notarization.
- CI builds the unsigned Release application and rejects unexpected executables, non-system libraries, local paths, credential-shaped strings, bundle-identifier drift, or entitlement drift.

## Entitlement policy

### Host

- Hardened Runtime enabled.
- App Sandbox disabled only because the core Accessibility product contract is incompatible with it.
- No network client or server entitlement.
- No automation, Apple Events, camera, microphone, location, contacts, calendar, photos, Bluetooth, USB, keychain sharing, app groups, or iCloud entitlement.
- Disable unsigned executable memory, dynamic library injection, and JIT.

### Plugin services

No plugin service is included in the core release. Any future service must use App Sandbox and must not receive network, file, media, personal-data, device, app-group, iCloud, or temporary-exception entitlements without a new threat-model and privacy review.

Every entitlement addition requires an ADR, privacy update, threat-model update, and physical verification.

## Security test matrix

- connection rejects wrong Team ID and wrong bundle identifier
- connection rejects unsupported protocol versions
- descriptor validator rejects oversized, recursive, unknown, URL-bearing, and executable-shaped inputs
- plugin crash and hang do not affect host menu control
- permission revocation disables actions without relaunch
- stale topology cannot generate an event
- event cleanup releases modifier and pointer states on every error path
- logs contain no menu titles, process names, paths, expressions, environment values, or secret canaries
- release bundle contains only expected executables and libraries
- the core release contains exactly one executable, an empty host entitlement allowlist, and no XPC service
- deterministic hostile wire and calculator corpora remain bounded under Address Sanitizer and Thread Sanitizer
- `codesign --verify --deep --strict`, `spctl`, notarization, and stapler validation pass
- notarization accepts only a named Keychain credential profile; raw Apple IDs, passwords, API keys, key identifiers, and issuer values are not accepted by repository automation
- the stapled application and stapled APFS disk image are assessed separately, and revision-bound evidence records both Apple submission identifiers and the final disk-image hash
- installation revalidates the mounted, staged, and installed application against the same revision-bound executable hash and preserves a recoverable prior bundle

## Residual risks

- Accessibility is broad authority granted by macOS. Process isolation cannot narrow the operating system permission inside the trusted host.
- Public input synthesis can be affected by concurrent user interaction or system topology changes. Fresh validation and post-action proof reduce but cannot eliminate this race.
- A compromised signed release key can produce trusted malware. Notarization audit trails, credential isolation, and revocation procedures limit impact.
