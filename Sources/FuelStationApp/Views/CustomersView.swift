import FuelStationCore


import SwiftUI

struct CustomersView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAddCustomer = false
    @State private var selectedCustomer: Customer?
    @State private var searchText = ""
    @State private var confirmAwardPoints = false
    @State private var confirmRedeemPoints = false
    @State private var confirmSettleDues = false

    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return storage.customers
        } else {
            return storage.customers.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.phone.contains(searchText)
            }
        }
    }

    var body: some View {
        HSplitView {
            customerList
                .frame(minWidth: 300, idealWidth: 400)
            if let selectedCustomer {
                customerDetail(selectedCustomer)
                    .frame(minWidth: 300, idealWidth: 500)
                    .id(selectedCustomer.id)
            } else {
                Text("Select a customer")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Customer", systemImage: "person.badge.plus") { showingAddCustomer = true }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showingAddCustomer) { AddCustomerView() }
        .searchable(text: $searchText, prompt: "Search by name or phone")
    }

    private var customerList: some View {
        List(selection: $selectedCustomer) {
            ForEach(filteredCustomers) { customer in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name)
                            .fontWeight(.medium)
                        Text(customer.phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(customer.loyaltyPoints) pts")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        if customer.creditBalance > 0 {
                            Text("Due: \(formatCurrency(customer.creditBalance))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                        Text(formatCurrency(customer.totalSpent))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(customer)
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    storage.deleteCustomer(filteredCustomers[idx].id)
                }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        .overlay {
            if filteredCustomers.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Customers" : "No Results",
                    systemImage: "person.slash",
                    description: Text(searchText.isEmpty ? "Add your first customer to get started." : "No customers match your search.")
                )
            }
        }
    }

    private func customerDetail(_ customer: Customer) -> some View {
        Form {
            Section("Customer Info") {
                TextField("Name", text: Binding(
                    get: { customer.name },
                    set: { var c = customer; c.name = $0; storage.updateCustomer(c) }
                ))
                TextField("Phone", text: Binding(
                    get: { customer.phone },
                    set: { var c = customer; c.phone = $0; storage.updateCustomer(c) }
                ))
                TextField("Email", text: Binding(
                    get: { customer.email ?? "" },
                    set: { var c = customer; c.email = $0.isEmpty ? nil : $0; storage.updateCustomer(c) }
                ))
                LabeledContent("Registered", value: formatDateOnly(customer.registrationDate))
            }

            Section("Loyalty Program") {
                LabeledContent("Loyalty Points", value: "\(customer.loyaltyPoints)")
                LabeledContent("Total Spent", value: formatCurrency(customer.totalSpent))
                
                Button("Award 50 Bonus Points") {
                    confirmAwardPoints = true
                }
                .confirmationDialog("Award 50 bonus points to \(customer.name)?", isPresented: $confirmAwardPoints) {
                    Button("Confirm") {
                        var c = customer
                        c.loyaltyPoints += 50
                        storage.updateCustomer(c)
                    }
                    Button("Cancel", role: .cancel) {}
                }
                
                Button("Redeem 100 Points for ₹300 Discount") {
                    confirmRedeemPoints = true
                }
                .disabled(customer.loyaltyPoints < 100)
                .confirmationDialog("Redeem 100 points from \(customer.name)?", isPresented: $confirmRedeemPoints) {
                    Button("Confirm") {
                        var c = customer
                        c.loyaltyPoints -= 100
                        storage.updateCustomer(c)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            Section("Credit Account (Khata)") {
                LabeledContent("Outstanding Balance", value: formatCurrency(customer.creditBalance))
                    .foregroundStyle(customer.creditBalance > 0 ? .red : .primary)
                
                if customer.creditBalance > 0 {
                    Button("Record Payment (Settle Dues)") {
                        confirmSettleDues = true
                    }
                    .confirmationDialog("Settle all dues for \(customer.name)?", isPresented: $confirmSettleDues) {
                        Button("Confirm") {
                            var c = customer
                            c.creditBalance = 0
                            storage.updateCustomer(c)
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }

            Section("Recent Transactions") {
                let recentTx = storage.transactions
                    .filter { $0.customerID == customer.id }
                    .sorted { $0.date > $1.date }
                    .prefix(10)
                
                if recentTx.isEmpty {
                    Text("No transactions for this customer")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentTx) { tx in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formatDate(tx.date))
                                    .font(.caption)
                                Text(tx.fuelType)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(formatCurrency(tx.amount))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("\(formatVolume(tx.liters)) L")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AddCustomerView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Phone", text: $phone)
            TextField("Email (Optional)", text: $email)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    storage.addCustomer(Customer(name: name, phone: phone, email: email.isEmpty ? nil : email))
                    dismiss()
                }
                .disabled(name.isEmpty || phone.isEmpty)
            }
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}
