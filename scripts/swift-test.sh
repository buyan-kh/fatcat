#!/usr/bin/env bash
# Builds and actually executes the FatCat swift-testing suite.
# Plain `swift test` under Command Line Tools compiles the tests but silently
# skips running them, so this script loads the bundle through a small runner.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_ROOT="$REPO_ROOT/macos/FatCat"
FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
SWIFT_LIBS="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
RUNNER="$NATIVE_ROOT/.build/fatcat-swift-test-runner"
BUNDLE="$NATIVE_ROOT/.build/debug/FatCatPackageTests.xctest/Contents/MacOS/FatCatPackageTests"

swift build --build-tests --package-path "$NATIVE_ROOT"

if [[ ! -x "$RUNNER" || "$SCRIPT_DIR/run-swift-tests.swift" -nt "$RUNNER" ]]; then
  swiftc "$SCRIPT_DIR/run-swift-tests.swift" \
    -parse-as-library \
    -F "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$SWIFT_LIBS" \
    -o "$RUNNER"
fi

FATCAT_TEST_BUNDLE="$BUNDLE" exec "$RUNNER" "$@"
