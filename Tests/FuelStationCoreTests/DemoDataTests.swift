import Foundation
import Testing
@testable import FuelStationCore

/// The seeder wipes and rebuilds the whole store, so it must never run against
/// the real station file: the in-memory store is requested before the shared
/// CoreData stack is first touched, and re-checked before seeding.
@Suite(.serialized)
@MainActor
struct DemoDataTests {
    private func makeStorage() throws -> StorageManager {
        // validate.sh sets this before the process starts so the choice cannot
        // race with the other test threads reading `environ`; the fallback only
        // runs for a bare `swift test`.
        if ProcessInfo.processInfo.environment["FUELSTATION_IN_MEMORY_STORE"] == nil {
            setenv("FUELSTATION_IN_MEMORY_STORE", "1", 1)
        }
        let storage = StorageManager()
        guard CoreDataStack.shared.isInMemoryStore else {
            throw AppError.persistence("CoreData stack is not in-memory; refusing to seed demo data")
        }
        return storage
    }

    @Test func seedCreatesAConsistentStation() throws {
        let storage = try makeStorage()
        try storage.seedDemoData()

        #expect(storage.settings.hasCompletedOnboarding)
        #expect(storage.settings.stationName == "Sharma Fuel Centre")
        #expect(storage.customers.count == StorageManager.demoCustomers.count)
        #expect(storage.lubeProducts.count == StorageManager.demoProducts.count)
        #expect(storage.pumps.count == 6)
        #expect(storage.fuelTanks.count == 3)
        #expect(storage.activeShift != nil)

        // A rich window of history for charts and reports.
        #expect(storage.transactions.count > 400)
        #expect(storage.lubeSales.count >= 20)
        // Tankers are large and infrequent: the 30-day window should include
        // at least a few refills (tanks are topped up below 35%).
        #expect(storage.deliveries.count >= 3)
        #expect(storage.deliveries.allSatisfy { $0.liters > 0 && $0.cost > 0 })
        #expect(storage.expenses.count >= 10)
        #expect(storage.shifts.count == StorageManager.demoDays)
    }

    @Test func seededRecordsArePlausibleAndLinked() throws {
        let storage = try makeStorage()
        try storage.seedDemoData()

        let now = Date()
        #expect(storage.transactions.allSatisfy { $0.date <= now })
        #expect(storage.lubeSales.allSatisfy { $0.date <= now })
        #expect(storage.deliveries.allSatisfy { $0.date <= now })
        #expect(storage.expenses.allSatisfy { $0.date <= now })

        let pumpNumbers = Set(storage.pumps.map(\.number))
        let shiftIDs = Set(storage.shifts.map(\.id))
        let customerIDs = Set(storage.customers.map(\.id))
        #expect(storage.transactions.allSatisfy { pumpNumbers.contains($0.pumpID) })
        #expect(storage.transactions.allSatisfy { $0.shiftID.map(shiftIDs.contains) ?? false })
        #expect(storage.transactions.allSatisfy { $0.amount > 0 && $0.liters > 0 })
        #expect(storage.transactions.allSatisfy { $0.customerID.map(customerIDs.contains) ?? true })

        // Payments cover the breakdown rows, and revenue reconciles.
        let methods = Set(storage.transactions.map(\.paymentMethod))
        #expect(methods.contains("Cash") && methods.contains("UPI"))
        #expect(methods.count >= 3)
        let revenue = storage.transactions.reduce(0) { $0 + $1.amount }
        let paymentTotal = methods.reduce(0.0) { sum, method in
            sum + storage.transactions.filter { $0.paymentMethod == method }.reduce(0) { $0 + $1.amount }
        }
        #expect(revenue > 0)
        // Summed in a different order, so allow for float rounding only.
        #expect(abs(paymentTotal - revenue) < 0.01)

        // Inventory stays in range and one tank is deliberately left low so the
        // low-stock alert shows up in the demo.
        #expect(storage.fuelTanks.allSatisfy { $0.current >= 0 && $0.current <= $0.capacity })
        #expect(!storage.lowTanks.isEmpty)

        // Pump odometers accumulate exactly the seeded volume.
        for pump in storage.pumps {
            let sold = storage.transactions.filter { $0.pumpID == pump.number }.reduce(0.0) { $0 + $1.liters }
            #expect(abs(pump.meterReading - sold) < 0.001)
        }

        // Lube stock never goes negative.
        #expect(storage.lubeProducts.allSatisfy { $0.stock >= 0 })
    }

    @Test func seedingTwiceReplacesRatherThanDuplicates() throws {
        let storage = try makeStorage()
        try storage.seedDemoData()
        let firstCounts = (
            transactions: storage.transactions.count,
            customers: storage.customers.count,
            deliveries: storage.deliveries.count
        )

        try storage.seedDemoData()
        #expect(storage.transactions.count == firstCounts.transactions)
        #expect(storage.customers.count == firstCounts.customers)
        #expect(storage.deliveries.count == firstCounts.deliveries)
        #expect(storage.shifts.count == StorageManager.demoDays)
    }
}
