# Security Model

## Security objective

prismBar must provide useful menu bar control without becoming a route for information escape, privilege transfer, arbitrary code execution, or silent user monitoring.

## Protected assets

- the user's menu bar contents and application inventory
- Accessibility consent and the authority it grants
- keyboard and pointer event integrity
- local preferences and calculator history
- application signing and release credentials
- plugin protocol integrity
- build, CI, and release provenance

## Trust boundaries

| Boundary | Trusted side | Untrusted or less-trusted side | Control |
|---|---|---|---|
| Accessibility | signed prismBar host | every other local process | host-only AX access, no delegation |
| XPC | host protocol validator | plugin service input and availability | code-signing requirement, schema limits, timeouts |
| Plugin renderer | host-owned native views | plugin-provided descriptors | closed element vocabulary, size limits, semantic validation |
| Preferences | typed domain layer | corrupted or stale stored data | versioned decoding, validation, safe defaults |
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

### Malicious or substituted plugin

**Threat:** A modified XPC service connects to the host or an unrelated process connects to the service.

**Mitigations:**

- Only sealed embedded services are discoverable.
- Host and service set reciprocal code-signing requirements.
- Bundle identifier, Team ID, protocol version, and manifest digest are allowlisted.
- Hardened Runtime and library validation remain enabled.
- No third-party install directory is scanned.

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
- Signing credentials remain in Apple tooling or 1Password and are never printed.
- Release builds come from a clean signed commit and generate an SBOM and checksums.
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

- App Sandbox enabled.
- No network client or server entitlement.
- No user-selected files, downloads, pictures, music, movies, contacts, calendars, location, microphone, camera, Bluetooth, USB, app groups, or iCloud.
- No temporary exceptions.

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
- host and plugins have the exact entitlement allowlists
- `codesign --verify --deep --strict`, `spctl`, notarization, and stapler validation pass

## Residual risks

- Accessibility is broad authority granted by macOS. Process isolation cannot narrow the operating system permission inside the trusted host.
- Public input synthesis can be affected by concurrent user interaction or system topology changes. Fresh validation and post-action proof reduce but cannot eliminate this race.
- A compromised signed release key can produce trusted malware. Notarization audit trails, credential isolation, and revocation procedures limit impact.
