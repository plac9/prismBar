# Clean-room Policy

## Purpose

This policy prevents source-license contamination and makes the independent origin of prismBar auditable.

## Reference boundary

The former GPL-derived repository is preserved at `~/dev/prismBar-gpl-reference`. Its fetch remotes remain available for provenance review. All push URLs are disabled.

The new implementation must not copy or adapt from that repository:

- source code or symbol structure
- tests or fixtures
- documentation or user-facing strings
- assets, icons, colors, or layout constants
- build configuration, entitlements, scripts, or project structure
- commit history or authored patches

## Permitted inputs

- independently written product requirements in this repository
- public behavior observed from released applications
- official Apple documentation, sample code, HIG, and SDK interfaces
- standards with compatible licenses and recorded provenance
- independently developed LaClair Technologies code only after an explicit licensing decision

## Development rules

- Tests express the product contract, not the internal behavior of the reference implementation.
- New symbols and module boundaries originate from `docs/ARCHITECTURE.md`.
- Synthetic menu item names are used in tests and screenshots.
- Every dependency requires a license and security review before addition.
- Generated visual assets retain their prompt, source layers, export procedure, and ownership record.
- Similarity audits compare authored source against the reference tree before release. Matches beyond unavoidable API names must be reviewed manually.

## Provenance record

The reference tree was frozen at commit `06f6483c1a7efcad6c3f578505c4d7b1d3bb1e6b` on 2026-08-25. It contained three preserved uncommitted documentation changes. No file from that tree was copied into this repository.

## Release gate

A release is blocked if:

- the reference and product trees share Git ancestry
- a source, asset, test, string, or configuration similarity cannot be explained by a public API or common convention
- a dependency lacks a complete license record
- the distributed source offer does not match the exact shipped MPL-covered revision
