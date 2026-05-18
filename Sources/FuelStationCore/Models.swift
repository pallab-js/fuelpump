import Foundation

public struct FuelTank: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var type: String
    public var capacity: Double
    public var current: Double
    public var lastUpdated: Date

    public init(id: UUID = UUID(), type: String, capacity: Double, current: Double = 0, lastUpdated: Date = .now) {
        self.id = id
        self.type = type
        self.capacity = capacity
        self.current = current
        self.lastUpdated = lastUpdated
    }

    public var fillRatio: Double {
        guard capacity > 0 else { return 0 }
        return min(max(current / capacity, 0), 1)
    }
}

public enum PumpStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active, offline, maintenance
}

public struct Pump: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var number: Int
    public var label: String
    public var fuelType: String
    public var status: PumpStatus
    public var meterReading: Double
    public var lastMaintenance: Date?

    public init(id: UUID = UUID(), number: Int, label: String = "", fuelType: String = "", status: PumpStatus = .active, meterReading: Double = 0, lastMaintenance: Date? = nil) {
        self.id = id
        self.number = number
        self.label = label.isEmpty ? "Pump \(number)" : label
        self.fuelType = fuelType
        self.status = status
        self.meterReading = meterReading
        self.lastMaintenance = lastMaintenance
    }
}

public struct FuelTransaction: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var pumpID: Int
    public var fuelType: String
    public var liters: Double
    public var amount: Double
    public var paymentMethod: String
    public var notes: String?
    public var customerID: UUID?
    public var shiftID: UUID?
    public var attendantName: String?

    public init(id: UUID = UUID(), date: Date = .now, pumpID: Int, fuelType: String, liters: Double, amount: Double, paymentMethod: String, notes: String? = nil, customerID: UUID? = nil, shiftID: UUID? = nil, attendantName: String? = nil) {
        self.id = id
        self.date = date
        self.pumpID = pumpID
        self.fuelType = fuelType
        self.liters = liters
        self.amount = amount
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.customerID = customerID
        self.shiftID = shiftID
        self.attendantName = attendantName
    }
}

public struct Delivery: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var supplier: String
    public var fuelType: String
    public var liters: Double
    public var cost: Double
    public var invoiceRef: String?

    public init(id: UUID = UUID(), date: Date = .now, supplier: String, fuelType: String, liters: Double, cost: Double, invoiceRef: String? = nil) {
        self.id = id
        self.date = date
        self.supplier = supplier
        self.fuelType = fuelType
        self.liters = liters
        self.cost = cost
        self.invoiceRef = invoiceRef
    }
}

public struct Expense: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var category: String
    public var amount: Double
    public var note: String?
    public var receiptPath: String?

    public init(id: UUID = UUID(), date: Date = .now, category: String, amount: Double, note: String? = nil, receiptPath: String? = nil) {
        self.id = id
        self.date = date
        self.category = category
        self.amount = amount
        self.note = note
        self.receiptPath = receiptPath
    }
}

public struct Customer: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var phone: String
    public var email: String?
    public var loyaltyPoints: Int
    public var totalSpent: Double
    public var creditBalance: Double
    public var registrationDate: Date

    public init(id: UUID = UUID(), name: String, phone: String, email: String? = nil, loyaltyPoints: Int = 0, totalSpent: Double = 0, creditBalance: Double = 0, registrationDate: Date = .now) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.loyaltyPoints = loyaltyPoints
        self.totalSpent = totalSpent
        self.creditBalance = creditBalance
        self.registrationDate = registrationDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, phone, email, loyaltyPoints, totalSpent, creditBalance, registrationDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        let encPhone = try container.decode(String.self, forKey: .phone)
        phone = (try? EncryptionManager.shared.decrypt(encPhone)) ?? encPhone
        
        if let encEmail = try container.decodeIfPresent(String.self, forKey: .email) {
            email = (try? EncryptionManager.shared.decrypt(encEmail)) ?? encEmail
        } else {
            email = nil
        }
        
        loyaltyPoints = try container.decode(Int.self, forKey: .loyaltyPoints)
        totalSpent = try container.decode(Double.self, forKey: .totalSpent)
        creditBalance = try container.decode(Double.self, forKey: .creditBalance)
        registrationDate = try container.decode(Date.self, forKey: .registrationDate)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        let encPhone = (try? EncryptionManager.shared.encrypt(phone)) ?? phone
        try container.encode(encPhone, forKey: .phone)
        
        if let email = email {
            let encEmail = (try? EncryptionManager.shared.encrypt(email)) ?? email
            try container.encode(encEmail, forKey: .email)
        }
        
        try container.encode(loyaltyPoints, forKey: .loyaltyPoints)
        try container.encode(totalSpent, forKey: .totalSpent)
        try container.encode(creditBalance, forKey: .creditBalance)
        try container.encode(registrationDate, forKey: .registrationDate)
    }
}

public struct DashboardSection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var isVisible: Bool
    public var order: Int

    public static let defaultSections: [DashboardSection] = [
        DashboardSection(id: "kpi", title: "Key Metrics", isVisible: true, order: 0),
        DashboardSection(id: "charts", title: "Analytics", isVisible: true, order: 1),
        DashboardSection(id: "lowStock", title: "Low Stock Alerts", isVisible: true, order: 2),
        DashboardSection(id: "attendantPerf", title: "Attendant Performance", isVisible: true, order: 3),
        DashboardSection(id: "recentTx", title: "Recent Transactions", isVisible: true, order: 4)
    ]
}

public enum ShiftStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active, closed
}

public struct Shift: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var employeeName: String
    public var attendants: [String]
    public var openingCash: Double
    public var closingCash: Double?
    public var status: ShiftStatus

    public init(id: UUID = UUID(), startTime: Date = .now, endTime: Date? = nil, employeeName: String, attendants: [String] = [], openingCash: Double = 0, closingCash: Double? = nil, status: ShiftStatus = .active) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.employeeName = employeeName
        self.attendants = attendants
        self.openingCash = openingCash
        self.closingCash = closingCash
        self.status = status
    }
}

public struct LubeProduct: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var brand: String
    public var grade: String
    public var unitSize: String
    public var price: Double
    public var stock: Int

    public init(id: UUID = UUID(), name: String, brand: String, grade: String, unitSize: String, price: Double, stock: Int = 0) {
        self.id = id
        self.name = name
        self.brand = brand
        self.grade = grade
        self.unitSize = unitSize
        self.price = price
        self.stock = stock
    }
}

public struct LubeSale: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var productID: UUID
    public var quantity: Int
    public var totalAmount: Double
    public var customerID: UUID?
    public var attendantName: String?

    public init(id: UUID = UUID(), date: Date = .now, productID: UUID, quantity: Int, totalAmount: Double, customerID: UUID? = nil, attendantName: String? = nil) {
        self.id = id
        self.date = date
        self.productID = productID
        self.quantity = quantity
        self.totalAmount = totalAmount
        self.customerID = customerID
        self.attendantName = attendantName
    }
}

public struct StationSettings: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var taxRate: Double
    public var currency: String
    public var lowThreshold: Double
    public var fuelTypes: [String]
    public var backupEnabled: Bool
    public var fuelPrices: [String: Double]
    public var dashboardSections: [DashboardSection]
    public var hasCompletedOnboarding: Bool
    public var gstin: String
    public var upiID: String
    public var stationName: String
    public var address: String
    public var phone: String

    public static let defaultID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
    public static let defaultPrices: [String: Double] = ["MS (Petrol)": 105.41, "HSD (Diesel)": 92.32, "XP/Speed": 110.12]

    public init(id: UUID = StationSettings.defaultID, taxRate: Double = 0.18, currency: String = "INR", lowThreshold: Double = 1000, fuelTypes: [String] = ["MS (Petrol)", "HSD (Diesel)", "XP/Speed"], backupEnabled: Bool = true, fuelPrices: [String: Double] = defaultPrices, dashboardSections: [DashboardSection] = DashboardSection.defaultSections, hasCompletedOnboarding: Bool = false, gstin: String = "", upiID: String = "", stationName: String = "FuelPump Station", address: String = "Main Road", phone: String = "") {
        self.id = id
        self.taxRate = taxRate
        self.currency = currency
        self.lowThreshold = lowThreshold
        self.fuelTypes = fuelTypes
        self.backupEnabled = backupEnabled
        self.fuelPrices = fuelPrices
        self.dashboardSections = dashboardSections
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.gstin = gstin
        self.upiID = upiID
        self.stationName = stationName
        self.address = address
        self.phone = phone
    }

    public enum CodingKeys: String, CodingKey {
        case id, taxRate, currency, lowThreshold, fuelTypes, backupEnabled, fuelPrices, dashboardSections, hasCompletedOnboarding, gstin, upiID, stationName, address, phone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taxRate = try container.decode(Double.self, forKey: .taxRate)
        currency = try container.decode(String.self, forKey: .currency)
        lowThreshold = try container.decode(Double.self, forKey: .lowThreshold)
        fuelTypes = try container.decode([String].self, forKey: .fuelTypes)
        backupEnabled = try container.decode(Bool.self, forKey: .backupEnabled)
        let decodedPrices = try container.decodeIfPresent([String: Double].self, forKey: .fuelPrices) ?? [:]
        fuelPrices = decodedPrices.isEmpty ? StationSettings.defaultPrices : decodedPrices
        dashboardSections = try container.decodeIfPresent([DashboardSection].self, forKey: .dashboardSections) ?? DashboardSection.defaultSections
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        gstin = try container.decodeIfPresent(String.self, forKey: .gstin) ?? ""
        upiID = try container.decodeIfPresent(String.self, forKey: .upiID) ?? ""
        stationName = try container.decodeIfPresent(String.self, forKey: .stationName) ?? "FuelPump Station"
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? "Main Road"
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taxRate, forKey: .taxRate)
        try container.encode(currency, forKey: .currency)
        try container.encode(lowThreshold, forKey: .lowThreshold)
        try container.encode(fuelTypes, forKey: .fuelTypes)
        try container.encode(backupEnabled, forKey: .backupEnabled)
        try container.encode(fuelPrices, forKey: .fuelPrices)
        try container.encode(dashboardSections, forKey: .dashboardSections)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(gstin, forKey: .gstin)
        try container.encode(upiID, forKey: .upiID)
        try container.encode(stationName, forKey: .stationName)
        try container.encode(address, forKey: .address)
        try container.encode(phone, forKey: .phone)
    }
}

public struct AttendantPerformance: Identifiable, Equatable, Hashable {
    public let id = UUID()
    public let name: String
    public var fuelVolume: Double
    public var fuelRevenue: Double
    public var lubeQuantity: Int
    public var lubeRevenue: Double
    
    public init(name: String, fuelVolume: Double = 0, fuelRevenue: Double = 0, lubeQuantity: Int = 0, lubeRevenue: Double = 0) {
        self.name = name
        self.fuelVolume = fuelVolume
        self.fuelRevenue = fuelRevenue
        self.lubeQuantity = lubeQuantity
        self.lubeRevenue = lubeRevenue
    }
}
