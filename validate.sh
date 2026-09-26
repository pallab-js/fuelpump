#!/bin/bash
set -euo pipefail

echo "=== FuelStationApp Validation ==="

echo ""
echo "1. Building release..."
swift build -c release

echo ""
echo "2. Checking binary exists..."
BIN_PATH=$(swift build -c release --show-bin-path)
BINARY="$BIN_PATH/FuelStationApp"
if [ -f "$BINARY" ]; then
    echo "   Binary: $BINARY ($(stat -f%z "$BINARY") bytes)"
else
    echo "   ERROR: Binary not found at $BINARY"
    exit 1
fi

echo ""
echo "3. Running core tests..."
# `swift test` (not a hand-rolled swiftc invocation) so SwiftPM owns the
# module search paths and linking on every toolchain/layout.
#
# The store type is chosen before the process starts: tests must never open the
# real station file, and mutating the environment from inside a test races with
# the other test threads reading `environ` (macOS turns that heap corruption
# into a silent SIGTRAP).
if ! FUELSTATION_IN_MEMORY_STORE=1 swift test; then
    echo ""
    echo "   Newest crash report, if any:"
    REPORT=$(ls -t "$HOME/Library/Logs/DiagnosticReports"/*.ips 2>/dev/null | head -1 || true)
    if [ -n "${REPORT:-}" ]; then
        echo "   === $REPORT ==="
        head -c 4000 "$REPORT"
    else
        echo "   (none found)"
    fi
    exit 1
fi

echo ""
echo "=== Validation complete ==="
echo "Binary ready at: $BINARY"
echo "Run with: swift run"
