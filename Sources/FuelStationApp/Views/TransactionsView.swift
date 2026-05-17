import FuelStationCore


import SwiftUI

struct TransactionsView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAdd = false
    @State private var filterDateFrom: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
    @State private var filterDateTo: Date = .now
    @State private var filterPump: Int?
    @State private var filterPayment: String?
    @State private var selectedTransactionID: FuelTransaction.ID?
    @State private var transactionSort: [KeyPathComparator<FuelTransaction>] = [
        KeyPathComparator(\.date, order: .reverse)
    ]

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filters
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
                transactionTable
            }
            .frame(minWidth: 500, idealWidth: 550)
            if let id = selectedTransactionID, let tx = storage.transactions.first(where: { $0.id == id }) {
                transactionDetail(tx)
                    .frame(minWidth: 250, idealWidth: 350)
            } else {
                Text("Select a transaction")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("New FuelTransaction", systemImage: "plus") { showingAdd = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Delete", systemImage: "trash") {
                    if let id = selectedTransactionID {
                        storage.deleteTransaction(id)
                        selectedTransactionID = nil
                    }
                }
                .disabled(selectedTransactionID == nil)
            }
        }
        .sheet(isPresented: $showingAdd) { AddTransactionView() }
    }

    private var filters: some View {
        HStack {
            DatePicker("From", selection: $filterDateFrom, displayedComponents: .date)
                .labelsHidden()
            DatePicker("To", selection: $filterDateTo, displayedComponents: .date)
                .labelsHidden()
            Picker("Pump", selection: $filterPump) {
                Text("All Pumps").tag(nil as Int?)
                ForEach(storage.pumps) { pump in
                    Text(pump.label).tag(pump.number as Int?)
                }
            }
            .frame(width: 120)
            Picker("Payment", selection: $filterPayment) {
                Text("All Methods").tag(nil as String?)
                ForEach(["Cash", "Card", "Mobile", "Fuel Card"], id: \.self) { m in
                    Text(m).tag(m as String?)
                }
            }
            .frame(width: 140)
            Spacer()
        }
    }

    private var filteredTransactions: [FuelTransaction] {
        let filtered = storage.transactions.filter { tx in
            let dateOk = tx.date >= filterDateFrom && tx.date <= filterDateTo
            let pumpOk = filterPump == nil || tx.pumpID == filterPump
            let paymentOk = filterPayment == nil || tx.paymentMethod == filterPayment
            return dateOk && pumpOk && paymentOk
        }
        return filtered.sorted(using: transactionSort)
    }

    private var transactionTable: some View {
        Table(filteredTransactions, selection: $selectedTransactionID, sortOrder: $transactionSort) {
            TableColumn("Date", value: \.date) { tx in
                Text(formatDate(tx.date))
                    .font(.caption)
            }
            .width(130)
            TableColumn("Pump", value: \.pumpID) { tx in
                Text("\(tx.pumpID)")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(54)
            TableColumn("Fuel", value: \.fuelType) { tx in
                Text(tx.fuelType)
                    .font(.caption)
            }
            .width(80)
            TableColumn("Liters", value: \.liters) { tx in
                Text(formatVolume(tx.liters))
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(72)
            TableColumn("Amount", value: \.amount) { tx in
                Text(formatCurrency(tx.amount))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(88)
            TableColumn("Payment", value: \.paymentMethod) { tx in
                Text(tx.paymentMethod)
                    .font(.caption)
            }
            .width(80)
        }
        .tableStyle(.bordered)
        .alternatingRowBackgrounds()
    }

    private func transactionDetail(_ tx: FuelTransaction) -> some View {
        Form {
            Section("FuelTransaction Details") {
                LabeledContent("Date", value: formatDate(tx.date))
                LabeledContent("Pump", value: "\(tx.pumpID)")
                LabeledContent("Fuel", value: tx.fuelType)
                LabeledContent("Liters", value: storage.formatVolume(tx.liters))
                LabeledContent("Amount", value: storage.formatCurrency(tx.amount))
                LabeledContent("Payment", value: tx.paymentMethod)
                if let notes = tx.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            }
            
            Section("Customer Info") {
                if let customerID = tx.customerID, let customer = storage.customer(for: customerID) {
                    LabeledContent("Name", value: customer.name)
                    LabeledContent("Phone", value: customer.phone)
                } else {
                    Text("Guest Customer")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button(action: {
                    PrintUtility.printReceipt(transaction: tx)
                }) {
                    Label("Print Receipt", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Section("Totals") {
                let dayTotal = filteredTransactions
                    .filter { Calendar.current.isDateInToday($0.date) }
                    .reduce(0) { $0 + $1.amount }
                let periodTotal = filteredTransactions.reduce(0) { $0 + $1.amount }
                LabeledContent("Today", value: storage.formatCurrency(dayTotal))
                LabeledContent("Filtered Period", value: storage.formatCurrency(periodTotal))
            }
        }
        .formStyle(.grouped)
    }
}

struct AddTransactionView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var pumpID = 1
    @State private var fuelType = ""
    @State private var liters = 50.0
    @State private var amount = 0.0
    @State private var paymentMethod = "Cash"
    @State private var notes = ""
    @State private var customerID: UUID? = nil
    @State private var attendantName: String? = nil
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private var isValid: Bool {
        liters > 0 && amount > 0 && !fuelType.isEmpty
    }

    private var pricePerLiter: Double {
        storage.price(for: fuelType)
    }

    var body: some View {
        Form {
            Section("Pump & Fuel") {
                Picker("Pump", selection: $pumpID) {
                    if storage.pumps.isEmpty {
                        Text("No pumps configured").tag(0)
                    } else {
                        ForEach(storage.pumps) { pump in
                            Text(pump.label).tag(pump.number)
                        }
                    }
                }
                Picker("Fuel Type", selection: $fuelType) {
                    ForEach(storage.settings.fuelTypes, id: \.self) { ft in Text(ft).tag(ft) }
                }
                
                if let activeShift = storage.activeShift, !activeShift.attendants.isEmpty {
                    Picker("Attendant", selection: $attendantName) {
                        Text("Unspecified").tag(nil as String?)
                        Divider()
                        ForEach(activeShift.attendants, id: \.self) { att in
                            Text(att).tag(att as String?)
                        }
                    }
                }
            }

            Section("Customer Loyalty") {
                Picker("Customer", selection: $customerID) {
                    Text("None / Guest").tag(nil as UUID?)
                    Divider()
                    ForEach(storage.customers) { customer in
                        Text("\(customer.name) (\(customer.phone))").tag(customer.id as UUID?)
                    }
                }
                
                if let customerID, let customer = storage.customer(for: customerID) {
                    HStack {
                        Text("Points: \(customer.loyaltyPoints)")
                        Spacer()
                        Text("Awards: +\(Int(liters / 10)) pts")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)
                }
            }

            Section("FuelTransaction Details") {
                LabeledContent("Price / L") {
                    Text(storage.formatCurrency(pricePerLiter))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Liters")
                    TextField("Liters", value: $liters, formatter: volumeFormatter)
                        .frame(width: 100)
                }
                HStack {
                    Text("Amount")
                    TextField("Amount", value: $amount, formatter: currencyFormatter)
                        .frame(width: 100)
                }
                if !fuelType.isEmpty {
                    Text("Calculated: \(storage.formatVolume(liters)) × \(storage.formatCurrency(pricePerLiter)) = \(storage.formatCurrency(liters * pricePerLiter))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Payment", selection: $paymentMethod) {
                    Text("Cash").tag("Cash")
                    Text("UPI").tag("UPI")
                    Text("Card").tag("Card")
                    Text("Credit / Ledger").tag("Credit")
                    Text("Fuel Card").tag("Fuel Card")
                }
                TextField("Notes (optional)", text: $notes)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard isValid else {
                        if liters <= 0 { validationMessage = loc("Liters must be greater than zero") }
                        else if amount <= 0 { validationMessage = loc("Amount must be greater than zero") }
                        else { validationMessage = loc("Please fill in all required fields") }
                        showValidationAlert = true
                        return
                    }
                    
                    do {
                        try storage.addTransaction(FuelTransaction(
                            pumpID: pumpID,
                            fuelType: fuelType,
                            liters: liters,
                            amount: amount,
                            paymentMethod: paymentMethod,
                            notes: notes.isEmpty ? nil : notes,
                            customerID: customerID,
                            attendantName: attendantName
                        ))
                        dismiss()
                    } catch {
                        validationMessage = error.localizedDescription
                        showValidationAlert = true
                    }
                }
            }
        }
        .alert("Invalid Input", isPresented: $showValidationAlert) {
            Button("OK") {}
        } message: {
            Text(validationMessage)
        }
        .onAppear {
            if fuelType.isEmpty {
                fuelType = storage.settings.fuelTypes.first ?? "Petrol"
                amount = storage.calculatedAmount(liters: liters, fuelType: fuelType)
            }
        }
        .onChange(of: fuelType) { _, newFuel in
            amount = storage.calculatedAmount(liters: liters, fuelType: newFuel)
        }
        .onChange(of: liters) { _, newLiters in
            guard !fuelType.isEmpty else { return }
            amount = storage.calculatedAmount(liters: newLiters, fuelType: fuelType)
        }
        .frame(minWidth: 450, idealWidth: 450)
    }
}
