# Security Policy

## Supported versions

Security support begins with the first signed public release. Until then, the `main` branch is pre-release software and must not be treated as a production security boundary.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability or information disclosure. Report it privately through GitHub Security Advisories for this repository.

Include only the minimum information required to reproduce the issue. Redact menu bar titles, application names, usernames, paths, device identifiers, signing identities, environment values, and tokens.

## Security invariants

- No telemetry, analytics, advertising SDKs, or crash uploads.
- No screen capture, OCR, or storage of menu bar pixels.
- No enumeration or logging of environment variables.
- No private Apple frameworks or undocumented selectors.
- No arbitrary plugin loading.
- No plugin receives Accessibility authority.
- No plugin can render executable UI code inside the host process.
- No network entitlement for the host or bundled plugins unless a future reviewed capability explicitly requires it.
- No secrets, certificates, profiles, tokens, or personal data in Git history or release artifacts.
- Every executable uses Hardened Runtime and an explicit entitlement set.
- Release artifacts must pass code-signing, notarization, malware, secret, dependency, and privacy-manifest audits.

The detailed model is in `docs/SECURITY-MODEL.md`.
