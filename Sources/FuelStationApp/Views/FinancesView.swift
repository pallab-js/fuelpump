import FuelStationCore


import SwiftUI
import UniformTypeIdentifiers

struct FinancesView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAddExpense = false
    @State private var showingExportOptions = false
    @State private var selectedExpenseID: Expense.ID?
    @State private var expenseSort: [KeyPathComparator<Expense>] = [
        KeyPathComparator(\.date, order: .reverse)
    ]
    @State private var deliverySort: [KeyPathComparator<Delivery>] = [
        KeyPathComparator(\.date, order: .reverse)
    ]

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                profitLossSection
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                Divider()
                expensesSection
                Divider()
                deliveriesSection
            }
            .frame(minWidth: 500, idealWidth: 550)
            if let id = selectedExpenseID, let expense = storage.expenses.first(where: { $0.id == id }) {
                expenseDetail(expense)
                    .frame(minWidth: 250, idealWidth: 350)
            } else {
                Text("Select an expense for details")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Expense", systemImage: "plus") { showingAddExpense = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Delete", systemImage: "trash") {
                    if let id = selectedExpenseID {
                        storage.deleteExpense(id)
                        selectedExpenseID = nil
                    }
                }
                .disabled(selectedExpenseID == nil)
                Button("Export", systemImage: "square.and.arrow.up") { showingExportOptions = true }
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
        .confirmationDialog("Export Data", isPresented: $showingExportOptions) {
            Button("Export Transactions (CSV)") { exportCSV(type: "transactions") }
            Button("Export Expenses (CSV)") { exportCSV(type: "expenses") }
            Button("Export Deliveries (CSV)") { exportCSV(type: "deliveries") }
            Button("Export All (JSON)") { exportJSON() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var profitLossSection: some View {
        VStack(spacing: 8) {
            Text("Profit & Loss Summary")
                .font(.headline)
            HStack(spacing: 16) {
                plCard(title: "Revenue", value: formatCurrency(storage.totalRevenue), color: .green)
                plCard(title: "Expenses", value: formatCurrency(storage.totalExpenses), color: .red)
                plCard(title: "Deliveries Cost", value: formatCurrency(storage.totalDeliveriesCost), color: .orange)
                plCard(title: "Gross Profit", value: formatCurrency(storage.grossProfit), color: storage.grossProfit >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private func plCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.background))
    }

    private var sortedExpenses: [Expense] {
        storage.expenses.sorted(using: expenseSort)
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Expenses")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            Table(sortedExpenses, selection: $selectedExpenseID, sortOrder: $expenseSort) {
                TableColumn("Date", value: \.date) { expense in
                    Text(formatDateOnly(expense.date))
                        .font(.caption)
                }
                .width(90)
                TableColumn("Category", value: \.category) { expense in
                    Text(expense.category)
                        .font(.caption)
                }
                .width(100)
                TableColumn("Amount", value: \.amount) { expense in
                    Text(formatCurrency(expense.amount))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(90)
                TableColumn("Note") { expense in
                    if let note = expense.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .tableStyle(.bordered)
            .alternatingRowBackgrounds()
            .frame(minHeight: 100)
        }
    }

    private var displayedDeliveries: [Delivery] {
        Array(storage.deliveries.sorted(using: deliverySort).prefix(50))
    }

    private var deliveriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Deliveries")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            if displayedDeliveries.isEmpty {
                Text("No deliveries recorded")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            } else {
                Table(displayedDeliveries, sortOrder: $deliverySort) {
                    TableColumn("Date", value: \.date) { Text(formatDateOnly($0.date)).font(.caption) }
                        .width(90)
                    TableColumn("Supplier", value: \.supplier) { Text($0.supplier).font(.caption) }
                        .width(100)
                    TableColumn("Fuel", value: \.fuelType) { Text($0.fuelType).font(.caption) }
                        .width(80)
                    TableColumn("Liters", value: \.liters) { Text(formatVolume($0.liters)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing) }
                        .width(72)
                    TableColumn("Cost", value: \.cost) { Text(formatCurrency($0.cost)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing) }
                        .width(88)
                }
                .tableStyle(.bordered)
                .frame(minHeight: 100)
            }
        }
    }

    private func expenseDetail(_ expense: Expense) -> some View {
        Form {
            Section("Expense Details") {
                LabeledContent("Date", value: formatDate(expense.date))
                LabeledContent("Category", value: expense.category)
                LabeledContent("Amount", value: formatCurrency(expense.amount))
                if let note = expense.note, !note.isEmpty {
                    LabeledContent("Note", value: note)
                }
                if let receipt = expense.receiptPath, !receipt.isEmpty {
                    LabeledContent("Receipt", value: receipt)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportCSV(type: String) {
        let content: String
        switch type {
        case "transactions":
            content = generateCSVRows(storage.transactions)
        case "expenses":
            content = generateCSVRows(storage.expenses)
        case "deliveries":
            content = generateCSVRows(storage.deliveries)
        default:
            return
        }
        saveToFile(content: content, filename: "\(type).csv")
    }

    private func exportJSON() {
        guard let content = try? storage.fullExportJSON() else { return }
        saveToFile(content: content, filename: "export.json")
    }

    private func saveToFile(content: String, filename: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = filename.hasSuffix(".csv") ? [.commaSeparatedText] : [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to export \(filename): \(error.localizedDescription)")
            }
        }
    }
}

struct AddExpenseView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var category = "Utilities"
    @State private var amount = 0.0
    @State private var note = ""
    @State private var showValidationAlert = false

    var body: some View {
        Form {
            Picker("Category", selection: $category) {
                Text("Utilities").tag("Utilities")
                Text("Rent").tag("Rent")
                Text("Salary").tag("Salary")
                Text("Maintenance").tag("Maintenance")
                Text("Supplies").tag("Supplies")
                Text("Other").tag("Other")
            }
            HStack {
                Text("Amount")
                TextField("Amount", value: $amount, formatter: currencyFormatter)
                    .frame(width: 100)
            }
            TextField("Note (optional)", text: $note)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard amount > 0 else {
                        showValidationAlert = true
                        return
                    }
                    storage.addExpense(Expense(category: category, amount: amount, note: note.isEmpty ? nil : note))
                    dismiss()
                }
            }
        }
        .alert("Invalid Input", isPresented: $showValidationAlert) {
            Button("OK") {}
        } message: {
            Text("Amount must be greater than zero", bundle: fuelStationBundle)
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}
