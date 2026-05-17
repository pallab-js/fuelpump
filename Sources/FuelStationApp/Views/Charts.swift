import FuelStationCore


import SwiftUI
import Charts

// MARK: - Chart Data Models

struct DailySales: Identifiable {
    let id = UUID()
    let date: Date
    let total: Double
}

struct SalesByMethod: Identifiable {
    let id = UUID()
    let method: String
    let total: Double
}

struct SalesByFuelType: Identifiable {
    let id = UUID()
    let fuelType: String
    let total: Double
    let liters: Double
}

struct WeeklyComparisonItem: Identifiable {
    let id = UUID()
    let day: String
    let amount: Double
    let week: String
}

// MARK: - StorageManager Chart Extensions

extension StorageManager {
    var dailySalesLast7Days: [DailySales] {
        aggregateDailySales(days: 7)
    }

    var dailySalesLast30Days: [DailySales] {
        aggregateDailySales(days: 30)
    }

    private func aggregateDailySales(days: Int) -> [DailySales] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: Double] = [:]

        for i in (0..<days).reversed() {
            if let date = cal.date(byAdding: .day, value: -i, to: today) {
                byDay[date] = 0
            }
        }

        for tx in transactions {
            let txDay = cal.startOfDay(for: tx.date)
            if byDay.keys.contains(txDay) {
                byDay[txDay, default: 0] += tx.amount
            }
        }

        return byDay.sorted(by: { $0.key < $1.key }).map { DailySales(date: $0.key, total: $0.value) }
    }

    func dailySales(from: Date, to: Date) -> [DailySales] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)
        let days = cal.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
        var byDay: [Date: Double] = [:]

        for i in 0...max(days, 0) {
            if let date = cal.date(byAdding: .day, value: i, to: fromDay) {
                byDay[date] = 0
            }
        }

        for tx in transactions where tx.date >= fromDay && tx.date <= toDay + 86399 {
            let txDay = cal.startOfDay(for: tx.date)
            if byDay.keys.contains(txDay) {
                byDay[txDay, default: 0] += tx.amount
            }
        }

        return byDay.sorted(by: { $0.key < $1.key }).map { DailySales(date: $0.key, total: $0.value) }
    }

    func salesByMethod(from: Date, to: Date) -> [SalesByMethod] {
        let rangeTx = transactions.filter { $0.date >= from && $0.date <= to }
        var byMethod: [String: Double] = [:]
        for tx in rangeTx {
            byMethod[tx.paymentMethod, default: 0] += tx.amount
        }
        return byMethod.map { SalesByMethod(method: $0.key, total: $0.value) }
            .sorted(by: { $0.total > $1.total })
    }

    func salesByFuelType(from: Date, to: Date) -> [SalesByFuelType] {
        let rangeTx = transactions.filter { $0.date >= from && $0.date <= to }
        var byFuel: [String: (total: Double, liters: Double)] = [:]
        for tx in rangeTx {
            byFuel[tx.fuelType, default: (0, 0)].total += tx.amount
            byFuel[tx.fuelType, default: (0, 0)].liters += tx.liters
        }
        return byFuel.map { SalesByFuelType(fuelType: $0.key, total: $0.value.total, liters: $0.value.liters) }
            .sorted(by: { $0.liters > $1.liters })
    }

    var todaySalesByMethod: [SalesByMethod] {
        let cal = Calendar.current
        let todayTx = transactions.filter { cal.isDateInToday($0.date) }
        var byMethod: [String: Double] = [:]
        for tx in todayTx {
            byMethod[tx.paymentMethod, default: 0] += tx.amount
        }
        return byMethod.map { SalesByMethod(method: $0.key, total: $0.value) }
            .sorted(by: { $0.total > $1.total })
    }

    var todaySalesByFuelType: [SalesByFuelType] {
        let cal = Calendar.current
        let todayTx = transactions.filter { cal.isDateInToday($0.date) }
        var byFuel: [String: (total: Double, liters: Double)] = [:]
        for tx in todayTx {
            byFuel[tx.fuelType, default: (0, 0)].total += tx.amount
            byFuel[tx.fuelType, default: (0, 0)].liters += tx.liters
        }
        return byFuel.map { SalesByFuelType(fuelType: $0.key, total: $0.value.total, liters: $0.value.liters) }
            .sorted(by: { $0.liters > $1.liters })
    }

    var weeklyComparison: [WeeklyComparisonItem] {
        let cal = Calendar.current
        let today = Date()

        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start,
              let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
              let nextWeekStart = cal.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart)
        else { return [] }

        var thisWeek: [Int: Double] = [:]
        var lastWeek: [Int: Double] = [:]

        for tx in transactions {
            if tx.date >= thisWeekStart, tx.date < nextWeekStart {
                let wd = cal.component(.weekday, from: tx.date)
                thisWeek[wd, default: 0] += tx.amount
            } else if tx.date >= lastWeekStart, tx.date < thisWeekStart {
                let wd = cal.component(.weekday, from: tx.date)
                lastWeek[wd, default: 0] += tx.amount
            }
        }

        return (1...7).flatMap { weekday in
            let dayName = cal.shortWeekdaySymbols[weekday - 1]
            return [
                WeeklyComparisonItem(day: dayName, amount: thisWeek[weekday] ?? 0, week: "This Week"),
                WeeklyComparisonItem(day: dayName, amount: lastWeek[weekday] ?? 0, week: "Last Week"),
            ]
        }
    }
}

// MARK: - Chart Views

struct SalesTrendChart: View {
    let data: [DailySales]

    var body: some View {
        chartCard(title: "Sales Trend") {
            if data.isEmpty || data.allSatisfy({ $0.total == 0 }) {
                ContentUnavailableView("No sales data", systemImage: "chart.line.downtrend.xyaxis", description: Text("Transactions will appear here"))
            } else {
                Chart(data) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Sales", item.total)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Sales", item.total)
                    )
                    .foregroundStyle(.linearGradient(colors: [.blue.opacity(0.15), .blue.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis { AxisMarks { AxisValueLabel() } }
                .chartYScale(domain: .automatic(includesZero: true))
                .accessibilityLabel("Sales trend chart")
                .accessibilityValue("Showing sales over the selected period. Current trend is \(data.last?.total ?? 0) for the most recent day.")
                .accessibilityElement(children: .contain)
            }
        }
    }
}

struct PaymentBreakdownChart: View {
    let data: [SalesByMethod]

    private var total: Double { data.reduce(0) { $0 + $1.total } }

    var body: some View {
        chartCard(title: "Payment Breakdown") {
            if data.isEmpty || total == 0 {
                ContentUnavailableView("No payments today", systemImage: "creditcard", description: Text("Today's transactions will appear here"))
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Method", item.method))
                    .annotation(position: .overlay) {
                        if item.total / total > 0.08 {
                            Text(item.method.prefix(1))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("Payment method: \(item.method)")
                    .accessibilityValue(formatCurrency(item.total))
                }
                .chartLegend(position: .bottom, spacing: 8)
                .chartForegroundStyleScale(mapping: { method in
                    paymentMethodColor(method)
                })
                .accessibilityLabel("Payment breakdown chart")
                .accessibilityValue("Distribution of payment methods today. Total sales: \(formatCurrency(total)).")
            }
        }
    }

    private func paymentMethodColor(_ method: String) -> Color {
        switch method {
        case "Cash": return .green
        case "Card": return .blue
        case "Mobile": return .orange
        case "Fuel Card": return .purple
        default: return .gray
        }
    }
}

struct FuelTypeBarChart: View {
    let data: [SalesByFuelType]

    let fuelColors: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .cyan, .indigo]

    var body: some View {
        chartCard(title: "Fuel Type Sales Today") {
            if data.isEmpty || data.allSatisfy({ $0.liters == 0 }) {
                ContentUnavailableView("No fuel sales today", systemImage: "fuelpump", description: Text("Today's transactions will appear here"))
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Liters", item.liters),
                        y: .value("Fuel Type", item.fuelType)
                    )
                    .foregroundStyle(by: .value("Fuel Type", item.fuelType))
                    .annotation(position: .trailing, spacing: 4) {
                        Text("\(formatVolume(item.liters)) L")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Fuel type: \(item.fuelType)")
                    .accessibilityValue("\(formatVolume(item.liters)) sold")
                }
                .chartLegend(.hidden)
                .chartXAxis { AxisMarks { AxisValueLabel() } }
                .chartXScale(domain: .automatic(includesZero: true))
                .accessibilityLabel("Fuel type sales bar chart")
                .accessibilityValue("Showing sales volume for each fuel type today.")
            }
        }
    }
}

struct TankLevelChart: View {
    let tanks: [FuelTank]

    var body: some View {
        chartCard(title: "Tank Levels") {
            if tanks.isEmpty {
                ContentUnavailableView("No tanks configured", systemImage: "fuelpump", description: Text("Add tanks in Inventory"))
            } else {
                Chart(tanks) { tank in
                    BarMark(
                        x: .value("Fill %", tank.fillRatio * 100),
                        y: .value("Tank", tank.type)
                    )
                    .foregroundStyle(tankFillColor(tank).gradient)
                    .annotation(position: .trailing, spacing: 4) {
                        Text("\(Int(tank.fillRatio * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Tank for \(tank.type)")
                    .accessibilityValue("\(Int(tank.fillRatio * 100)) percent full")
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 20)) { value in
                        AxisValueLabel("\(value.as(Int.self) ?? 0)%")
                    }
                }
                .chartXScale(domain: 0...100)
                .chartLegend(.hidden)
                .accessibilityLabel("Fuel tank levels chart")
                .accessibilityValue("Displays the current capacity percentage of all fuel tanks.")
            }
        }
    }

    private func tankFillColor(_ tank: FuelTank) -> Color {
        if tank.fillRatio < 0.2 { return .red }
        if tank.fillRatio < 0.5 { return .orange }
        return .green
    }
}

struct WeeklyComparisonChart: View {
    let data: [WeeklyComparisonItem]

    var body: some View {
        chartCard(title: "Weekly Comparison") {
            if data.isEmpty || data.allSatisfy({ $0.amount == 0 }) {
                ContentUnavailableView("No data", systemImage: "calendar", description: Text("Compare this week vs last week"))
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Sales", item.amount)
                    )
                    .foregroundStyle(by: .value("Week", item.week))
                    .position(by: .value("Week", item.week))
                    .accessibilityLabel("\(item.day), \(item.week)")
                    .accessibilityValue(formatCurrency(item.amount))
                }
                .chartForegroundStyleScale([
                    "This Week": .blue,
                    "Last Week": .gray.opacity(0.4),
                ])
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, spacing: 8)
                .chartYScale(domain: .automatic(includesZero: true))
                .accessibilityLabel("Weekly sales comparison chart")
                .accessibilityValue("Comparing sales of current week versus previous week.")
            }
        }
    }
}

// MARK: - Shared Card Style

private struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
                .frame(minHeight: 160)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}

@MainActor private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    ChartCard(title: title, content: content)
}
