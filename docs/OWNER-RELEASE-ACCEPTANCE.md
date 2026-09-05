# prismBar owner release acceptance

Debt: `02935b4e-3b59-4879-bdb8-d23b8eb0a6cd`. Reviewed September 5, 2026.
Status: **incomplete; publication remains blocked**. This is an acceptance item,
not an engine implementation defect. No new physical observations were recorded.

## Exact candidate and verified evidence

- Source: `357a225cd2d27b030abc1d3a6692ab9841616760` (fetched `origin/main` at review time).
- Installed application: `/Applications/prismBar.app`, macOS 27.0 build `26A5425a`.
- Artifact: `prismBar-0.1.0-1-357a225cd2d2.dmg`.
- DMG SHA-256: `121f7b10c5f902d9770c4d68a588b8f4002eb9dc9ff901253fe07fc25eee1b01`.
- Executable SHA-256: `0abae00dfb177b88f1e7860b287a62c12be6ae6cf50b5487c2dfac6ceeb1e98e`.

The primary checkout at `~/dev/prismBar` contains ignored `build/` evidence.
Its exact-revision CI, eleven-surface UI, runtime, and stress JSON records report
`passed`. These are existing records, not newly executed CI or UI tests.
Running the physical recorder's `--status` there revalidated installed revision,
Developer ID signature, Gatekeeper acceptance, staple, executable hash, and the
distribution-record binding. The installed release-bundle audit also passed.

The physical record was last updated `2026-09-04T17:51:47Z` and reports
`incomplete`: 8 confirmed, 11 unconfirmed. Confirmed gates are accessibilityGrant,
dark, fullScreen, largerText, menuMovement, permissionRelaunch, signedUpgrade,
and statusItem. Their historical observations were preserved without changes.

## Remaining observed matrix

Use the exact candidate above in an owner-attended physical session. Record the
actual result and supporting evidence for each row; a command succeeding is not
proof of the visual or interactive behavior. Restore system preferences afterward.

| Recorder gate | Required observation |
| --- | --- |
| cleanAccountGatekeeper | In a clean macOS 27 account, launch the quarantined distribution artifact through the shipping flow; observe Gatekeeper and first launch without bypasses. |
| multipleDisplays | With multiple displays attached, move the active menu bar between displays and exercise status item, prismDeck, movement, and recovery after display changes. |
| spaces | Switch Spaces and return; verify reachable status item, correctly placed windows, and working movement/Undo. |
| sleepWake | Sleep and wake the physical Mac; verify permission state, status item, movement/Undo, and absence of duplicate windows. |
| logout | Log out and back in, relaunch the same installed app, and verify permission state and core interactions. |
| reboot | Reboot and relaunch the same installed app; verify permission state and core interactions. |
| light | Switch global appearance to light and inspect every shipping surface for legibility and correct adaptation. Recheck global dark adaptation in the same session despite the existing dark confirmation. |
| reducedMotion | Enable Reduce Motion globally and exercise presentation, dismissal, and movement feedback. |
| reducedTransparency | Enable Reduce Transparency globally and inspect shipping surfaces for legibility and adaptation. |
| increasedContrast | Enable Increase Contrast globally and inspect text, controls, selection, and focus indicators. |
| voiceOver | Navigate shipping surfaces using VoiceOver; verify names, order, focus, actions, and recovery announcements. |

Run the recorder from a clean checkout **at the candidate revision** with its
original evidence available, before recording each genuinely observed result:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/record-physical-acceptance.sh --status
# Substitute only a gate actually observed in this session:
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/record-physical-acceptance.sh --confirm GATE --observed-on-physical-macos-27
```

Do not copy confirmations onto a different revision. This documentation change
does not rebuild or replace the candidate. If a new candidate is selected, obtain
its own revision-bound evidence. Keep the shipping-surface screenshots and HTML
audit in `build/` as required by the agent guide; this handoff is not UI proof.

## External blocker and next action

- Failing check: physical acceptance result is `incomplete`, with the 11 false
  gates above. No application crash or engine failure was established.
- Initial worktree error: `Physical acceptance failed: exact-revision notarized distribution evidence is unavailable`.
- Attempted remediation: located the primary checkout through `git worktree list`
  and successfully ran its exact-revision status check. Missing worktree evidence
  is resolved for inspection; the owner-observed matrix remains incomplete.
- Affected image: the exact DMG above; no container or running service is changed.
- Operational impact: release acceptance and publication cannot be completed.
- Escalation recipient: Patrick LaClair, product and release owner.
- Next action: owner-attended system-transition and accessibility session, then
  final artifact/diff/price/license review. Automated retries cannot supply owner
  observations or choose a price.
- Review timing: at the next owner-attended physical session and before any
  publication attempt; no unattended reboot, logout, or gate confirmation is
  scheduled by this task.

## Final owner decision packet

After all physical gates pass, review the exact source diff and artifact hashes,
the final threat model/privacy contract, public MPL source correspondence, and
the shipping license/notice presentation. The license audit confirms bundled
legal text and dependency inventory; it does not approve the product presentation.
Record the actual price, license-presentation approval, selected artifact/revision,
and explicit publish or hold decision with owner and timestamp. No price or
publication approval was supplied by this automated debt request. Keep this debt
open until those observations and decisions have direct evidence.
