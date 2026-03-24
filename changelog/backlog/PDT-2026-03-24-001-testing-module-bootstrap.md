# PDT-2026-03-24-001 Testing Module Bootstrap

## Status

- Current status: `blocked`
- Target release version: `0.1.17`
- Target feature slug: `testing-module-bootstrap`

## User Request

Fix the local toolchain/testing setup so `swift test` works again.

## Constraints

- Prefer a repo-local fix over a machine-specific assumption when the Apple developer install is incomplete.
- Do not break the existing app build or package layout.
- Keep the test command as `swift test`.

## Implementation Intent

- Verify whether the local Apple developer install provides `Testing` or `XCTest`.
- If the machine install is missing required test modules, make the package fetch and link the `swift-testing` package explicitly instead of relying on a bundled toolchain module.
- Keep the existing tests and assertions working with minimal code churn.
- Record the limitation if any Apple-side tooling gaps remain after the repo-side fix.

## Test Conditions

- `swift test` resolves dependencies and runs the existing test suite.
- `swift build` still succeeds.
- The package no longer fails immediately with `error: XCTest not available`.

## Success Criteria

- A fresh checkout on this machine can run `swift test` without requiring a separate Apple-provided `Testing` module.

## Investigation Findings

- The active developer directory is `/Library/Developer/CommandLineTools`.
- `swift test` fails before running tests because `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve a platform path from this Command Line Tools install.
- The local Apple developer install is also missing `XCTest`, `Testing`, and `CompilerPluginSupport` artifacts that SwiftPM expects.
- `softwareupdate --list` shows only Safari and macOS system updates, not a standalone Command Line Tools repair package.
- Fixing this fully requires an Apple-side developer tools reinstall or a full Xcode install outside the repository.
