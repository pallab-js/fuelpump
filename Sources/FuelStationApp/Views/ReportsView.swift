import FuelStationCore


import SwiftUI
import UniformTypeIdentifiers

struct ReportsView: View {
    @Environment(StorageManager.self) private var storage
    @State private var dateFrom: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
    @State private var dateTo: Date = .now
    @State private var showingExport = false

    private var rangeTx: [FuelTransaction] {
        storage.transactions(from: dateFrom, to: dateTo)
    }

    private var rangeExpenses: [Expense] {
        storage.expenses(from: dateFrom, to: dateTo)
    }

    private var rangeDeliveries: [Delivery] {
        storage.deliveries(from: dateFrom, to: dateTo)
    }

    private var revenue: Double { rangeTx.reduce(0) { $0 + $1.amount } }
    private var totalExpenses: Double { rangeExpenses.reduce(0) { $0 + $1.amount } }
    private var totalDeliveriesCost: Double { rangeDeliveries.reduce(0) { $0 + $1.cost } }
    private var profit: Double { revenue - totalExpenses - totalDeliveriesCost }
    private var txCount: Int { rangeTx.count }
    private var avgPerTx: Double { txCount > 0 ? revenue / Double(txCount) : 0 }
    @State private var selectedClosureDate: ClosureDateWrapper?

    var body: some View {
    ScrollView {
        VStack(spacing: 16) {
            dateSection
            profitLossSection
            taxSummarySection
            salesTrendSection
            breakdownSection
            dailyTableSection
            actionsSection
        }
        .padding()
    }
    .sheet(item: $selectedClosureDate) { wrapper in
        NavigationStack {
            DailyClosureView(date: wrapper.date)
        }
    }
}
    
    private var taxSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GST & Tax Summary")
                    .font(.headline)
                Spacer()
                Text("Rate: \(Int(storage.settings.taxRate * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let taxRate = storage.settings.taxRate
            let taxableValue = revenue / (1 + taxRate)
            let totalTax = revenue - taxableValue
            let cgst = totalTax / 2
            let sgst = totalTax / 2
            
            HStack(spacing: 16) {
                plCard("Taxable Value", value: formatCurrency(taxableValue), color: .primary)
                plCard("CGST", value: formatCurrency(cgst), color: .orange)
                plCard("SGST", value: formatCurrency(sgst), color: .orange)
                plCard("Total Tax", value: formatCurrency(totalTax), color: .red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private var dateSection: some View {
        VStack(spacing: 8) {
            HStack {
                HStack {
                    Text("From", bundle: fuelStationBundle)
                    DatePicker("From", selection: $dateFrom, displayedComponents: .date)
                        .labelsHidden()
                }
                HStack {
                    Text("To", bundle: fuelStationBundle)
                    DatePicker("To", selection: $dateTo, displayedComponents: .date)
                        .labelsHidden()
                }
                Spacer()
                HStack(spacing: 4) {
                    presetButton("Today", days: 0)
                    presetButton("7 Days", days: 7)
                    presetButton("30 Days", days: 30)
                    presetButton("90 Days", days: 90)
                    presetButton("Year", days: 365)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private func presetButton(_ label: String, days: Int) -> some View {
        Button(label) {
            dateTo = .now
            dateFrom = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var profitLossSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profit & Loss Summary", bundle: fuelStationBundle)
                .font(.headline)
            HStack(spacing: 16) {
                plCard("Revenue", value: formatCurrency(revenue), color: .green)
                plCard("Expenses", value: formatCurrency(totalExpenses), color: .red)
                plCard("Deliveries Cost", value: formatCurrency(totalDeliveriesCost), color: .orange)
                plCard("Gross Profit", value: formatCurrency(profit), color: profit >= 0 ? .green : .red)
            }
            HStack(spacing: 16) {
                infoCard("Transactions", value: "\(txCount)")
                infoCard("Avg / Tx", value: formatCurrency(avgPerTx))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private func plCard(_ title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).fontWeight(.bold).foregroundStyle(color)
            Text(title, bundle: fuelStationBundle)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.background))
        .accessibilityElement(children: .combine)
    }

    private func infoCard(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).fontWeight(.bold)
            Text(title, bundle: fuelStationBundle)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.background))
        .accessibilityElement(children: .combine)
    }

    private var salesTrendSection: some View {
        SalesTrendChart(data: storage.dailySales(from: dateFrom, to: dateTo))
    }

    private var breakdownSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            PaymentBreakdownChart(data: storage.salesByMethod(from: dateFrom, to: dateTo))
            FuelTypeBarChart(data: storage.salesByFuelType(from: dateFrom, to: dateTo))
        }
    }

    private var dailyTableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Breakdown", bundle: fuelStationBundle)
                .font(.headline)
            let daily = storage.dailySales(from: dateFrom, to: dateTo)
            if daily.isEmpty || daily.allSatisfy({ $0.total == 0 }) {
                Text("No transactions in this period", bundle: fuelStationBundle)
                    .foregroundStyle(.secondary)
            } else {
                Table(daily) {
                    TableColumn("Date") { item in
                        Text(item.date, style: .date)
                            .font(.caption)
                    }
                    .width(120)
                    TableColumn("Sales") { item in
                        Text(formatCurrency(item.total))
                            .font(.caption).fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("Report") { item in
                        Button("View") {
                            selectedClosureDate = ClosureDateWrapper(item.date)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .width(60)
                }
                .tableStyle(.bordered)
                .frame(minHeight: 150)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private var actionsSection: some View {
        HStack(spacing: 16) {
            Button("Export Report (CSV)", systemImage: "square.and.arrow.up") { exportCSV() }
                .buttonStyle(.borderedProminent)
            Button("Export Data (JSON)", systemImage: "doc") { exportJSON() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private func exportCSV() {
        var lines: [String] = [
            "Report,\(formatDateOnly(dateFrom)) - \(formatDateOnly(dateTo))",
            "",
            "Profit & Loss Summary",
            "Revenue,\(revenue)",
            "Expenses,\(totalExpenses)",
            "Deliveries Cost,\(totalDeliveriesCost)",
            "Gross Profit,\(profit)",
            "Transactions,\(txCount)",
            "Avg Per Transaction,\(avgPerTx)",
            "",
            "Daily Breakdown",
            "Date,Sales",
        ]
        for day in storage.dailySales(from: dateFrom, to: dateTo) {
            lines.append("\(formatDateOnly(day.date)),\(day.total)")
        }
        lines.append("")
        lines.append("Payment Breakdown")
        lines.append("Method,Amount")
        for item in storage.salesByMethod(from: dateFrom, to: dateTo) {
            lines.append("\(item.method),\(item.total)")
        }
        lines.append("")
        lines.append("Fuel Type Breakdown")
        lines.append("Fuel Type,Liters,Revenue")
        for item in storage.salesByFuelType(from: dateFrom, to: dateTo) {
            lines.append("\(item.fuelType),\(item.liters),\(item.total)")
        }

        let content = lines.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Report-\(formatDateOnly(dateFrom))-\(formatDateOnly(dateTo)).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportJSON() {
        guard let content = try? storage.fullExportJSON() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Report-\(formatDateOnly(dateFrom))-\(formatDateOnly(dateTo)).json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct ClosureDateWrapper: Identifiable {
    let id = UUID()
    let date: Date
    init(_ date: Date) { self.date = date }
}

