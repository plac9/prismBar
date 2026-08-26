# ADR-001: Clean-room source and MPL-2.0

**Status:** Accepted
**Date:** 2026-08-25
**Deciders:** Patrick LaClair and Codex

## Context

The previous prismBar repository was a GPL-derived fork. GPL permits commercial sale, but its whole-program reciprocal obligations and inherited implementation prevent the product from becoming an independently licensed LaClair Technologies application.

## Decision

Create a new repository with new Git history and no copied implementation artifacts. Preserve the GPL tree in a separate push-disabled reference directory. License the independently authored prismBar host and prismPluginKit source under MPL-2.0.

External code contributions remain closed until a contributor-rights workflow can preserve the owner's ability to offer commercial alternatives later.

## Consequences

### Positive

- Public source and paid distribution can coexist.
- Changes to covered files remain available when binaries are distributed.
- Separate works, including independently licensed plugins, can remain under their own terms.
- Git and source provenance are auditable.

### Negative

- The implementation cannot reuse completed GPL-derived code, tests, strings, configuration, or assets.
- Clean-room and similarity verification add release work.
- External pull requests cannot be accepted immediately.

### Risks

- Recreating familiar behavior could accidentally produce similar implementation details.
- Bundling separately licensed components without a clear process boundary could create licensing ambiguity.

## Alternatives Considered

- **Continue under GPL-3.0:** Legally viable for sale, but does not meet the independent-product and licensing-control objective.
- **MIT or Apache-2.0:** Simpler, but permits closed redistribution of modified host files, conflicting with the public-source continuity goal.
- **Custom source-available license:** Offers more restrictions but would not meet the standard definition of open source and would create adoption and compliance ambiguity.
