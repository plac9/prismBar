# Clean-Room Similarity Assurance

## Boundary

The audit compares the independently authored prismBar repository with an archived snapshot of the frozen GPL reference at commit `06f6483c1a7efcad6c3f578505c4d7b1d3bb1e6b`. It reads that commit through `git archive`, never reads uncommitted reference-tree changes, and never modifies either repository. Both reference push URLs must remain disabled.

The audit is an assurance gate, not an implementation input. Its output contains only a pass or fail category plus the two Git revisions. It never emits reference paths, filenames, symbols, strings, snippets, hashes, or source content.

## Detection

`scripts/audit-clean-room-similarity.sh` fails closed for:

- identical content of at least 80 bytes across audited source, test, configuration, documentation, privacy, and asset file types;
- normalized source similarity of 85 percent or greater for Swift, shell, Python, JavaScript, or TypeScript files with at least 30 combined unique nonblank lines;
- an enabled reference push URL;
- an unavailable reference repository or required local audit tool;
- a dirty clean-room source repository outside its synthetic contract tests.

Normalization removes line comments, whitespace, blank lines, and duplicate lines before calculating the Dice similarity coefficient. A line-count upper bound skips pairs that cannot mathematically reach the threshold.

## Verification

`Tests/ReleaseWorkflowTests/clean_room_similarity_contract.sh` proves that the auditor:

- accepts independently authored synthetic fixtures;
- rejects an exact copied implementation file;
- rejects a near-copy with one changed line;
- does not expose synthetic paths, filenames, identifiers, or source content.

The full release CI executes this synthetic contract. The real reference comparison remains a local release gate because the frozen GPL tree is deliberately absent from public CI. Run the real audit from a clean committed revision immediately before producing a release candidate:

```bash
./scripts/audit-clean-room-similarity.sh
```

Any final source or documentation change invalidates the prior result and requires another exact-revision run.
