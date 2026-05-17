import FuelStationCore


import SwiftUI

struct SearchView: View {
    @Environment(StorageManager.self) private var storage
    @State private var searchText = ""
    
    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case customers = "Customers"
        case transactions = "Transactions"
        case deliveries = "Deliveries"
        case expenses = "Expenses"
    }
    
    @State private var category: SearchCategory = .all

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if searchText.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search customers, transactions, receipts...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Picker("Category", selection: $category) {
                ForEach(SearchCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .frame(width: 120)
        }
        .padding()
        .background(.background)
        .overlay(Divider(), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("Search for anything")
                .font(.headline)
            Text("Find customers by name, transactions by notes, or deliveries by supplier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List {
            if category == .all || category == .customers {
                let matches = storage.customers.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.phone.contains(searchText) ||
                    ($0.email?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
                if !matches.isEmpty {
                    Section("Customers") {
                        ForEach(matches) { customer in
                            CustomerSearchRow(customer: customer)
                        }
                    }
                }
            }
            
            if category == .all || category == .transactions {
                let matches = storage.transactions.filter {
                    ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    $0.fuelType.localizedCaseInsensitiveContains(searchText) ||
                    "\($0.pumpID)".contains(searchText)
                }
                if !matches.isEmpty {
                    Section("Transactions") {
                        ForEach(matches) { tx in
                            TransactionSearchRow(tx: tx)
                        }
                    }
                }
            }
            
            if category == .all || category == .deliveries {
                let matches = storage.deliveries.filter {
                    $0.supplier.localizedCaseInsensitiveContains(searchText) ||
                    $0.fuelType.localizedCaseInsensitiveContains(searchText) ||
                    ($0.invoiceRef?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
                if !matches.isEmpty {
                    Section("Deliveries") {
                        ForEach(matches) { delivery in
                            DeliverySearchRow(delivery: delivery)
                        }
                    }
                }
            }
            
            if category == .all || category == .expenses {
                let matches = storage.expenses.filter {
                    $0.category.localizedCaseInsensitiveContains(searchText) ||
                    ($0.note?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
                if !matches.isEmpty {
                    Section("Expenses") {
                        ForEach(matches) { expense in
                            ExpenseSearchRow(expense: expense)
                        }
                    }
                }
            }
        }
    }
}

struct CustomerSearchRow: View {
    let customer: Customer
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(customer.name).fontWeight(.medium)
                Text(customer.phone).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(customer.loyaltyPoints) pts").font(.caption).foregroundStyle(.blue)
        }
    }
}

struct TransactionSearchRow: View {
    let tx: FuelTransaction
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(tx.fuelType).fontWeight(.medium)
                Text(formatDate(tx.date)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatCurrency(tx.amount)).fontWeight(.semibold)
                Text("\(formatVolume(tx.liters)) L").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct DeliverySearchRow: View {
    let delivery: Delivery
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(delivery.supplier).fontWeight(.medium)
                Text("\(delivery.fuelType) - \(formatDateOnly(delivery.date))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatCurrency(delivery.cost)).fontWeight(.semibold)
                Text("+\(formatVolume(delivery.liters)) L").font(.caption2).foregroundStyle(.green)
            }
        }
    }
}

struct ExpenseSearchRow: View {
    let expense: Expense
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(expense.category).fontWeight(.medium)
                Text(formatDateOnly(expense.date)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCurrency(expense.amount)).fontWeight(.semibold).foregroundStyle(.red)
        }
    }
}
