import FuelStationCore


import SwiftUI

struct InventoryView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAddTank = false
    @State private var showingAddDelivery = false
    @State private var selectedTank: FuelTank?
    @State private var tankToDelete: FuelTank?

    var body: some View {
        HSplitView {
            tankList
                .frame(minWidth: 250, idealWidth: 350)
            if let selectedTank {
                tankDetail(selectedTank)
                    .frame(minWidth: 250, idealWidth: 350)
            } else {
                Text("Select a tank")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Tank", systemImage: "plus") { showingAddTank = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Log Delivery", systemImage: "shippingbox") { showingAddDelivery = true }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showingAddTank) { AddTankView() }
        .sheet(isPresented: $showingAddDelivery) { AddDeliveryView() }
    }

    private var tankList: some View {
        List(selection: $selectedTank) {
            ForEach(storage.fuelTanks) { tank in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tank.type)
                            .fontWeight(.medium)
                        Text("\(formatVolume(tank.current)) / \(formatVolume(tank.capacity)) L")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if tank.current < storage.settings.lowThreshold {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    ProgressView(value: tank.fillRatio)
                        .tankProgressTint(tank)
                        .frame(width: 60)
                        .accessibilityLabel("Tank for \(tank.type)")
                        .accessibilityValue("\(Int(tank.fillRatio * 100)) percent full")
                    Text("\(Int(tank.fillRatio * 100))%")
                        .font(.caption)
                        .frame(width: 36, alignment: .trailing)
                }
                .tag(tank)
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    tankToDelete = storage.fuelTanks[idx]
                }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        .overlay {
            if storage.fuelTanks.isEmpty {
                ContentUnavailableView("No Tanks", systemImage: "fuelpump", description: Text("Add your first fuel tank to get started."))
            }
        }
        .alert("Delete Tank?", isPresented: Binding(
            get: { tankToDelete != nil },
            set: { if !$0 { tankToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { tankToDelete = nil }
            Button("Delete", role: .destructive) {
                if let tank = tankToDelete {
                    storage.deleteTank(tank.id)
                    if selectedTank?.id == tank.id { selectedTank = nil }
                    tankToDelete = nil
                }
            }
        } message: {
            if let tank = tankToDelete {
                Text("Are you sure you want to delete the \(tank.type) tank? This may affect transaction history.")
            }
        }
    }

    private func tankDetail(_ tank: FuelTank) -> some View {
        Form {
            Section("Tank Info") {
                LabeledContent("Type", value: tank.type)
                LabeledContent("Capacity", value: "\(formatVolume(tank.capacity)) L")
                LabeledContent("Current", value: "\(formatVolume(tank.current)) L")
                LabeledContent("Fill", value: "\(Int(tank.fillRatio * 100))%")
                LabeledContent("Last Updated", value: formatDate(tank.lastUpdated))
            }
            Section("Threshold") {
                let threshold = storage.settings.lowThreshold
                if tank.current < threshold {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Below low threshold (\(formatVolume(threshold)) L)")
                            .foregroundStyle(.orange)
                    }
                    
                    let reorderAmount = tank.capacity - tank.current
                    Button("Generate Purchase Order") {
                        generatePO(for: tank, reorderAmount: reorderAmount)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Text("Above threshold (\(formatVolume(threshold)) L)")
                        .foregroundStyle(.green)
                }
            }
            Section("Delivery History") {
                let tankDeliveries = storage.deliveries
                    .filter { $0.fuelType == tank.type }
                    .sorted { $0.date > $1.date }
                if tankDeliveries.isEmpty {
                    Text("No deliveries recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tankDeliveries.prefix(20)) { d in
                        HStack {
                            Text(formatDateOnly(d.date))
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                            Text(d.supplier)
                                .font(.caption)
                            Spacer()
                            Text("+\(formatVolume(d.liters)) L")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func generatePO(for tank: FuelTank, reorderAmount: Double) {
        let dateStr = formatDateOnly(Date())
        let poText = """
        PURCHASE ORDER
        ==============
        Date: \(dateStr)
        Station: \(storage.settings.stationName)
        GSTIN: \(storage.settings.gstin)
        
        To: Primary Supplier
        
        Please deliver the following:
        Product: \(tank.type)
        Quantity: \(formatVolume(reorderAmount))
        
        Delivery required ASAP.
        Thank you.
        """
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "PO_\(tank.type)_\(dateStr).txt"
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? poText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct AddTankView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var type = ""
    @State private var capacity = 10000.0

    var body: some View {
        Form {
            Picker("Fuel Type", selection: $type) {
                ForEach(storage.settings.fuelTypes, id: \.self) { ft in
                    Text(ft).tag(ft)
                }
            }
            HStack {
                Text("Capacity (L)")
                Slider(value: $capacity, in: 1000...50000, step: 100)
                Text("\(Int(capacity))")
                    .frame(width: 60)
            }
        }
        .padding()
        .onAppear {
            if type.isEmpty {
                type = storage.settings.fuelTypes.first ?? ""
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard !type.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    storage.addTank(FuelTank(type: type, capacity: capacity))
                    dismiss()
                }
                .disabled(type.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}

struct AddDeliveryView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var supplier = ""
    @State private var fuelType = ""
    @State private var liters = 1000.0
    @State private var cost = 0.0
    @State private var invoiceRef = ""
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showExcessAlert = false
    @State private var excessAmount: Double = 0

    private var currencyFmt: NumberFormatter { storage.makeCurrencyFormatter() }

    private var isValid: Bool {
        !supplier.trimmingCharacters(in: .whitespaces).isEmpty &&
        liters > 0 &&
        cost >= 0 &&
        !fuelType.isEmpty
    }

    var body: some View {
        Form {
            TextField("Supplier", text: $supplier)
            Picker("Fuel Type", selection: $fuelType) {
                ForEach(storage.settings.fuelTypes, id: \.self) { ft in
                    Text(ft).tag(ft)
                }
            }
            .onAppear {
                if fuelType.isEmpty {
                    fuelType = storage.settings.fuelTypes.first ?? "Petrol"
                }
            }
            HStack {
                Text("Liters")
                TextField("Liters", value: $liters, formatter: volumeFormatter)
                    .frame(width: 100)
            }
            HStack {
                Text("Cost")
                TextField("Cost", value: $cost, formatter: currencyFmt)
                    .frame(width: 100)
            }
            TextField("Invoice Ref (optional)", text: $invoiceRef)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard isValid else {
                        if supplier.trimmingCharacters(in: .whitespaces).isEmpty { validationMessage = loc("Supplier is required") }
                        else if liters <= 0 { validationMessage = loc("Liters must be greater than zero") }
                        else if cost < 0 { validationMessage = loc("Cost cannot be negative") }
                        else { validationMessage = loc("Please fill in all required fields") }
                        showValidationAlert = true
                        return
                    }
                    let excess = storage.addDelivery(Delivery(supplier: supplier, fuelType: fuelType, liters: liters, cost: cost, invoiceRef: invoiceRef.isEmpty ? nil : invoiceRef))
                    if excess > 0 {
                        excessAmount = excess
                        showExcessAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .alert("Invalid Input", isPresented: $showValidationAlert) {
            Button("OK") {}
        } message: {
            Text(validationMessage)
        }
        .alert("Delivery Exceeds Capacity", isPresented: $showExcessAlert) {
            Button("OK") {}
        } message: {
            Text("This delivery exceeds the tank capacity by \(storage.formatVolume(excessAmount)). The excess fuel was not added to the tank.")
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}

extension View {
    func tankProgressTint(_ tank: FuelTank) -> some View {
        let color: Color = tank.fillRatio < 0.2 ? .red : tank.fillRatio < 0.5 ? .orange : .green
        return self.tint(color)
    }
}
