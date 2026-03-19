<div align="center">

# cog-swift

**Swift language extension for [Cog](https://github.com/trycog/cog-cli).**

SCIP-based code intelligence and native DWARF debugging for Swift projects.

[Installation](#installation) · [Code Intelligence](#code-intelligence) · [Debugging](#debugging) · [How It Works](#how-it-works) · [Development](#development)

</div>

---

## Installation

### Prerequisites

- [Swift 6.0+](https://www.swift.org/install/)
- [Cog](https://github.com/trycog/cog-cli) CLI installed

### Install

```sh
cog ext:install https://github.com/trycog/cog-swift.git
cog ext:install https://github.com/trycog/cog-swift --version=0.1.0
cog ext:update
cog ext:update cog-swift
```

Cog downloads the tagged GitHub release tarball, then builds locally on the installing machine with `swift build -c release` and installs to `~/.config/cog/extensions/cog-swift/`. `--version` matches an exact release version after optional `v` prefix normalization.

The extension version is defined once in `cog-extension.json`; the build reads that version from the manifest, release tags use `vX.Y.Z`, and the install flag uses the matching bare semver `X.Y.Z`.

---

## Code Intelligence

Configure file patterns in `.cog/settings.json`:

```json
{
  "code": {
    "index": [
      "Sources/**/*.swift",
      "Tests/**/*.swift"
    ]
  }
}
```

Then build the index:

```sh
cog code:index
```

Query symbols:

```sh
cog code:query --find "viewDidLoad"
cog code:query --refs "URLSession"
cog code:query --symbols Sources/App/Models/User.swift
```

A built-in file watcher automatically keeps the index up to date as files change — no manual re-indexing needed after the initial build.

| File Type | Capabilities |
|-----------|--------------|
| `.swift` | Go-to-definition, find references, symbol search, project structure |

By default, successful indexing emits only structured progress events on
stderr so Cog can update file-by-file progress. Set `COG_SWIFT_DEBUG=1` to
enable additional verbose diagnostics.

### Indexing Features

The built-in SCIP indexer supports:

- Classes, structs, enums, protocols, and actors
- Functions and methods (with arity tracking and parameter extraction)
- Properties (stored, computed, static)
- Initializers (`init`, failable `init?`), deinitializers, and subscripts
- Enum cases with associated value parameters
- Extensions with protocol conformance tracking
- Type aliases and associated types
- Generic type parameters
- Imports (module-level)
- Local variables and constants
- Closures with parameter bindings
- Pattern bindings (`if let`, `guard let`, `for-in`)
- Inheritance and conformance relationships
- Doc comment extraction (`///` and `/** */`)
- Nested type declarations
- Deterministic output ordering

---

## Debugging

Start the MCP debug server:

```sh
cog debug:serve
```

Launch a debug-built Swift binary through the debug server for breakpoints, stepping, and variable inspection.

| Setting | Value |
|---------|-------|
| Debugger type | `native` — Cog's built-in DWARF engine |
| Platform support | ptrace (Linux), mach (macOS) |
| Boundary markers | `swift_task_switch`, `_swift_runtime_on_report` |

Boundary markers filter Swift runtime internals from stack traces so you only see your code.

---

## How It Works

Cog invokes `cog-swift` once per extension group. It expands matched files onto
argv, the wrapper distributes that batch across concurrent workers, and it
emits per-file progress events on stderr as each file finishes:

```
cog invokes:      bin/cog-swift --output <output_path> <file_path> [file_path ...]
wrapper executes: in-process SCIP indexing for one or more documents
```

**Auto-discovery:**

| Step | Logic |
|------|-------|
| Workspace root | Walks up from each input file until a directory containing `Package.swift`, `*.xcodeproj`, `*.xcworkspace`, or `.git` is found (fallback: file parent directory). |
| Package name | Parsed from workspace `Package.swift` `name: "..."` field. Falls back to workspace directory name. |
| Indexed target | Every file expanded from `{files}`; output is one SCIP protobuf containing one document per input file. |

### Architecture

```
Sources/CogSwift/
├── main.swift         # Entry point: CLI dispatch, concurrent file processing, SCIP output
├── CLI.swift          # Argument parsing (--output and file paths)
├── Workspace.swift    # Project root discovery and package name extraction
├── Analyzer.swift     # SwiftSyntax AST visitor and symbol extraction
├── Scope.swift        # Scope stack for tracking nested declarations
├── Symbol.swift       # SCIP symbol string builder with escaping
├── SCIP.swift         # SCIP protocol type definitions
└── Protobuf.swift     # Hand-rolled protobuf wire format encoder
```

The only external dependency is [SwiftSyntax](https://github.com/swiftlang/swift-syntax) — Apple's official Swift parser. The protobuf encoder is hand-rolled with no additional dependencies.

---

## Development

### Build from source

```sh
swift build -c release
```

Produces `.build/release/cog-swift`. The Cog build command copies this to `bin/cog-swift`.

Cog installs from GitHub release source tarballs and then runs the same build locally after download.

### Test

```sh
swift test              # Unit tests
bash test/smoke.sh      # Integration smoke tests against fixtures
```

Smoke tests build the indexer, run it against each fixture project, decode the SCIP protobuf output, and verify that expected symbols are present.

### Manual verification

```sh
swift build
.build/debug/cog-swift --output /tmp/index.scip /path/to/Sources/**/*.swift
```

### Indexing diagnostics

Enable verbose indexing diagnostics with:

```sh
COG_SWIFT_DEBUG=1 .build/debug/cog-swift --output /tmp/index.scip /path/to/file.swift 2> /tmp/cog-swift-debug.log
```

With `COG_SWIFT_DEBUG=1`, the wrapper emits structured debug events on stderr for
per-file timing and processing status. When run through `cog code:index` with Cog
debug logging enabled, those non-progress stderr lines are forwarded into
`.cog/cog.log` while progress JSON continues to drive the live TUI.

### Release

- Set the next version in `cog-extension.json`
- Tag releases as `vX.Y.Z` to match Cog's exact-version install flow
- Pushing a matching tag triggers GitHub Actions to verify the tag against `cog-extension.json`, run tests, and create a GitHub Release
- Cog installs from the release source tarball, but the extension still builds locally after download

---

## Acknowledgments

The SCIP protocol types are derived from the [SCIP specification](https://github.com/sourcegraph/scip) by Sourcegraph.

Swift source parsing is powered by [SwiftSyntax](https://github.com/swiftlang/swift-syntax) by Apple.

---

<div align="center">
<sub>Built with <a href="https://www.swift.org">Swift</a></sub>
</div>
