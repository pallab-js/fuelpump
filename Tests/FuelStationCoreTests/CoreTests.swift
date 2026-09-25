import Foundation
import Testing
@testable import FuelStationCore

// MARK: - FuelTank

@Test func fillRatioIsClamped() {
    #expect(FuelTank(type: "Petrol", capacity: 10_000, current: 5_000).fillRatio == 0.5)
    #expect(FuelTank(type: "Diesel", capacity: 10_000, current: 0).fillRatio == 0)
    #expect(FuelTank(type: "Petrol", capacity: 10_000, current: 15_000).fillRatio == 1)
    #expect(FuelTank(type: "Test", capacity: 0, current: 100).fillRatio == 0)
}

// MARK: - dayRange

@Test func dayRangeCoversTheEntireEndDay() {
    // DatePicker yields midnight for a date-only selection, so the end day must
    // be included in full instead of being cut off at 00:00.
    let cal = Calendar.current
    let from = cal.date(from: DateComponents(year: 2026, month: 9, day: 20))!
    let to = cal.date(from: DateComponents(year: 2026, month: 9, day: 25))!
    let range = dayRange(from: from, to: to)

    #expect(range.start == from)
    #expect(range.endExclusive == cal.date(byAdding: .day, value: 1, to: to)!)
    #expect(to.addingTimeInterval(3600 * 23) < range.endExclusive)
    #expect(range.start < range.endExclusive)
}

@Test func dayRangeNormalizesMidDayBounds() {
    let cal = Calendar.current
    let from = cal.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 13))!
    let to = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 18))!
    let range = dayRange(from: from, to: to)

    #expect(range.start == cal.startOfDay(for: from))
    #expect(range.endExclusive == cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to))!)
}

// MARK: - csvField

@Test func csvFieldEscapesSeparatorsAndQuotes() {
    #expect(csvField("plain") == "plain")
    #expect(csvField("a,b") == "\"a,b\"")
    #expect(csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
    #expect(csvField("line\nbreak") == "\"line\nbreak\"")
    #expect(csvField("line\rbreak") == "\"line\rbreak\"")
}

@Test func csvFieldDefusesFormulaInjection() {
    #expect(csvField("=1+1") == "'=1+1")
    #expect(csvField("@SUM(A1)") == "'@SUM(A1)")
    #expect(csvField("+1+1") == "'+1+1")
    #expect(csvField("-rm -rf /") == "'-rm -rf /")
    #expect(csvField("\tcmd") == "'\tcmd")
    // Numbers keep their value: negatives must stay numeric.
    #expect(csvField("-42.5") == "-42.5")
    #expect(csvField("12,345") == "\"12,345\"")
}

// MARK: - CSV export

@Test func generateCSVEscapesFieldsAndWritesHeader() {
    let rows = generateCSVRows([
        Delivery(date: .now, supplier: "IOCL, Delhi", fuelType: "Petrol", liters: 2_000, cost: 150_000)
    ])

    #expect(rows.contains("supplier"))
    #expect(rows.contains("\"IOCL, Delhi\""))
    #expect(rows.split(separator: "\n").count == 2)
}

// MARK: - Settings compatibility

@Test func legacySettingsStillDecode() throws {
    // Settings written by an older build may miss newly added keys.
    let legacy = """
    {"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","taxRate":0.18,"currency":"INR",
    "lowThreshold":1000,"fuelTypes":["MS (Petrol)"],"backupEnabled":true}
    """
    let decoded = try #require(try? JSONDecoder().decode(StationSettings.self, from: Data(legacy.utf8)))

    #expect(decoded.fuelTypes == ["MS (Petrol)"])
    #expect(decoded.fuelPrices == StationSettings.defaultPrices)
    #expect(!decoded.hasCompletedOnboarding)
}
