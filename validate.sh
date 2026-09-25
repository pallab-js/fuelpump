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
swift test

echo ""
echo "=== Validation complete ==="
echo "Binary ready at: $BINARY"
echo "Run with: swift run"
