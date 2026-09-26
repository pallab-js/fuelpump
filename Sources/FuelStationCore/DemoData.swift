import Foundation

// MARK: - Demo Data

extension StorageManager {
    /// Days of history created by ``seedDemoData()``.
    public static let demoDays = 30

    /// Replaces every record with a deterministic 30-day demo station so the
    /// app can be explored without real data: tanks, pumps, customers, shifts,
    /// fuel sales, lube sales, deliveries and expenses, all mutually consistent
    /// (tank levels are refilled by deliveries before they run dry, every sale
    /// references an existing pump and shift, no record is dated in the future).
    public func seedDemoData() throws {
        var rng = DemoRandom(seed: 0x5EED_DA7A)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        try wipeAllData()

        // Station identity (wipeAllData resets settings to the defaults).
        var s = settings
        guard s.fuelTypes.count >= 3 else {
            throw AppError.validation("Demo data needs the default three fuel types")
        }
        s.stationName = "Sharma Fuel Centre"
        s.address = "42 MG Road, Bengaluru 560001"
        s.phone = "+91 80 4123 4567"
        s.gstin = "29ABCDE1234F1Z5"
        s.upiID = "sharmafuel@upi"
        s.lowThreshold = 1500
        s.hasCompletedOnboarding = true
        updateSettings(s)

        let petrol = s.fuelTypes[0]
        let diesel = s.fuelTypes[1]
        let xp = s.fuelTypes[2]

        // Pumps: three petrol, two diesel, one premium — one under maintenance.
        pumps = []
        for (number, fuel) in [(1, petrol), (2, petrol), (3, petrol), (4, diesel), (5, diesel), (6, xp)] {
            addPump(Pump(number: number, fuelType: fuel, status: number == 3 ? .maintenance : .active))
        }

        // Tanks: refilled automatically by the day loop when they run low.
        addTank(FuelTank(type: petrol, capacity: 15_000, current: 9_000, lastUpdated: today))
        addTank(FuelTank(type: diesel, capacity: 12_000, current: 7_500, lastUpdated: today))
        addTank(FuelTank(type: xp, capacity: 6_000, current: 3_200, lastUpdated: today))

        for (name, phone, email) in Self.demoCustomers {
            addCustomer(Customer(name: name, phone: phone, email: email))
        }

        for product in Self.demoProducts {
            addLubeProduct(product)
        }

        let staff = ["Ravi Kumar", "Anita Desai", "Suresh Pillai"]

        // Past days: closed shifts, each owning that day's records.
        for offset in stride(from: Self.demoDays - 1, through: 1, by: -1) {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let shiftID = UUID()
            let attendants = [staff[(offset + 1) % staff.count], staff[(offset + 2) % staff.count]]
            let cash = try seedDay(
                day: day,
                shiftID: shiftID,
                attendants: attendants,
                cutoff: nil,
                using: &rng
            )
            let variance = Double.random(in: -500...700, using: &rng).rounded()
            shifts.append(Shift(
                id: shiftID,
                startTime: time(on: day, hour: 7, minute: 0),
                endTime: time(on: day, hour: 21, minute: 0),
                employeeName: staff[offset % staff.count],
                attendants: attendants,
                openingCash: 5_000,
                closingCash: 5_000 + cash + variance,
                status: .closed
            ))
        }

        // Today gets an active shift first, so its sales are tagged with it by
        // `addTransaction`.
        let todayShiftID = UUID()
        shifts.append(Shift(
            id: todayShiftID,
            startTime: time(on: today, hour: 7, minute: 0),
            employeeName: staff[0],
            attendants: [staff[1], staff[2]],
            openingCash: 5_000,
            status: .active
        ))
        saveBlob(shifts, "shifts")

        // Never create records in the future: sales are skipped past this line.
        _ = try seedDay(day: today, shiftID: todayShiftID, attendants: [staff[1], staff[2]], cutoff: Date().addingTimeInterval(-600), using: &rng)

        // Show the low-stock alert in the demo by leaving premium fuel low.
        if let idx = fuelTanks.firstIndex(where: { $0.type == xp }) {
            var tank = fuelTanks[idx]
            tank.current = min(tank.current, 1_200)
            tank.lastUpdated = Date()
            fuelTanks[idx] = tank
        }

        transactions.sort { $0.date > $1.date }
        lubeSales.sort { $0.date > $1.date }
        deliveries.sort { $0.date > $1.date }
        expenses.sort { $0.date > $1.date }
        shifts.sort { $0.startTime > $1.startTime }

        // Persist blobs synchronously and drain the queued CoreData writes.
        flush()
        logger.log("Seeded demo station: \(self.transactions.count) transactions over \(Self.demoDays) days")
    }

    // MARK: - Day

    /// Generates one day of activity and returns the day's cash total (used to
    /// derive a plausible closing balance for the shift).
    private func seedDay(
        day: Date,
        shiftID: UUID,
        attendants: [String],
        cutoff: Date?,
        using rng: inout DemoRandom
    ) throws -> Double {
        // Records must never be dated later than `cutoff` (today only).
        let isPast: (Date) -> Bool = { date in cutoff.map { date <= $0 } ?? true }

        // Refill any tank that fell below 35% before it can run dry.
        for tank in fuelTanks where tank.fillRatio < 0.35 {
            let deliveryDate = time(on: day, hour: 6, minute: 15)
            guard isPast(deliveryDate) else { continue }
            let liters = (tank.capacity * 0.9 - tank.current).rounded()
            guard liters > 0 else { continue }
            let unitPrice = price(for: tank.type)
            let invoiceDay = deliveryDate.formatted(date: .numeric, time: .omitted)
                .replacingOccurrences(of: "/", with: "")
            _ = try addDelivery(Delivery(
                date: deliveryDate,
                supplier: ["Indian Oil", "HPCL", "BPCL"].randomElement(using: &rng)!,
                fuelType: tank.type,
                liters: liters,
                cost: round(liters * unitPrice * 0.9, to: 2),
                invoiceRef: "INV-\(invoiceDay)-\(tank.type.prefix(3))"
            ))
        }

        var cashTotal = 0.0

        for _ in 0..<Int.random(in: 16...28, using: &rng) {
            let fuelType = pickWeighted(Self.demoFuelMix, using: &rng)
            let unitPrice = price(for: fuelType)
            let liters = round(
                Bool.random(withProbability: 0.3, using: &rng)
                    ? Double.random(in: 2...9, using: &rng)
                    : Double.random(in: 12...65, using: &rng),
                to: 1
            )
            var payment = pickWeighted(Self.demoPaymentMix, using: &rng)

            var customerID: UUID?
            if payment == "Credit" {
                // Khata (credit) only makes sense for a registered customer.
                customerID = customers.randomElement(using: &rng)?.id
                if customerID == nil { payment = "UPI" }
            } else if Bool.random(withProbability: 0.4, using: &rng) {
                customerID = customers.randomElement(using: &rng)?.id
            }

            let pumpCandidates = pumps.filter { $0.fuelType == fuelType && $0.status == .active }
            guard let pump = (pumpCandidates.isEmpty ? pumps.filter({ $0.status == .active }) : pumpCandidates)
                .randomElement(using: &rng) else {
                throw AppError.validation("Demo data needs at least one active pump")
            }

            let txDate = time(
                on: day,
                hour: Int.random(in: 7...20, using: &rng),
                minute: Int.random(in: 0...59, using: &rng)
            )
            if let cutoff, txDate > cutoff { continue }

            let amount = round(liters * unitPrice, to: 2)
            if payment == "Cash" { cashTotal += amount }

            try addTransaction(FuelTransaction(
                date: txDate,
                pumpID: pump.number,
                fuelType: fuelType,
                liters: liters,
                amount: amount,
                paymentMethod: payment,
                customerID: customerID,
                shiftID: shiftID,
                attendantName: attendants.randomElement(using: &rng)
            ))
        }

        // Lube shop sales (skipped when stock runs out).
        for _ in 0..<Int.random(in: 0...2, using: &rng) {
            let inStock = lubeProducts.filter { $0.stock > 0 }
            guard let product = inStock.randomElement(using: &rng) else { break }
            let quantity = product.stock >= 3 ? Int.random(in: 1...2, using: &rng) : 1
            try addLubeSale(LubeSale(
                date: time(on: day, hour: Int.random(in: 8...20, using: &rng), minute: Int.random(in: 0...59, using: &rng)),
                productID: product.id,
                quantity: quantity,
                totalAmount: round(Double(quantity) * product.price, to: 2),
                customerID: Bool.random(withProbability: 0.3, using: &rng) ? customers.randomElement(using: &rng)?.id : nil,
                attendantName: attendants.randomElement(using: &rng)
            ))
        }

        // Running costs.
        let expenses: [(date: Date, category: String, amount: Double, note: String?)] = [
            (time(on: day, hour: 10, minute: 0), "Salary", 45_000, "Staff payroll"),
            (time(on: day, hour: 11, minute: 30), "Utilities", 8_400, "Electricity & water"),
            (time(on: day, hour: 15, minute: 0), "Maintenance", round(Double.random(in: 1_200...3_500, using: &rng), to: 0), nil),
            (time(on: day, hour: 16, minute: 0), "Supplies", round(Double.random(in: 300...900, using: &rng), to: 0), nil),
            (time(on: day, hour: 9, minute: 0), "Rent", 35_000, "Godown rent")
        ]
        for expense in expenses where isPast(expense.date) {
            if shouldSeedExpense(expense.category, day: day) {
                addExpense(Expense(date: expense.date, category: expense.category, amount: expense.amount, note: expense.note))
            }
        }

        return cashTotal
    }

    /// Cadence of each running cost over the demo window.
    private func shouldSeedExpense(_ category: String, day: Date) -> Bool {
        let offset = offsetOfDay(day)
        switch category {
        case "Salary": return offset % 7 == 1
        case "Utilities": return offset % 5 == 2
        case "Maintenance": return offset % 3 == 0
        case "Supplies": return offset % 2 == 0
        case "Rent": return offset % 10 == 3
        default: return false
        }
    }

    private func offsetOfDay(_ day: Date) -> Int {
        Calendar.current.dateComponents([.day], from: day, to: Calendar.current.startOfDay(for: .now)).day ?? 0
    }

    private func time(on day: Date, hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private func round(_ value: Double, to decimals: Int) -> Double {
        let factor = pow(10, Double(decimals))
        return (value * factor).rounded() / factor
    }

    private func pickWeighted(_ entries: [(value: String, weight: Int)], using rng: inout DemoRandom) -> String {
        var roll = Int.random(in: 0..<entries.reduce(0) { $0 + $1.weight }, using: &rng)
        for entry in entries {
            roll -= entry.weight
            if roll < 0 { return entry.value }
        }
        return entries[0].value
    }

    // MARK: - Seed content

    static let demoCustomers: [(name: String, phone: String, email: String)] = [
        ("Rahul Verma", "+91 98450 11223", "rahul.verma@example.com"),
        ("Priya Nair", "+91 98860 44556", "priya.nair@example.com"),
        ("Amit Sharma", "+91 99001 77889", "amit.sharma@example.com"),
        ("Sneha Iyer", "+91 97412 33445", "sneha.iyer@example.com"),
        ("Vikram Rao", "+91 90080 66778", "vikram.rao@example.com"),
        ("Fatima Khan", "+91 96325 99001", "fatima.khan@example.com")
    ]

    static let demoProducts: [LubeProduct] = [
        LubeProduct(name: "Engine Oil", brand: "Motul", grade: "5W-30", unitSize: "1 L", price: 620, stock: 40),
        LubeProduct(name: "Engine Oil", brand: "Shell", grade: "10W-40", unitSize: "1 L", price: 720, stock: 35),
        LubeProduct(name: "Engine Oil", brand: "Castrol", grade: "15W-40", unitSize: "3.5 L", price: 2_450, stock: 18),
        LubeProduct(name: "Gear Oil", brand: "Mobil", grade: "80W-90", unitSize: "1 L", price: 480, stock: 20),
        LubeProduct(name: "Brake Fluid", brand: "Bosch", grade: "DOT 4", unitSize: "300 ml", price: 310, stock: 24),
        LubeProduct(name: "Coolant", brand: "Prestone", grade: "Ready Mix", unitSize: "1 L", price: 290, stock: 25),
        LubeProduct(name: "Screen Wash", brand: "3M", grade: "-20°C", unitSize: "1 L", price: 180, stock: 30),
        LubeProduct(name: "Air Filter", brand: "Mahle", grade: "OEM", unitSize: "1 pc", price: 750, stock: 15)
    ]

    static let demoFuelMix: [(value: String, weight: Int)] = [
        ("MS (Petrol)", 50), ("HSD (Diesel)", 35), ("XP/Speed", 15)
    ]

    static let demoPaymentMix: [(value: String, weight: Int)] = [
        ("Cash", 45), ("UPI", 30), ("Card", 12), ("Credit", 8), ("Fuel Card", 5)
    ]
}

/// xorshift64 so the demo station looks identical on every seed.
struct DemoRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private extension Bool {
    static func random(withProbability probability: Double, using rng: inout DemoRandom) -> Bool {
        Double.random(in: 0..<1, using: &rng) < probability
    }
}
