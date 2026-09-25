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
echo "3. Running core tests against the built module..."

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/main.swift" << 'SWIFT'
import Foundation
import FuelStationCore

func expect(_ condition: Bool, _ msg: String) {
    if condition {
        print("  PASS: \(msg)")
    } else {
        print("FAIL: \(msg)")
        exit(1)
    }
}

// FuelTank
let half = FuelTank(type: "Petrol", capacity: 10000, current: 5000)
expect(half.fillRatio == 0.5, "fillRatio 50%")
expect(FuelTank(type: "Diesel", capacity: 10000, current: 0).fillRatio == 0, "fillRatio empty")
expect(FuelTank(type: "Petrol", capacity: 10000, current: 15000).fillRatio == 1, "fillRatio clamps overfill")
expect(FuelTank(type: "Test", capacity: 0, current: 100).fillRatio == 0, "fillRatio zero capacity")

// dayRange must cover the whole end day (DatePicker yields midnight)
let cal = Calendar.current
let day1 = cal.date(from: DateComponents(year: 2026, month: 9, day: 20))!
let day2 = cal.date(from: DateComponents(year: 2026, month: 9, day: 25))!
let range = dayRange(from: day1, to: day2)
expect(range.start == day1, "dayRange starts at the from-day")
expect(range.endExclusive == cal.date(byAdding: .day, value: 1, to: day2)!, "dayRange end is exclusive")
expect(day2.addingTimeInterval(3600 * 23) < range.endExclusive, "entire end day is inside the range")

// CSV escaping + spreadsheet formula injection
expect(csvField("plain") == "plain", "csv passthrough")
expect(csvField("a,b") == "\"a,b\"", "csv quotes commas")
expect(csvField("say \"hi\"") == "\"say \"\"hi\"\"\"", "csv doubles quotes")
expect(csvField("line\nbreak") == "\"line\nbreak\"", "csv quotes newlines")
expect(csvField("=1+1") == "'=1+1", "csv defuses formula")
expect(csvField("@SUM(A1)") == "'@SUM(A1)", "csv defuses at-formula")
expect(csvField("+1+1") == "'+1+1", "csv defuses plus formula")
expect(csvField("-rm -rf /") == "'-rm -rf /", "csv defuses dash formula")
expect(csvField("-42.5") == "-42.5", "csv keeps negative numbers")

// CSV rows built from real models
let rows = generateCSVRows([
    Delivery(date: day1, supplier: "IOCL, Delhi", fuelType: "Petrol", liters: 2000, cost: 150000)
])
expect(rows.contains("supplier"), "csv header present")
expect(rows.contains("\"IOCL, Delhi\""), "csv escapes supplier with comma")
expect(rows.split(separator: "\n").count == 2, "csv emits header plus one row")

// Settings keep working with data written by older versions (missing keys)
let legacy = """
{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","taxRate":0.18,"currency":"INR",
"lowThreshold":1000,"fuelTypes":["MS (Petrol)"],"backupEnabled":true}
"""
let decoded = try! JSONDecoder().decode(StationSettings.self, from: Data(legacy.utf8))
expect(decoded.fuelTypes == ["MS (Petrol)"], "legacy settings decode fuel types")
expect(decoded.fuelPrices == StationSettings.defaultPrices, "legacy settings fall back to default prices")
expect(!decoded.hasCompletedOnboarding, "legacy settings default onboarding to false")

print("")
print("All tests passed!")
SWIFT

swiftc -I "$BIN_PATH" -L "$BIN_PATH" -lFuelStationCore "$TEST_DIR/main.swift" -o "$TEST_DIR/run_tests"
"$TEST_DIR/run_tests"

echo ""
echo "=== Validation complete ==="
echo "Binary ready at: $BINARY"
echo "Run with: swift run"
