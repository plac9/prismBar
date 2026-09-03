# Privacy

prismBar is designed to perform its work locally on the Mac.

## Data the app may process

- Accessibility metadata required to identify and move visible menu bar elements
- owning process identifiers and locally available application names or icons
- user preferences for reading size, section layout, and shortcuts

## Data the app does not collect

- screenshots or screen recordings
- OCR output
- menu contents, document contents, passwords, clipboard history, keystroke history, or typed text outside an active prismBar control
- analytics, telemetry, advertising identifiers, contacts, calendars, photos, location, or browsing history
- environment variables, shell history, configuration files, or credentials

## Storage

Preferences use app-owned local storage. The reading-size value controls presentation only; it cannot grant permission or authorize a menu-bar action, and an invalid value restores the documented default. Sensitive values are not expected. If a future feature requires a secret, it must use Keychain and receive a separate security review.

## Network

The initial product has no runtime network capability. Project and release links open only after an explicit user action through the system browser. CI downloads reviewed build tools from versioned upstream releases and verifies their recorded digests; this build-time traffic is not present in the application. Update delivery and licensing must not be added until their data flows, retention, authentication, and failure behavior are documented and reviewed.

## Plugins

No plugin service is linked, embedded, launched, or exposed by the shipping core release. The preserved future Prism Card design requires sandboxed XPC services with declared capabilities and bounded Codable messages. A future plugin release must complete a new privacy and security review before shipping.
