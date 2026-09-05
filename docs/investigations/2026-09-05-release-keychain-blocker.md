# prismBar release Keychain blocker verification

- Blocker: `71e79657-6193-4dde-9fe5-8a6d96db010a` (HIGH).
- Verified: 2026-09-05, approximately 19:46 UTC.
- Inspected source: `357a225cd2d27b030abc1d3a6692ab9841616760`, matching local `origin/main` after daemon preflight.
- Result: the reported provisioning absence is stale. The dedicated Keychain exists, its approved identity validates, and its notarization profile authenticates after an out-of-repository unlock.

## Root cause and remediation

The current blocker was a locked dedicated Keychain. The repository identity check
passed even while the Keychain was locked; this does not prove that protected
notarization material or the signing private key can be used.

The read-only `notarytool history` probe initially exited 1 with this error
(Keychain filename and home path redacted):

```text
Error: The [KEYCHAIN] is locked. Use Keychain Access or the `security unlock-keychain [HOME]/Library/Keychains/[KEYCHAIN]` command line tool to unlock the [KEYCHAIN] keychain.
```

The available 1Password access could list and read the single matching prismBar
Keychain password item. A separate `op whoami --format=json` call returned
`account is not signed in`; that result alone did not establish item access failure.
No accessible Developer ID certificate item was discovered, but reimporting a
certificate was unnecessary because the approved identity was already present.

Used the existing password to unlock only the dedicated Keychain through the
native password prompt. The password passed through process memory and a private
terminal; it was not placed in command arguments, a file, repository content, or
tool output. No certificate export/import, permission expansion, search-list
change, or login/System Keychain access was performed. No Keychain lock-policy
change was made.

## Verification

| Check | Result |
| --- | --- |
| Dedicated nonsymlink Keychain and exactly one approved identity, using the repository validator | PASS |
| Native dedicated-Keychain unlock | PASS, exit 0 |
| Explicit dedicated Keychain/profile `notarytool history` after unlock | PASS, exit 0 with JSON response; history suppressed |
| Xcode selected per command | Xcode 27.0, build 27A5228h |
| Release signing Keychain contract | PASS |
| Release readiness contract | PASS |
| Archive contract | PASS, exit 0 |
| Notarization contract | PASS, exit 0 |
| Public-safety source audit | PASS |
| Full release readiness on the task branch | STOPPED as designed: `Release readiness failed: the release revision is not on main` |

Host discovery was bounded to immediate Keychain files in the current user's
standard Keychain directory, excluding login/System files. No host-wide code
search was performed. Credential values and identity inventory were suppressed.

Only evidence documentation changed. Swift package tests, unsigned builds, static
analysis, physical UI tests, and screenshots were not rerun because app and
workflow code were unchanged. The task's earlier complete CI claim was not
independently re-established. No archive, private-key signing operation,
notarization submission, installation, or distribution was attempted.

## Operational handoff

| Field | Finding / next action |
| --- | --- |
| Failing check | Initial dedicated-profile notarization authentication; now passes after unlock |
| Exact error | Locked-Keychain error above; current full-readiness stop is the task-branch guard above |
| Affected image | No container image. The affected output is the prismBar macOS release archive/distribution artifact |
| Attempted remediation | Successfully unlocked the existing isolated Keychain using its accessible password item and retried authentication |
| Operational impact | The credential provisioning claim no longer blocks this session. Complete release readiness and private-key signing remain unverified |
| Recommended escalation recipient | Patrick LaClair, release owner and credential administrator, if access fails again |
| Next action | On the intended clean main revision, ensure matching CI/UI evidence and rerun release readiness with the approved dedicated Keychain/profile. If it relocks, repeat the authorized out-of-repository unlock; preserve lock policy and never use login Keychain fallback |
| Review timing | Immediately before the next credentialed release attempt, and after host restart, sleep, or Keychain relock |

This is a session access repair, not a persistent unlock mechanism. No unresolved
external credential dependency was observed after remediation. Publication of
this report is delegated to the daemon: the task's report-only exception requires
a signed local commit and prohibits agent `git push` / PR creation for this diff.
