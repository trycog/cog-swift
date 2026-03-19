# cog-swift

SCIP code intelligence indexer for Swift, built with SwiftSyntax.

## Build

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift test                     # Run tests
```

## Test

```bash
bash test/smoke.sh             # Smoke tests against fixtures
```

## Release Procedure

1. Update version in `cog-extension.json`
2. Commit: `git commit -m "Bump version to X.Y.Z"`
3. Tag: `git tag vX.Y.Z`
4. Push: `git push origin main --tags`
5. GitHub Actions will create the release

Version follows semver. For 0.x: minor = breaking, patch = features/fixes.
