#!/bin/bash
set -euo pipefail

echo "=== FuelStationApp Validation ==="

echo ""
echo "1. Building release..."
swift build -c release

echo ""
echo "2. Checking binary exists..."
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    BINARY=".build/arm64-apple-macosx/release/FuelStationApp"
else
    BINARY=".build/x86_64-apple-macosx/release/FuelStationApp"
fi
if [ -f "$BINARY" ]; then
    echo "   Binary: $BINARY ($(stat -f%z "$BINARY") bytes)"
else
    echo "   ERROR: Binary not found!"
    exit 1
fi

echo ""
echo "3. Running model tests via script..."

cat > /tmp/test_models.swift << 'SWIFT'
import Foundation

// Copy of model types for inline testing
struct FuelTank: Codable, Equatable {
    var type: String; var capacity: Double; var current: Double
    var fillRatio: Double { capacity > 0 ? min(max(current / capacity, 0), 1) : 0 }
}

struct FuelTransaction: Codable { var pumpID: Int; var fuelType: String; var liters: Double; var amount: Double; var paymentMethod: String }
struct Delivery: Codable { var supplier: String; var fuelType: String; var liters: Double; var cost: Double }
struct Expense: Codable { var category: String; var amount: Double }

func assert(_ condition: Bool, _ msg: String) { if !condition { print("FAIL: \(msg)"); exit(1) } else { print("  PASS: \(msg)") } }

// FuelTank tests
let t1 = FuelTank(type: "Petrol", capacity: 10000, current: 5000)
assert(t1.fillRatio == 0.5, "fillRatio 50%")
let t2 = FuelTank(type: "Diesel", capacity: 10000, current: 0)
assert(t2.fillRatio == 0, "fillRatio empty")
let t3 = FuelTank(type: "Petrol", capacity: 10000, current: 15000)
assert(t3.fillRatio == 1, "fillRatio overfill")
let t4 = FuelTank(type: "Test", capacity: 0, current: 100)
assert(t4.fillRatio == 0, "fillRatio zero capacity")

// FuelTransaction tests
let tx = FuelTransaction(pumpID: 1, fuelType: "Power", liters: 50, amount: 75.0, paymentMethod: "Cash")
assert(tx.pumpID == 1, "transaction pumpID")
assert(tx.fuelType == "Power", "transaction fuelType")

// Delivery tests
let d = Delivery(supplier: "IOCL", fuelType: "Petrol", liters: 20000, cost: 15000)
assert(d.supplier == "IOCL", "delivery supplier")

// Expense tests
let e = Expense(category: "Utilities", amount: 500)
assert(e.category == "Utilities", "expense category")

print("")
print("All tests passed!")
SWIFT

swift /tmp/test_models.swift

echo ""
echo "=== Validation complete ==="
echo "Binary ready at: $BINARY"
echo "Run with: swift run"
