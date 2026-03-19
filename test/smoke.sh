#!/bin/bash
# Smoke test for cog-swift indexer.
# Builds the binary and runs it against each test fixture, verifying expected symbols.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$ROOT_DIR/.build/debug/cog-swift"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Build
echo "Building cog-swift..."
cd "$ROOT_DIR"
swift build 2>&1 | tail -1

PASS=0
FAIL=0

run_fixture() {
    local fixture_name="$1"
    shift
    local expected_symbols=("$@")
    local fixture_dir="$FIXTURES_DIR/$fixture_name"
    local output="/tmp/cog-swift-smoke-${fixture_name}.scip"

    # Find all .swift files in the fixture
    local swift_files
    swift_files=$(find "$fixture_dir" -name "*.swift" -not -name "Package.swift" | sort)

    echo ""
    echo "=== $fixture_name ==="
    echo "Files: $(echo "$swift_files" | wc -l | tr -d ' ')"

    # Run indexer
    if ! $BIN --output "$output" $swift_files 2>/dev/null; then
        echo "  FAIL: indexer exited non-zero"
        ((FAIL++))
        return
    fi

    # Decode and check for expected symbols
    local decoded
    decoded=$(protoc --decode_raw < "$output" 2>/dev/null)

    local all_passed=true
    for sym in "${expected_symbols[@]}"; do
        if grep -q "$sym" <<< "$decoded"; then
            echo "  OK: found $sym"
            ((PASS++))
        else
            echo "  FAIL: missing $sym"
            ((FAIL++))
            all_passed=false
        fi
    done

    if $all_passed; then
        echo "  All checks passed."
    fi
}

# --- Fixtures ---

run_fixture "simple_project" \
    "Greeter#" \
    "Greeter#name." \
    "Greeter#greeting." \
    "Greeter#init(2)." \
    "Greeter#greet(0)." \
    "Greeter#deinit(0)." \
    "Greeter#subscript(1)." \
    "Speakable#" \
    "Speakable#\\[Voice\\]" \
    "Direction#" \
    "Direction#north." \
    "Direction#south." \
    "Direction#east." \
    "Direction#west." \
    "Direction#opposite." \
    "Result#" \
    "Result#\\[T\\]" \
    "Result#success." \
    "Result#failure." \
    "Point#" \
    "Point#x." \
    "Point#y." \
    "Point#distance(1)." \
    "Counter#" \
    "Counter#count." \
    "Counter#increment(0)." \
    "StringArray#" \
    "topLevelFunction(2)." \
    "globalConstant(0)." \
    "Greeter#speak(0)." \
    "Greeter#Voice#"

run_fixture "nested_types" \
    "Outer#" \
    "Outer#outerProp." \
    "Outer#Inner#" \
    "Outer.Inner#innerProp." \
    "Outer.Inner#DeepNested#" \
    "Outer.Inner.DeepNested#deepProp." \
    "Outer#Status#" \
    "Outer.Status#active." \
    "Outer.Status#inactive." \
    "Outer.Status#Info#" \
    "Outer.Status.Info#detail." \
    "Outer#Helper#" \
    "Outer.Helper#help(0)." \
    "Container#" \
    "Container#\\[T\\]" \
    "Container#items." \
    "Container#Node#" \
    "Container.Node#\\[U\\]" \
    "Container.Node#value."

run_fixture "protocols_extensions" \
    "Drawable#" \
    "Drawable#\\[Color\\]" \
    "Drawable#draw(0)." \
    "Drawable#canvas." \
    "Resizable#" \
    "Resizable#resize(1)." \
    "Circle#" \
    "Circle#radius." \
    "Circle#canvas." \
    "Circle#draw(0)." \
    "Circle#resize(1)." \
    "Circle#diameter." \
    "Circle#area(0)." \
    "Circle#Voice#\|Circle#Color#" \
    "Circle#description."

run_fixture "cross_file_import" \
    "User#" \
    "User#id." \
    "User#name." \
    "User#email." \
    "User#init(3)." \
    "UserService#" \
    "UserService#addUser(1)." \
    "UserService#count(0)." \
    "UserService#subscript(1)." \
    "ServiceError#" \
    "ServiceError#notFound." \
    "ServiceError#unauthorized."

# --- Summary ---
echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
