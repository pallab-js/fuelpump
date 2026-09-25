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
    return f.string(from: NSNumber(value: value)) ?? "0.00"
}

public func formatDate(_ date: Date) -> String {
    dateFormatter.string(from: date)
}

public func formatDateOnly(_ date: Date) -> String {
    dateOnlyFormatter.string(from: date)
}

/// Normalizes a user selected `from`/`to` pair into a half-open range that
/// covers the *entire* end day. DatePicker yields midnight for a date only
/// selection, so a naive `date <= to` would silently drop everything recorded
/// on the last day of the range.
public func dayRange(from: Date, to: Date) -> (start: Date, endExclusive: Date) {
    let cal = Calendar.current
    let start = cal.startOfDay(for: from)
    let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to))
        ?? cal.startOfDay(for: to).addingTimeInterval(86_400)
    return (start, endExclusive)
}

/// Escapes a single CSV cell: quotes separators/newlines and defuses
/// spreadsheet formula injection (`=`, `+`, `-`, `@`, tab, CR) for text values.
public func csvField(_ raw: String) -> String {
    var value = raw
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    // Keep plain numbers untouched so negatives stay numeric.
    if Double(trimmed) == nil, let first = value.first, "=+-@\t\r".contains(first) {
        value = "'" + value
    }
    if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
        value = "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

public func generateCSVRows<T: Encodable>(_ items: [T]) -> String {
    guard let first = items.first else { return "" }
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .sortedKeys
    
    guard let data = try? encoder.encode(first),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ""
    }
    
    let headers = Array(json.keys)
    var lines = [headers.map(csvField).joined(separator: ",")]
    
    for item in items {
        guard let itemData = try? encoder.encode(item),
              let itemJson = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any] else {
            continue
        }
        let row = headers.map { key -> String in
            let str = itemJson[key].map { String(describing: $0) } ?? ""
            return csvField(str)
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
