import FuelStationCore


import SwiftUI
import UniformTypeIdentifiers

struct DailyClosureView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var declaredCash: Double = 0

    private var currencyFmt: NumberFormatter { storage.makeCurrencyFormatter() }

    init(date: Date = .now) {
        self.date = date
    }

    private var dayTransactions: [FuelTransaction] {
        let cal = Calendar.current
        return storage.transactions.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var dayExpenses: [Expense] {
        let cal = Calendar.current
        return storage.expenses.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var dayDeliveries: [Delivery] {
        let cal = Calendar.current
        return storage.deliveries.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var totalRevenue: Double {
        dayTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalLiters: Double {
        dayTransactions.reduce(0) { $0 + $1.liters }
    }

    private var avgPerTransaction: Double {
        guard !dayTransactions.isEmpty else { return 0 }
        return totalRevenue / Double(dayTransactions.count)
    }

    private var cashTotal: Double {
        total(forMethod: "Cash")
    }

    /// Every payment method actually present in the day, in display order.
    /// Building this dynamically keeps the rows summing to `totalRevenue`
    /// (a hardcoded list drops methods such as UPI and Credit).
    private var paymentTotals: [(method: String, total: Double)] {
        let preferred = ["Cash", "UPI", "Card", "Credit", "Fuel Card", "Mobile"]
        var totals: [String: Double] = [:]
        for tx in dayTransactions {
            totals[tx.paymentMethod, default: 0] += tx.amount
        }
        var rows: [(method: String, total: Double)] = preferred.compactMap { m in
            guard let value = totals[m] else { return nil }
            totals.removeValue(forKey: m)
            return (m, value)
        }
        rows += totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        return rows
    }

    private func total(forMethod method: String) -> Double {
        dayTransactions.filter { $0.paymentMethod == method }.reduce(0) { $0 + $1.amount }
    }

    private func paymentStyle(for method: String) -> (icon: String, color: Color) {
        switch method {
        case "Cash": return ("dollarsign.circle", .green)
        case "UPI", "Mobile": return ("iphone", .orange)
        case "Card": return ("creditcard", .blue)
        case "Credit": return ("person.crop.circle.badge.questionmark", .red)
        case "Fuel Card": return ("fuelpump", .purple)
        default: return ("creditcard", .gray)
        }
    }

    private var fuelTypeSales: [(fuel: String, liters: Double, amount: Double)] {
        var byFuel: [String: (liters: Double, amount: Double)] = [:]
        for tx in dayTransactions {
            byFuel[tx.fuelType, default: (0, 0)].liters += tx.liters
            byFuel[tx.fuelType, default: (0, 0)].amount += tx.amount
        }
        return byFuel.map { ($0.key, $0.value.liters, $0.value.amount) }
            .sorted(by: { $0.liters > $1.liters })
    }

    private var dayShifts: [Shift] {
        let cal = Calendar.current
        return storage.shifts.filter { cal.isDate($0.startTime, inSameDayAs: date) }
    }

    private var totalOpeningCash: Double {
        dayShifts.reduce(0) { $0 + $1.openingCash }
    }

    private var expectedCash: Double {
        cashTotal + totalOpeningCash
    }

    private var cashDifference: Double {
        declaredCash - expectedCash
    }

    private var totalExpensesAmount: Double {
        dayExpenses.reduce(0) { $0 + $1.amount }
    }

    private var totalDeliveriesLiters: Double {
        dayDeliveries.reduce(0) { $0 + $1.liters }
    }

    private var totalDeliveriesCost: Double {
        dayDeliveries.reduce(0) { $0 + $1.cost }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                shiftsSection
                salesSummarySection
                paymentBreakdownSection
                fuelSalesSection
                expensesSection
                deliveriesSection
                cashReconciliationSection
                actionsSection
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 650)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "doc.text.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("Daily Closure Report")
                .font(.title2)
                .fontWeight(.bold)
            Text(date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily closure report for \(date, style: .date)")
    }

    private var shiftsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shifts")
                .font(.headline)
            if dayShifts.isEmpty {
                Text("No shifts recorded for this date")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dayShifts) { shift in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(shift.employeeName)
                                .fontWeight(.medium)
                            Text("\(formatDate(shift.startTime)) - \(shift.endTime.map { formatDate($0) } ?? "Active")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Opening: \(storage.formatCurrency(shift.openingCash))")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private var salesSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sales Summary")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                summaryCard(title: "Revenue", value: storage.formatCurrency(totalRevenue), color: .green)
                summaryCard(title: "Transactions", value: "\(dayTransactions.count)", color: .blue)
                summaryCard(title: "Avg / Tx", value: storage.formatCurrency(avgPerTransaction), color: .orange)
                summaryCard(title: "Total Liters", value: "\(storage.formatVolume(totalLiters)) L", color: .cyan)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .accessibilityLabel("Sales summary section")
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private var paymentBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Breakdown")
                .font(.headline)
            if dayTransactions.isEmpty {
                Text("No transactions for this date")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(paymentTotals.indices, id: \.self) { index in
                    let row = paymentTotals[index]
                    let style = paymentStyle(for: row.method)
                    paymentRow(method: row.method, total: row.total, icon: style.icon, color: style.color)
                }
                Divider()
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(storage.formatCurrency(totalRevenue))
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .accessibilityLabel("Payment breakdown section")
    }

    private func paymentRow(method: String, total: Double, icon: String, color: Color) -> some View {
        let pct = totalRevenue > 0 ? total / totalRevenue * 100 : 0
        return HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(method)
                .frame(width: 100, alignment: .leading)
            ProgressView(value: total, total: totalRevenue)
                .tint(color)
                .frame(maxWidth: .infinity)
            Text(storage.formatCurrency(total))
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            Text("\(Int(pct))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(method) payment: \(storage.formatCurrency(total)), \(Int(pct)) percent of total")
    }

    private var fuelSalesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fuel Sales")
                .font(.headline)
            if fuelTypeSales.isEmpty {
                Text("No fuel sold for this date")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Text("Liters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Text("Revenue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Text("Price/L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                Divider()
                ForEach(fuelTypeSales, id: \.fuel) { fuel, liters, amount in
                    HStack {
                        Text(fuel)
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        Text("\(storage.formatVolume(liters)) L")
                            .frame(width: 80, alignment: .trailing)
                        Text(storage.formatCurrency(amount))
                            .frame(width: 80, alignment: .trailing)
                        Text(storage.formatCurrency(liters > 0 ? amount / liters : 0))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .accessibilityLabel("Fuel sales section")
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Expenses")
                    .font(.headline)
                Spacer()
                if totalExpensesAmount > 0 {
                    Text(storage.formatCurrency(totalExpensesAmount))
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
            if dayExpenses.isEmpty {
                Text("No expenses for this date")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dayExpenses) { expense in
                    HStack {
                        Text(expense.category)
                            .font(.caption)
                        Spacer()
                        Text(storage.formatCurrency(expense.amount))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .accessibilityLabel("Expenses section")
    }

    private var deliveriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Deliveries")
                    .font(.headline)
                Spacer()
                if totalDeliveriesLiters > 0 {
                    Text("\(storage.formatVolume(totalDeliveriesLiters)) L")
                        .fontWeight(.semibold)
                }
            }
            if dayDeliveries.isEmpty {
                Text("No deliveries for this date")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dayDeliveries) { delivery in
                    HStack {
                        Text(delivery.supplier)
                            .font(.caption)
                        Text(delivery.fuelType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(storage.formatVolume(delivery.liters)) L")
                            .font(.caption)
                        Text(storage.formatCurrency(delivery.cost))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .accessibilityLabel("Deliveries section")
    }

    private var cashReconciliationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cash Reconciliation")
                .font(.headline)
            HStack {
                Text("Opening Cash (Shifts)")
                Spacer()
                Text(storage.formatCurrency(totalOpeningCash))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Sales Cash")
                Spacer()
                Text(storage.formatCurrency(cashTotal))
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Text("Total Expected Cash")
                Spacer()
                Text(storage.formatCurrency(expectedCash))
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Declared Cash")
                Spacer()
                TextField("Declared Cash", value: $declaredCash, formatter: currencyFmt)
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Difference")
                Spacer()
                Text(storage.formatCurrency(cashDifference))
                    .fontWeight(.bold)
                    .foregroundStyle(cashDifference >= 0 ? (abs(cashDifference) < 0.01 ? AnyShapeStyle(.primary) : AnyShapeStyle(.green)) : AnyShapeStyle(.red))
            }
            if abs(cashDifference) > 0.01 {
                Text(cashDifference >= 0 ? "Surplus: \(storage.formatCurrency(cashDifference))" : "Shortage: \(storage.formatCurrency(abs(cashDifference)))")
                    .font(.caption)
                    .foregroundStyle(cashDifference >= 0 ? .green : .red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .accessibilityLabel("Cash reconciliation section")
    }

    private var actionsSection: some View {
        HStack(spacing: 16) {
            Button("Export Report (CSV)", systemImage: "square.and.arrow.up") {
                exportCSV()
            }
            .buttonStyle(.bordered)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
private func exportCSV() {
    var lines: [String] = []
    lines.append("Daily Closure Report,\(formatDateOnly(date))")
    lines.append("")
    lines.append("Sales Summary")
    lines.append("Revenue,\(totalRevenue)")
    lines.append("Transactions,\(dayTransactions.count)")
    lines.append("Avg Per Transaction,\(avgPerTransaction)")
    lines.append("Total Liters,\(totalLiters)")
    lines.append("")
    lines.append("Payment Breakdown")
    lines.append("Method,Amount")
    for row in paymentTotals {
        lines.append("\(csvField(row.method)),\(row.total)")
    }
    lines.append("Total,\(totalRevenue)")
    lines.append("")
    lines.append("Fuel Sales")
    lines.append("Type,Liters,Revenue,PricePerLiter")
    for item in fuelTypeSales {
        let ppl = item.liters > 0 ? item.amount / item.liters : 0
        lines.append("\(csvField(item.fuel)),\(item.liters),\(item.amount),\(ppl)")
    }
    lines.append("")
    lines.append("Expenses")
    lines.append("Category,Amount")
    for expense in dayExpenses {
        lines.append("\(csvField(expense.category)),\(expense.amount)")
    }
    lines.append("Total Expenses,\(totalExpensesAmount)")
    lines.append("")
    lines.append("Deliveries")
    lines.append("Supplier,Fuel Type,Liters,Cost")
    for delivery in dayDeliveries {
        lines.append("\(csvField(delivery.supplier)),\(csvField(delivery.fuelType)),\(delivery.liters),\(delivery.cost)")
    }
    lines.append("")
    lines.append("Cash Reconciliation")
    lines.append("Expected Cash,\(expectedCash)")
    lines.append("Declared Cash,\(declaredCash)")
    lines.append("Difference,\(cashDifference)")

    let content = lines.joined(separator: "\n")
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "Closure-\(formatDateOnly(date)).csv"
    panel.allowedContentTypes = [.commaSeparatedText]
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
}

