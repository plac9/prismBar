# prismBar

See `AGENTS.md` for the authoritative project rules.

## Product

prismBar is a clean-room, privacy-first macOS 27 menu bar workspace. The host owns all Accessibility interactions. Bundled plugins are sandboxed XPC services that contribute bounded commands and declarative native panels without inheriting host authority.

## Primary commands

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodegen generate
swift test
xcodebuild -scheme prismBar -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

## Key documents

- `docs/PRODUCT-BRIEF.md`
- `docs/ARCHITECTURE.md`
- `docs/SECURITY-MODEL.md`
- `docs/CLEAN-ROOM-POLICY.md`
- `docs/IMPLEMENTATION-PLAN.md`
- `DESIGN.md`
