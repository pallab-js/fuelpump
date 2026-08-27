import Foundation
import Observation
import CoreData

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
    private let stack = CoreDataStack.shared
    private var pendingSaveTasks: [String: Task<Void, Never>] = [:]
    private let saveDebounceDuration: UInt64 = 400_000_000 // 400ms

    public init() {
        loadAll()
        if pumps.isEmpty {
            initializeDefaultPumps()
        }
    }

    // MARK: - Persistence

    public func loadAll() {
        // Load specific entities
        loadTransactions()
        loadLubeSales()
        
        // Load others from Blobs
        lubeProducts = loadBlob("lubeProducts") ?? []
        fuelTanks = loadBlob("fuelTanks") ?? []
        pumps = loadBlob("pumps") ?? []
        customers = loadBlob("customers") ?? []
        shifts = loadBlob("shifts") ?? []
        deliveries = loadBlob("deliveries") ?? []
        expenses = loadBlob("expenses") ?? []
        settings = loadBlob("settings") ?? StationSettings()
    }

    public func saveAll() {
        pendingSaveTasks.values.forEach { $0.cancel() }
        pendingSaveTasks.removeAll()
        
        saveBlob(lubeProducts, "lubeProducts")
        saveBlob(fuelTanks, "fuelTanks")
        saveBlob(pumps, "pumps")
        saveBlob(customers, "customers")
        saveBlob(shifts, "shifts")
        saveBlob(deliveries, "deliveries")
        saveBlob(expenses, "expenses")
        saveBlob(settings, "settings")
    }

    private func debouncedSave(_ value: some Encodable, _ key: String) {
        pendingSaveTasks[key]?.cancel()
        pendingSaveTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.saveDebounceDuration ?? 400_000_000)
            guard !Task.isCancelled else { return }
            self?.saveBlob(value, key)
        }
    }

    // MARK: - CoreData Helpers

    private func saveBlob<T: Encodable>(_ value: T, _ key: String) {
        // We perform encoding and DB work on a background task
        let dataToSave: Data? = try? encoder.encode(value)
        let backgroundContext = stack.newBackgroundContext()
        
        backgroundContext.perform {
            let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BlobEntity")
            request.predicate = NSPredicate(format: "key == %@", key)
            
            do {
                let results = try backgroundContext.fetch(request)
                let object = results.first ?? NSEntityDescription.insertNewObject(forEntityName: "BlobEntity", into: backgroundContext)
                object.setValue(key, forKey: "key")
                object.setValue(dataToSave, forKey: "data")
                try backgroundContext.save()
            } catch {
                logger.error("Failed to save blob \(key): \(error.localizedDescription)")
            }
        }
    }

    private func loadBlob<T: Decodable>(_ key: String) -> T? {
        let context = stack.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BlobEntity")
        request.predicate = NSPredicate(format: "key == %@", key)
        
        do {
            let results = try context.fetch(request)
            if let data = results.first?.value(forKey: "data") as? Data {
                return try decoder.decode(T.self, from: data)
            }
        } catch {
            logger.error("Failed to load blob \(key): \(error.localizedDescription)")
        }
        return nil
    }

    private func loadTransactions() {
        let backgroundContext = stack.newBackgroundContext()
        var result: [FuelTransaction] = []
        backgroundContext.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TransactionEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            do {
                let fetched = try backgroundContext.fetch(request)
                result = fetched.compactMap { obj in
                    FuelTransaction(
                        id: obj.value(forKey: "id") as? UUID ?? UUID(),
                        date: obj.value(forKey: "date") as? Date ?? .now,
                        pumpID: Int(obj.value(forKey: "pumpID") as? Int64 ?? 0),
                        fuelType: obj.value(forKey: "fuelType") as? String ?? "",
                        liters: obj.value(forKey: "liters") as? Double ?? 0,
                        amount: obj.value(forKey: "amount") as? Double ?? 0,
                        paymentMethod: obj.value(forKey: "paymentMethod") as? String ?? "Cash",
                        notes: obj.value(forKey: "notes") as? String,
                        customerID: obj.value(forKey: "customerID") as? UUID,
                        shiftID: obj.value(forKey: "shiftID") as? UUID,
                        attendantName: obj.value(forKey: "attendantName") as? String
                    )
                }
            } catch {
                logger.error("Failed to load transactions: \(error.localizedDescription)")
            }
        }
        self.transactions = result
    }

    private func loadLubeSales() {
        let backgroundContext = stack.newBackgroundContext()
        var result: [LubeSale] = []
        backgroundContext.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "LubeSaleEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            do {
                let fetched = try backgroundContext.fetch(request)
                result = fetched.compactMap { obj in
                    LubeSale(
                        id: obj.value(forKey: "id") as? UUID ?? UUID(),
                        date: obj.value(forKey: "date") as? Date ?? .now,
                        productID: obj.value(forKey: "productID") as? UUID ?? UUID(),
                        quantity: Int(obj.value(forKey: "quantity") as? Int64 ?? 0),
                        totalAmount: obj.value(forKey: "totalAmount") as? Double ?? 0,
                        customerID: obj.value(forKey: "customerID") as? UUID,
                        attendantName: obj.value(forKey: "attendantName") as? String
                    )
                }
            } catch {
                logger.error("Failed to load lube sales: \(error.localizedDescription)")
            }
        }
        self.lubeSales = result
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
        logger.log("Backup created: \(backupURL.lastPathComponent)")
    }

    public func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let snapshot = try decoder.decode(BackupSnapshot.self, from: data)
        
        try wipeAllData()
        
        lubeProducts = snapshot.lubeProducts
        lubeSales = snapshot.lubeSales
        fuelTanks = snapshot.fuelTanks
        pumps = snapshot.pumps
        customers = snapshot.customers
        shifts = snapshot.shifts
        transactions = snapshot.transactions
        deliveries = snapshot.deliveries
        expenses = snapshot.expenses
        settings = snapshot.settings
        
        // Save back to CoreData
        saveAll()
        for tx in transactions { try? saveTransactionToCoreData(tx) }
        for sale in lubeSales { try? saveLubeSaleToCoreData(sale) }
        
        logger.log("Backup restored from \(url.path)")
    }

    public func backupStore() {
        guard settings.backupEnabled else { return }
        try? createBackup()
    }

    // MARK: - Data Wipe

    public func wipeAllData() throws {
        let context = stack.viewContext
        let entities = ["TransactionEntity", "LubeSaleEntity", "BlobEntity"]
        for name in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
        stack.saveContext()
        
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
        logger.log("All data wiped from CoreData")
    }

    // MARK: - Pumps

    private func initializeDefaultPumps() {
        pumps = (1...8).map { Pump(number: $0, fuelType: settings.fuelTypes.first ?? "Petrol") }
        saveBlob(pumps, "pumps")
    }

    public func addPump(_ pump: Pump) {
        pumps.append(pump)
        saveBlob(pumps, "pumps")
    }

    public func updatePump(_ pump: Pump) {
        guard let idx = pumps.firstIndex(where: { $0.id == pump.id }) else { return }
        pumps[idx] = pump
        debouncedSave(pumps, "pumps")
    }

    public func deletePump(_ id: UUID) {
        pumps.removeAll { $0.id == id }
        saveBlob(pumps, "pumps")
    }

    // MARK: - Customers

    public func addCustomer(_ customer: Customer) {
        customers.append(customer)
        saveBlob(customers, "customers")
    }

    public func updateCustomer(_ customer: Customer) {
        guard let idx = customers.firstIndex(where: { $0.id == customer.id }) else { return }
        customers[idx] = customer
        debouncedSave(customers, "customers")
    }

    public func deleteCustomer(_ id: UUID) {
        customers.removeAll { $0.id == id }
        saveBlob(customers, "customers")
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
        saveBlob(shifts, "shifts")
    }

    public func endShift(closingCash: Double) {
        guard let idx = shifts.firstIndex(where: { $0.status == .active }) else { return }
        var shift = shifts[idx]
        shift.endTime = .now
        shift.closingCash = closingCash
        shift.status = .closed
        shifts[idx] = shift
        saveBlob(shifts, "shifts")
    }

    public func updateShift(_ shift: Shift) {
        guard let idx = shifts.firstIndex(where: { $0.id == shift.id }) else { return }
        shifts[idx] = shift
        debouncedSave(shifts, "shifts")
    }

    public func deleteShift(_ id: UUID) {
        shifts.removeAll { $0.id == id }
        saveBlob(shifts, "shifts")
    }

    // MARK: - Formatting Helpers

    public func formatCurrency(_ value: Double) -> String {
        FuelStationCore.formatCurrency(value, currency: settings.currency, localeIdentifier: settings.currency == "INR" ? "en_IN" : "en_US")
    }

    public func formatVolume(_ value: Double) -> String {
        FuelStationCore.formatVolume(value, localeIdentifier: settings.currency == "INR" ? "en_IN" : "en_US")
    }

    public func makeCurrencyFormatter() -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = settings.currency
        f.locale = Locale(identifier: settings.currency == "INR" ? "en_IN" : "en_US")
        return f
    }

    // MARK: - Lube Shop

    public func addLubeProduct(_ product: LubeProduct) {
        lubeProducts.append(product)
        saveBlob(lubeProducts, "lubeProducts")
    }

    public func updateLubeProduct(_ product: LubeProduct) {
        guard let idx = lubeProducts.firstIndex(where: { $0.id == product.id }) else { return }
        lubeProducts[idx] = product
        debouncedSave(lubeProducts, "lubeProducts")
    }

    public func deleteLubeProduct(_ id: UUID) {
        lubeProducts.removeAll { $0.id == id }
        saveBlob(lubeProducts, "lubeProducts")
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
        saveBlob(lubeProducts, "lubeProducts")
        
        lubeSales.insert(sale, at: 0)
        try? saveLubeSaleToCoreData(sale)
        saveBlob(lubeSales, "lubeSales")
    }
    
    private func saveLubeSaleToCoreData(_ sale: LubeSale) throws {
        let backgroundContext = stack.newBackgroundContext()
        backgroundContext.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "LubeSaleEntity", into: backgroundContext)
            object.setValue(sale.id, forKey: "id")
            object.setValue(sale.date, forKey: "date")
            object.setValue(sale.productID, forKey: "productID")
            object.setValue(Int64(sale.quantity), forKey: "quantity")
            object.setValue(sale.totalAmount, forKey: "totalAmount")
            object.setValue(sale.customerID, forKey: "customerID")
            object.setValue(sale.attendantName, forKey: "attendantName")
            try? backgroundContext.save()
        }
    }

    // MARK: - Fuel Tanks

    public func addTank(_ tank: FuelTank) {
        fuelTanks.append(tank)
        saveBlob(fuelTanks, "fuelTanks")
    }

    public func updateTank(_ tank: FuelTank) {
        guard let idx = fuelTanks.firstIndex(where: { $0.id == tank.id }) else { return }
        fuelTanks[idx] = tank
        saveBlob(fuelTanks, "fuelTanks")
    }

    public func deleteTank(_ id: UUID) {
        fuelTanks.removeAll { $0.id == id }
        saveBlob(fuelTanks, "fuelTanks")
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
        }

        // Update customer loyalty and credit
        if let customerID = txToSave.customerID, let custIdx = customers.firstIndex(where: { $0.id == customerID }) {
            var cust = customers[custIdx]
            cust.totalSpent += txToSave.amount
            cust.loyaltyPoints += Int(txToSave.liters / 10)
            if txToSave.paymentMethod == "Credit" {
                cust.creditBalance += txToSave.amount
            }
            customers[custIdx] = cust
        }

        transactions.insert(txToSave, at: 0)
        saveBlob(fuelTanks, "fuelTanks")
        saveBlob(pumps, "pumps")
        saveBlob(customers, "customers")
        try? saveTransactionToCoreData(txToSave)
    }
    
    private func saveTransactionToCoreData(_ tx: FuelTransaction) throws {
        let backgroundContext = stack.newBackgroundContext()
        backgroundContext.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "TransactionEntity", into: backgroundContext)
            object.setValue(tx.id, forKey: "id")
            object.setValue(tx.date, forKey: "date")
            object.setValue(Int64(tx.pumpID), forKey: "pumpID")
            object.setValue(tx.fuelType, forKey: "fuelType")
            object.setValue(tx.liters, forKey: "liters")
            object.setValue(tx.amount, forKey: "amount")
            object.setValue(tx.paymentMethod, forKey: "paymentMethod")
            object.setValue(tx.notes, forKey: "notes")
            object.setValue(tx.customerID, forKey: "customerID")
            object.setValue(tx.shiftID, forKey: "shiftID")
            object.setValue(tx.attendantName, forKey: "attendantName")
            try? backgroundContext.save()
        }
    }

    public func updateTransaction(_ tx: FuelTransaction) {
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else { return }
        let oldTx = transactions[idx]
        
        // Handle tank level adjustments if liters or fuel type changed
        if oldTx.fuelType == tx.fuelType {
            let delta = tx.liters - oldTx.liters
            if let tankIdx = fuelTanks.firstIndex(where: { $0.type == tx.fuelType }) {
                var tank = fuelTanks[tankIdx]
                tank.current -= delta
                tank.lastUpdated = .now
                fuelTanks[tankIdx] = tank
            }
        } else {
            // Revert old fuel type tank
            if let oldTankIdx = fuelTanks.firstIndex(where: { $0.type == oldTx.fuelType }) {
                var oldTank = fuelTanks[oldTankIdx]
                oldTank.current += oldTx.liters
                fuelTanks[oldTankIdx] = oldTank
            }
            // Deduct from new fuel type tank
            if let newTankIdx = fuelTanks.firstIndex(where: { $0.type == tx.fuelType }) {
                var newTank = fuelTanks[newTankIdx]
                newTank.current -= tx.liters
                fuelTanks[newTankIdx] = newTank
            }
        }

        transactions[idx] = tx
        saveTransactionToCoreDataManual(tx)
        saveBlob(fuelTanks, "fuelTanks")
    }
    
    private func saveTransactionToCoreDataManual(_ tx: FuelTransaction) {
        let backgroundContext = stack.newBackgroundContext()
        backgroundContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TransactionEntity")
            request.predicate = NSPredicate(format: "id == %@", tx.id as CVarArg)
            if let object = try? backgroundContext.fetch(request).first {
                object.setValue(tx.date, forKey: "date")
                object.setValue(Int64(tx.pumpID), forKey: "pumpID")
                object.setValue(tx.fuelType, forKey: "fuelType")
                object.setValue(tx.liters, forKey: "liters")
                object.setValue(tx.amount, forKey: "amount")
                object.setValue(tx.paymentMethod, forKey: "paymentMethod")
                object.setValue(tx.notes, forKey: "notes")
                object.setValue(tx.customerID, forKey: "customerID")
                object.setValue(tx.shiftID, forKey: "shiftID")
                object.setValue(tx.attendantName, forKey: "attendantName")
                try? backgroundContext.save()
            }
        }
    }

    public func deleteTransaction(_ id: UUID) {
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            let tx = transactions[idx]
            // Revert tank levels
            if let tankIdx = fuelTanks.firstIndex(where: { $0.type == tx.fuelType }) {
                var tank = fuelTanks[tankIdx]
                tank.current += tx.liters
                tank.lastUpdated = .now
                fuelTanks[tankIdx] = tank
            }
            transactions.remove(at: idx)
        }
        
        let backgroundContext = stack.newBackgroundContext()
        backgroundContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TransactionEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let object = try? backgroundContext.fetch(request).first {
                backgroundContext.delete(object)
                try? backgroundContext.save()
            }
        }
        saveBlob(fuelTanks, "fuelTanks")
    }

    // MARK: - Deliveries

    public func addDelivery(_ delivery: Delivery) -> Double {
        var excess: Double = 0
        if let tankIdx = fuelTanks.firstIndex(where: { $0.type == delivery.fuelType }) {
            var tank = fuelTanks[tankIdx]
            let newLevel = tank.current + delivery.liters
            if newLevel > tank.capacity {
                excess = newLevel - tank.capacity
                tank.current = tank.capacity
            } else {
                tank.current = newLevel
            }
            tank.lastUpdated = .now
            fuelTanks[tankIdx] = tank
        }
        deliveries.insert(delivery, at: 0)
        saveBlob(fuelTanks, "fuelTanks")
        saveBlob(deliveries, "deliveries")
        return excess
    }

    public func updateDelivery(_ delivery: Delivery) {
        guard let idx = deliveries.firstIndex(where: { $0.id == delivery.id }) else { return }
        deliveries[idx] = delivery
        saveBlob(deliveries, "deliveries")
    }

    public func deleteDelivery(_ id: UUID) {
        deliveries.removeAll { $0.id == id }
        saveBlob(deliveries, "deliveries")
    }

    // MARK: - Expenses

    public func addExpense(_ expense: Expense) {
        expenses.insert(expense, at: 0)
        saveBlob(expenses, "expenses")
    }

    public func updateExpense(_ expense: Expense) {
        guard let idx = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[idx] = expense
        saveBlob(expenses, "expenses")
    }

    public func deleteExpense(_ id: UUID) {
        expenses.removeAll { $0.id == id }
        saveBlob(expenses, "expenses")
    }

    // MARK: - Settings

    public func updateSettings(_ newSettings: StationSettings) {
        settings = newSettings
        debouncedSave(settings, "settings")
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
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
