import Foundation
import os

public let logger = Logger(subsystem: "com.fuelstation.app", category: "general")

public enum AppError: LocalizedError {
    case persistence(String)
    case export(String)
    case backup(String)
    case validation(String)

    public var errorDescription: String? {
        switch self {
        case .persistence(let msg): return "Storage error: \(msg)"
        case .export(let msg): return "Export error: \(msg)"
        case .backup(let msg): return "Backup error: \(msg)"
        case .validation(let msg): return "Validation error: \(msg)"
        }
    }
}

public let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

public let dateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

public let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "en_IN")
    return f
}()

public let volumeFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_IN")
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return f
}()

public func formatCurrency(_ value: Double, currency: String = "INR", localeIdentifier: String = "en_IN") -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currency
    f.locale = Locale(identifier: localeIdentifier)
    return f.string(from: NSNumber(value: value)) ?? "\(currency) 0.00"
}

public func formatVolume(_ value: Double, localeIdentifier: String = "en_IN") -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: localeIdentifier)
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    let vol = f.string(from: NSNumber(value: value)) ?? "0.00"
    return "\(vol) Litres"
}

public func formatDate(_ date: Date) -> String {
    dateFormatter.string(from: date)
}

public func formatDateOnly(_ date: Date) -> String {
    dateOnlyFormatter.string(from: date)
}

public func generateCSVRows<T: Encodable>(_ items: [T]) -> String {
    guard let first = items.first else { return "" }
    let mirror = Mirror(reflecting: first)
    let headers = mirror.children.map { $0.label ?? "field" }.joined(separator: ",")
    var lines = [headers]
    for item in items {
        let mirror = Mirror(reflecting: item)
        let row = mirror.children.map { _, value -> String in
            let str = String(describing: value)
            if str.contains(",") || str.contains("\"") || str.contains("\n") {
                let escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            return str
        }.joined(separator: ",")
        lines.append(row)
    }
    return lines.joined(separator: "\n")
}

public func generateJSONString<T: Encodable>(_ items: [T]) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(items)
    return String(data: data, encoding: .utf8) ?? "[]"
}

public func appDataDirectory() -> URL {
    let fm = FileManager.default
    let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let url = appSupport.appendingPathComponent("FuelStationApp", isDirectory: true)
    try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

public func backupsDirectory() -> URL {
    let url = appDataDirectory().appendingPathComponent("Backups", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

public func currentAppVersion() -> String {
    "1.0.0"
}

// MARK: - Localization Helpers

public var fuelStationBundle: Bundle { .module }

public func loc(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}
