import FuelStationCore


import SwiftUI

struct DashboardView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAddTx = false
    @State private var showingAddDelivery = false
    @State private var showingAddExpense = false
    @State private var showingClosure = false
    @State private var chartRange: ChartRange = .week

    enum ChartRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                let sections = storage.settings.dashboardSections
                    .filter { $0.isVisible }
                    .sorted(by: { $0.order < $1.order })
                
                ForEach(sections) { section in
                    switch section.id {
                    case "kpi": kpiSection
                    case "charts": chartsSection
                    case "lowStock": lowStockSection
                    case "recentTx": recentTransactionsSection
                    case "attendantPerf": attendantPerformanceSection
                    default: EmptyView()
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup {
                Button("FuelTransaction", systemImage: "plus.circle") { showingAddTx = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Delivery", systemImage: "shippingbox") { showingAddDelivery = true }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Expense", systemImage: "dollarsign.square") { showingAddExpense = true }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Spacer()
                Button("Closure", systemImage: "doc.text") { showingClosure = true }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showingAddTx) { AddTransactionView() }
        .sheet(isPresented: $showingAddDelivery) { AddDeliveryView() }
        .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
        .sheet(isPresented: $showingClosure) {
            NavigationStack {
                DailyClosureView()
            }
        }
    }

    private var kpiSection: some View {
        HStack(spacing: 16) {
            kpiCard(title: "Today's Sales", value: formatCurrency(storage.todaySalesTotal), icon: "dollarsign.circle")
            kpiCard(title: "Transactions", value: "\(storage.todayTransactionsCount)", icon: "list.bullet.clipboard")
            kpiCard(title: "Tanks", value: "\(storage.fuelTanks.count)", icon: "fuelpump")
            kpiCard(title: "Low Alerts", value: "\(storage.lowTanks.count)", icon: "exclamationmark.triangle")
        }
    }

    private func kpiCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private var chartsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Analytics")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $chartRange) {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                SalesTrendChart(data: chartData)
                PaymentBreakdownChart(data: storage.todaySalesByMethod)
            }

            FuelTypeBarChart(data: storage.todaySalesByFuelType)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                TankLevelChart(tanks: storage.fuelTanks)
                WeeklyComparisonChart(data: storage.weeklyComparison)
            }
        }
    }

    private var chartData: [DailySales] {
        switch chartRange {
        case .week: storage.dailySalesLast7Days
        case .month: storage.dailySalesLast30Days
        }
    }

    @ViewBuilder
    private var lowStockSection: some View {
        if !storage.lowTanks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Low Stock Alerts")
                    .font(.headline)
                    .foregroundStyle(.red)
                ForEach(storage.lowTanks) { tank in
                    Label("\(tank.type): \(formatVolume(tank.current)) L remaining", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Transactions")
                .font(.headline)
            let recent = Array(storage.transactions.sorted(by: { $0.date > $1.date }).prefix(10))
            if recent.isEmpty {
                Text("No transactions yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { tx in
                    HStack {
                        Text(formatDate(tx.date))
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)
                        Text(tx.fuelType)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        Text(formatVolume(tx.liters))
                            .font(.caption)
                            .frame(width: 60, alignment: .trailing)
                        Spacer()
                        Text(formatCurrency(tx.amount))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    if tx.id != recent.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private var attendantPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attendant Performance (Today)")
                .font(.headline)
            let perf = storage.attendantPerformance(from: Calendar.current.startOfDay(for: .now), to: .now)
            if perf.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Attendant").font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                    Text("Fuel Vol").font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                    Text("Fuel Rev").font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                    Text("Lubes").font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                    Spacer()
                    Text("Total").font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                }
                Divider()
                ForEach(perf) { p in
                    HStack {
                        Text(p.name).font(.caption).frame(width: 100, alignment: .leading)
                        Text(formatVolume(p.fuelVolume)).font(.caption).frame(width: 80, alignment: .trailing)
                        Text(formatCurrency(p.fuelRevenue)).font(.caption).frame(width: 80, alignment: .trailing)
                        Text("\(p.lubeQuantity)").font(.caption).frame(width: 60, alignment: .trailing)
                        Spacer()
                        Text(formatCurrency(p.fuelRevenue + p.lubeRevenue)).font(.caption).fontWeight(.semibold).frame(width: 80, alignment: .trailing)
                    }
                    if p.id != perf.last?.id { Divider() }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}
