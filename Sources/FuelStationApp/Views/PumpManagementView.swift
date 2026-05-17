import FuelStationCore


import SwiftUI

struct PumpManagementView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAddPump = false
    @State private var selectedPump: Pump?

    var body: some View {
        HSplitView {
            pumpList
                .frame(minWidth: 250, idealWidth: 350)
            if let selectedPump {
                pumpDetail(selectedPump)
                    .frame(minWidth: 250, idealWidth: 400)
                    .id(selectedPump.id)
            } else {
                Text("Select a pump")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Pump", systemImage: "plus.circle") { showingAddPump = true }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showingAddPump) { AddPumpView() }
    }

    private var pumpList: some View {
        List(selection: $selectedPump) {
            ForEach(storage.pumps) { pump in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pump.label)
                            .fontWeight(.medium)
                        Text(pump.fuelType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        statusBadge(pump.status)
                        Text("\(formatVolume(pump.meterReading)) L")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(pump)
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    storage.deletePump(storage.pumps[idx].id)
                }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
    }

    private func pumpDetail(_ pump: Pump) -> some View {
        Form {
            Section("Pump Configuration") {
                LabeledContent("Pump Number", value: "\(pump.number)")
                TextField("Label", text: Binding(
                    get: { pump.label },
                    set: { var p = pump; p.label = $0; storage.updatePump(p) }
                ))
                Picker("Fuel Type", selection: Binding(
                    get: { pump.fuelType },
                    set: { var p = pump; p.fuelType = $0; storage.updatePump(p) }
                )) {
                    ForEach(storage.settings.fuelTypes, id: \.self) { ft in
                        Text(ft).tag(ft)
                    }
                }
            }

            Section("Status & Maintenance") {
                Picker("Status", selection: Binding(
                    get: { pump.status },
                    set: { var p = pump; p.status = $0; storage.updatePump(p) }
                )) {
                    ForEach(PumpStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker("Last Maintenance", selection: Binding(
                    get: { pump.lastMaintenance ?? .now },
                    set: { var p = pump; p.lastMaintenance = $0; storage.updatePump(p) }
                ), displayedComponents: .date)
            }

            Section("Meter Reading") {
                HStack {
                    Text("Total Volume Delivered")
                    Spacer()
                    Text("\(formatVolume(pump.meterReading)) L")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }
                
                Button("Reset Meter", role: .destructive) {
                    var p = pump
                    p.meterReading = 0
                    storage.updatePump(p)
                }
            }

            Section("Recent Activity") {
                let recentTx = storage.transactions
                    .filter { $0.pumpID == pump.number }
                    .sorted { $0.date > $1.date }
                    .prefix(10)
                
                if recentTx.isEmpty {
                    Text("No recent transactions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentTx) { tx in
                        HStack {
                            Text(formatDate(tx.date))
                                .font(.caption)
                            Spacer()
                            Text("\(formatVolume(tx.liters)) L")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func statusBadge(_ status: PumpStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.2))
            .foregroundStyle(statusColor(status))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusColor(_ status: PumpStatus) -> Color {
        switch status {
        case .active: return .green
        case .offline: return .red
        case .maintenance: return .orange
        }
    }
}

struct AddPumpView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var number = 1
    @State private var label = ""
    @State private var fuelType = ""

    var body: some View {
        Form {
            Stepper("Pump Number: \(number)", value: $number, in: 1...99)
            TextField("Label (Optional)", text: $label, prompt: Text("e.g. South Wing Pump 1"))
            Picker("Fuel Type", selection: $fuelType) {
                ForEach(storage.settings.fuelTypes, id: \.self) { ft in
                    Text(ft).tag(ft)
                }
            }
        }
        .padding()
        .onAppear {
            if fuelType.isEmpty {
                fuelType = storage.settings.fuelTypes.first ?? "Petrol"
            }
            if number == 1 && !storage.pumps.isEmpty {
                number = (storage.pumps.map { $0.number }.max() ?? 0) + 1
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    storage.addPump(Pump(number: number, label: label, fuelType: fuelType))
                    dismiss()
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}
