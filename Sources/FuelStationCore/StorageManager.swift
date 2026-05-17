import Foundation
import Observation

@Observable
@MainActor
public final class StorageManager {
    public var lubeProducts: [LubeProduct] = []
    public var lubeSales: [LubeSale] = []
    public var fuelTanks: [FuelTank] = []
    public var pumps: [Pump] = []
    public var customers: [Customer] = []
    public var shifts: [Shift] = []
    public var transactions: [FuelTransaction] = []
    public var deliveries: [Delivery] = []
    public var expenses: [Expense] = []
    public var settings: StationSettings = StationSettings()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        loadAll()
        if pumps.isEmpty {
            initializeDefaultPumps()
        }
    }

    // MARK: - Persistence

    public func loadAll() {
        lubeProducts = loadJSON("lubeProducts") ?? []
        lubeSales = loadJSON("lubeSales") ?? []
        fuelTanks = loadJSON("fuelTanks") ?? []
        pumps = loadJSON("pumps") ?? []
        customers = loadJSON("customers") ?? []
        shifts = loadJSON("shifts") ?? []
        transactions = loadJSON("transactions") ?? []
        deliveries = loadJSON("deliveries") ?? []
        expenses = loadJSON("expenses") ?? []
        settings = loadJSON("settings") ?? StationSettings()
    }

    public func saveAll() {
        saveJSON(lubeProducts, "lubeProducts")
        saveJSON(lubeSales, "lubeSales")
        saveJSON(fuelTanks, "fuelTanks")
        saveJSON(pumps, "pumps")
        saveJSON(customers, "customers")
        saveJSON(shifts, "shifts")
        saveJSON(transactions, "transactions")
        saveJSON(deliveries, "deliveries")
        saveJSON(expenses, "expenses")
        saveJSON(settings, "settings")
    }

    private func saveJSON<T: Encodable>(_ value: T, _ name: String) {
        let url = appDataDirectory().appendingPathComponent("\(name).json")
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save \(name): \(error.localizedDescription)")
        }
    }

    private func loadJSON<T: Decodable>(_ name: String) -> T? {
        let url = appDataDirectory().appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Failed to load \(name): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Backup

    public func createBackup() throws {
        saveAll()
        let dateStr = formatDateOnly(Date())
        let backupURL = backupsDirectory().appendingPathComponent("backup-\(dateStr).json")
        let snapshot = BackupSnapshot(
            lubeProducts: lubeProducts,
            lubeSales: lubeSales,
            fuelTanks: fuelTanks,
            pumps: pumps,
            customers: customers,
            shifts: shifts,
            transactions: transactions,
            deliveries: deliveries,
            expenses: expenses,
            settings: settings
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: backupURL, options: .atomic)
        logger.log("Backup created at \(backupURL.path)")
    }

    public func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let snapshot = try decoder.decode(BackupSnapshot.self, from: data)
        settings = snapshot.settings
        lubeProducts = snapshot.lubeProducts
        lubeSales = snapshot.lubeSales
        fuelTanks = snapshot.fuelTanks
        pumps = snapshot.pumps
        customers = snapshot.customers
        shifts = snapshot.shifts
        transactions = snapshot.transactions
        deliveries = snapshot.deliveries
        expenses = snapshot.expenses
        saveAll()
        logger.log("Backup restored from \(url.path)")
    }

    public func backupStore() {
        guard settings.backupEnabled else { return }
        try? createBackup()
    }

    // MARK: - Data Wipe

    public func wipeAllData() throws {
        let fm = FileManager.default
        let dir = appDataDirectory()
        let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        for url in contents where url.pathExtension == "json" {
            try fm.removeItem(at: url)
        }
        lubeProducts = []
        lubeSales = []
        fuelTanks = []
        pumps = []
        customers = []
        shifts = []
        transactions = []
        deliveries = []
        expenses = []
        settings = StationSettings()
        initializeDefaultPumps()
        saveAll()
        logger.log("All data wiped")
    }

    // MARK: - Pumps

    private func initializeDefaultPumps() {
        pumps = (1...8).map { Pump(number: $0, fuelType: settings.fuelTypes.first ?? "Petrol") }
        saveJSON(pumps, "pumps")
    }

    public func addPump(_ pump: Pump) {
        pumps.append(pump)
        saveJSON(pumps, "pumps")
    }

    public func updatePump(_ pump: Pump) {
        guard let idx = pumps.firstIndex(where: { $0.id == pump.id }) else { return }
        pumps[idx] = pump
        saveJSON(pumps, "pumps")
    }

    public func deletePump(_ id: UUID) {
        pumps.removeAll { $0.id == id }
        saveJSON(pumps, "pumps")
    }

    // MARK: - Customers

    public func addCustomer(_ customer: Customer) {
        customers.append(customer)
        saveJSON(customers, "customers")
    }

    public func updateCustomer(_ customer: Customer) {
        guard let idx = customers.firstIndex(where: { $0.id == customer.id }) else { return }
        customers[idx] = customer
        saveJSON(customers, "customers")
    }

    public func deleteCustomer(_ id: UUID) {
        customers.removeAll { $0.id == id }
        saveJSON(customers, "customers")
    }

    public func customer(for id: UUID) -> Customer? {
        customers.first { $0.id == id }
    }

    // MARK: - Shifts

    public var activeShift: Shift? {
        shifts.first { $0.status == .active }
    }

    public func startShift(employeeName: String, attendants: [String] = [], openingCash: Double) {
        let shift = Shift(employeeName: employeeName, attendants: attendants, openingCash: openingCash)
        shifts.append(shift)
        saveJSON(shifts, "shifts")
    }

    public func endShift(closingCash: Double) {
        guard let idx = shifts.firstIndex(where: { $0.status == .active }) else { return }
        var shift = shifts[idx]
        shift.endTime = .now
        shift.closingCash = closingCash
        shift.status = .closed
        shifts[idx] = shift
        saveJSON(shifts, "shifts")
    }

    public func updateShift(_ shift: Shift) {
        guard let idx = shifts.firstIndex(where: { $0.id == shift.id }) else { return }
        shifts[idx] = shift
        saveJSON(shifts, "shifts")
    }

    public func deleteShift(_ id: UUID) {
        shifts.removeAll { $0.id == id }
        saveJSON(shifts, "shifts")
    }

    // MARK: - Formatting Helpers

    public func formatCurrency(_ value: Double) -> String {
        FuelStationCore.formatCurrency(value, currency: settings.currency, localeIdentifier: settings.currency == "INR" ? "en_IN" : "en_US")
    }

    public func formatVolume(_ value: Double) -> String {
        FuelStationCore.formatVolume(value, localeIdentifier: settings.currency == "INR" ? "en_IN" : "en_US")
    }

    // MARK: - Lube Shop

    public func addLubeProduct(_ product: LubeProduct) {
        lubeProducts.append(product)
        saveJSON(lubeProducts, "lubeProducts")
    }

    public func updateLubeProduct(_ product: LubeProduct) {
        guard let idx = lubeProducts.firstIndex(where: { $0.id == product.id }) else { return }
        lubeProducts[idx] = product
        saveJSON(lubeProducts, "lubeProducts")
    }

    public func deleteLubeProduct(_ id: UUID) {
        lubeProducts.removeAll { $0.id == id }
        saveJSON(lubeProducts, "lubeProducts")
    }

    public func addLubeSale(_ sale: LubeSale) throws {
        guard let idx = lubeProducts.firstIndex(where: { $0.id == sale.productID }) else {
            throw AppError.validation("Product not found")
        }
        
        var product = lubeProducts[idx]
        guard product.stock >= sale.quantity else {
            throw AppError.validation("Insufficient stock for \(product.name). Available: \(product.stock)")
        }
        
        product.stock -= sale.quantity
        lubeProducts[idx] = product
        saveJSON(lubeProducts, "lubeProducts")
        
        lubeSales.append(sale)
        saveJSON(lubeSales, "lubeSales")
    }

    // MARK: - Fuel Tanks

    public func addTank(_ tank: FuelTank) {
        fuelTanks.append(tank)
        saveJSON(fuelTanks, "fuelTanks")
    }

    public func updateTank(_ tank: FuelTank) {
        guard let idx = fuelTanks.firstIndex(where: { $0.id == tank.id }) else { return }
        fuelTanks[idx] = tank
        saveJSON(fuelTanks, "fuelTanks")
    }

    public func deleteTank(_ id: UUID) {
        fuelTanks.removeAll { $0.id == id }
        saveJSON(fuelTanks, "fuelTanks")
    }

    public func tankLowThreshold() -> Double {
        settings.lowThreshold
    }

    // MARK: - Transactions

    public func addTransaction(_ tx: FuelTransaction) throws {
        var txToSave = tx
        if let activeShift {
            txToSave.shiftID = activeShift.id
        }

        // Update tank levels
        guard let tankIdx = fuelTanks.firstIndex(where: { $0.type == txToSave.fuelType }) else {
            throw AppError.validation("No tank found for fuel type: \(txToSave.fuelType)")
        }
        
        var tank = fuelTanks[tankIdx]
        guard tank.current >= txToSave.liters else {
            throw AppError.validation("Insufficient fuel in \(tank.type) tank. Available: \(FuelStationCore.formatVolume(tank.current))")
        }
        
        tank.current -= txToSave.liters
        tank.lastUpdated = .now
        fuelTanks[tankIdx] = tank
        
        // Update pump meter reading
        if let pumpIdx = pumps.firstIndex(where: { $0.number == txToSave.pumpID }) {
            var pump = pumps[pumpIdx]
            pump.meterReading += txToSave.liters
            pumps[pumpIdx] = pump
            saveJSON(pumps, "pumps")
        }

        // Update customer loyalty and credit
        if let customerID = txToSave.customerID, let custIdx = customers.firstIndex(where: { $0.id == customerID }) {
            var cust = customers[custIdx]
            cust.totalSpent += txToSave.amount
            // Award 1 point per 10 litres
            cust.loyaltyPoints += Int(txToSave.liters / 10)

            // If payment method is Credit, increase balance
            if txToSave.paymentMethod == "Credit" {
                cust.creditBalance += txToSave.amount
            }

            customers[custIdx] = cust
            saveJSON(customers, "customers")
        }

        transactions.append(txToSave)
        saveJSON(transactions, "transactions")
        saveJSON(fuelTanks, "fuelTanks")
    }

    public func updateTransaction(_ tx: FuelTransaction) {
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else { return }
        transactions[idx] = tx
        saveJSON(transactions, "transactions")
    }

    public func deleteTransaction(_ id: UUID) {
        transactions.removeAll { $0.id == id }
        saveJSON(transactions, "transactions")
    }

    // MARK: - Deliveries

    public func addDelivery(_ delivery: Delivery) {
        if let tankIdx = fuelTanks.firstIndex(where: { $0.type == delivery.fuelType }) {
            var tank = fuelTanks[tankIdx]
            tank.current = min(tank.capacity, tank.current + delivery.liters)
            tank.lastUpdated = .now
            fuelTanks[tankIdx] = tank
        }
        deliveries.append(delivery)
        saveJSON(deliveries, "deliveries")
        saveJSON(fuelTanks, "fuelTanks")
    }

    public func updateDelivery(_ delivery: Delivery) {
        guard let idx = deliveries.firstIndex(where: { $0.id == delivery.id }) else { return }
        deliveries[idx] = delivery
        saveJSON(deliveries, "deliveries")
    }

    public func deleteDelivery(_ id: UUID) {
        deliveries.removeAll { $0.id == id }
        saveJSON(deliveries, "deliveries")
    }

    // MARK: - Expenses

    public func addExpense(_ expense: Expense) {
        expenses.append(expense)
        saveJSON(expenses, "expenses")
    }

    public func updateExpense(_ expense: Expense) {
        guard let idx = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[idx] = expense
        saveJSON(expenses, "expenses")
    }

    public func deleteExpense(_ id: UUID) {
        expenses.removeAll { $0.id == id }
        saveJSON(expenses, "expenses")
    }

    // MARK: - Settings

    public func updateSettings(_ newSettings: StationSettings) {
        settings = newSettings
        saveJSON(settings, "settings")
    }

    public func price(for fuelType: String) -> Double {
        settings.fuelPrices[fuelType] ?? 1.50
    }

    public func setPrice(_ price: Double, for fuelType: String) {
        var s = settings
        s.fuelPrices[fuelType] = max(0, price)
        updateSettings(s)
    }

    public func calculatedAmount(liters: Double, fuelType: String) -> Double {
        liters * price(for: fuelType)
    }

    // MARK: - Computed

    public var todayTransactions: [FuelTransaction] {
        let cal = Calendar.current
        return transactions.filter { cal.isDateInToday($0.date) }
    }

    public var todayExpenses: [Expense] {
        expenses.filter { Calendar.current.isDateInToday($0.date) }
    }

    public var todayDeliveries: [Delivery] {
        deliveries.filter { Calendar.current.isDateInToday($0.date) }
    }

    public var todaySalesTotal: Double {
        todayTransactions.reduce(0) { $0 + $1.amount }
    }

    public var todayTransactionsCount: Int {
        todayTransactions.count
    }

    public var todayExpensesTotal: Double {
        todayExpenses.reduce(0) { $0 + $1.amount }
    }

    public var todayDeliveriesTotalLiters: Double {
        todayDeliveries.reduce(0) { $0 + $1.liters }
    }

    public var todayDeliveriesTotalCost: Double {
        todayDeliveries.reduce(0) { $0 + $1.cost }
    }

    public var todayCashTotal: Double {
        todayTransactions.filter { $0.paymentMethod == "Cash" }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Date Range Queries

    public func transactions(from: Date, to: Date) -> [FuelTransaction] {
        transactions.filter { $0.date >= from && $0.date <= to }
    }

    public func expenses(from: Date, to: Date) -> [Expense] {
        expenses.filter { $0.date >= from && $0.date <= to }
    }

    public func deliveries(from: Date, to: Date) -> [Delivery] {
        deliveries.filter { $0.date >= from && $0.date <= to }
    }

    public func totalRevenue(from: Date, to: Date) -> Double {
        transactions(from: from, to: to).reduce(0) { $0 + $1.amount }
    }

    public func totalExpenses(from: Date, to: Date) -> Double {
        expenses(from: from, to: to).reduce(0) { $0 + $1.amount }
    }

    public func totalDeliveriesCost(from: Date, to: Date) -> Double {
        deliveries(from: from, to: to).reduce(0) { $0 + $1.cost }
    }

    public func grossProfit(from: Date, to: Date) -> Double {
        totalRevenue(from: from, to: to) - totalExpenses(from: from, to: to) - totalDeliveriesCost(from: from, to: to)
    }

    public func attendantPerformance(from: Date, to: Date) -> [AttendantPerformance] {
        var perfMap: [String: AttendantPerformance] = [:]
        
        let txs = transactions(from: from, to: to)
        for tx in txs {
            let name = tx.attendantName ?? "Unspecified"
            if perfMap[name] == nil {
                perfMap[name] = AttendantPerformance(name: name)
            }
            perfMap[name]?.fuelVolume += tx.liters
            perfMap[name]?.fuelRevenue += tx.amount
        }
        
        let sales = lubeSales.filter { $0.date >= from && $0.date <= to }
        for sale in sales {
            let name = sale.attendantName ?? "Unspecified"
            if perfMap[name] == nil {
                perfMap[name] = AttendantPerformance(name: name)
            }
            perfMap[name]?.lubeQuantity += sale.quantity
            perfMap[name]?.lubeRevenue += sale.totalAmount
        }
        
        return perfMap.values.sorted { $0.fuelRevenue > $1.fuelRevenue }
    }

    public var lowTanks: [FuelTank] {
        fuelTanks.filter { $0.current < settings.lowThreshold }
    }

    public var totalRevenue: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    public var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    public var totalDeliveriesCost: Double {
        deliveries.reduce(0) { $0 + $1.cost }
    }

    public var grossProfit: Double {
        totalRevenue - totalExpenses - totalDeliveriesCost
    }

    // MARK: - Full Export

    public func fullExportJSON() throws -> String {
        let snapshot = BackupSnapshot(
            lubeProducts: lubeProducts,
            lubeSales: lubeSales,
            fuelTanks: fuelTanks,
            pumps: pumps,
            customers: customers,
            shifts: shifts,
            transactions: transactions,
            deliveries: deliveries,
            expenses: expenses,
            settings: settings
        )
        let data = try encoder.encode(snapshot)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public struct BackupSnapshot: Codable {
    public let lubeProducts: [LubeProduct]
    public let lubeSales: [LubeSale]
    public let fuelTanks: [FuelTank]
    public let pumps: [Pump]
    public let customers: [Customer]
    public let shifts: [Shift]
    public let transactions: [FuelTransaction]
    public let deliveries: [Delivery]
    public let expenses: [Expense]
    public let settings: StationSettings
}
