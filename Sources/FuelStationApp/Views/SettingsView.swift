import FuelStationCore


import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingWipeConfirmation = false
    @State private var showingRestorePicker = false
    @State private var showingAddFuelTypeAlert = false
    @State private var newFuelTypeName = ""
    @State private var newFuelTypePrice = 1.50
    @State private var statusMessage = ""
    private let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private func setStatus(_ msg: String) {
        statusMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.statusMessage == msg {
                self.statusMessage = ""
            }
        }
    }

    var body: some View {
        Form {
            Section("Station Details") {
                TextField("Station Name", text: Binding(
                    get: { storage.settings.stationName },
                    set: { var s = storage.settings; s.stationName = $0; storage.updateSettings(s) }
                ))
                TextField("Address", text: Binding(
                    get: { storage.settings.address },
                    set: { var s = storage.settings; s.address = $0; storage.updateSettings(s) }
                ))
                TextField("Phone", text: Binding(
                    get: { storage.settings.phone },
                    set: { var s = storage.settings; s.phone = $0; storage.updateSettings(s) }
                ))
            }

            Section("Financial Settings") {
                HStack {
                    Text("Tax Rate")
                    Slider(value: Binding(
                        get: { storage.settings.taxRate },
                        set: { var s = storage.settings; s.taxRate = $0; storage.updateSettings(s) }
                    ), in: 0...0.5, step: 0.01)
                    Text("\(Int(storage.settings.taxRate * 100))%")
                        .frame(width: 40)
                }
                Picker("Currency", selection: Binding(
                    get: { storage.settings.currency },
                    set: { var s = storage.settings; s.currency = $0; storage.updateSettings(s) }
                )) {
                    Text("INR (₹)").tag("INR")
                    Text("USD ($)").tag("USD")
                    Text("EUR (€)").tag("EUR")
                    Text("GBP (£)").tag("GBP")
                }
                
                TextField("GSTIN", text: Binding(
                    get: { storage.settings.gstin },
                    set: { var s = storage.settings; s.gstin = $0; storage.updateSettings(s) }
                ))
                
                TextField("UPI ID (VPA)", text: Binding(
                    get: { storage.settings.upiID },
                    set: { var s = storage.settings; s.upiID = $0; storage.updateSettings(s) }
                ))
            }

            Section("Inventory Threshold") {
                HStack {
                    Text("Low Stock Alert (L)")
                    Slider(value: Binding(
                        get: { storage.settings.lowThreshold },
                        set: { var s = storage.settings; s.lowThreshold = $0; storage.updateSettings(s) }
                    ), in: 100...5000, step: 100)
                    Text("\(Int(storage.settings.lowThreshold))")
                        .frame(width: 60)
                }
            }

            Section("Dashboard Layout") {
                List {
                    ForEach(storage.settings.dashboardSections.sorted(by: { $0.order < $1.order })) { section in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            Toggle(section.title, isOn: Binding(
                                get: { section.isVisible },
                                set: { newValue in
                                    var s = storage.settings
                                    if let idx = s.dashboardSections.firstIndex(where: { $0.id == section.id }) {
                                        s.dashboardSections[idx].isVisible = newValue
                                        storage.updateSettings(s)
                                    }
                                }
                            ))
                        }
                    }
                    .onMove { indices, newOffset in
                        var s = storage.settings
                        var ordered = s.dashboardSections.sorted(by: { $0.order < $1.order })
                        ordered.move(fromOffsets: indices, toOffset: newOffset)
                        for i in 0..<ordered.count {
                            ordered[i].order = i
                        }
                        s.dashboardSections = ordered
                        storage.updateSettings(s)
                    }
                }
                .frame(minHeight: 150)
            }

            Section("Fuel Types & Pricing") {
                ForEach(storage.settings.fuelTypes, id: \.self) { ft in
                    HStack {
                        Text(ft)
                            .frame(width: 100, alignment: .leading)
                        TextField("Price", value: Binding(
                            get: { storage.settings.fuelPrices[ft] ?? 1.50 },
                            set: { newPrice in
                                var s = storage.settings
                                s.fuelPrices[ft] = max(0, newPrice)
                                storage.updateSettings(s)
                            }
                        ), formatter: priceFormatter)
                        .frame(width: 70)
                        Text("/ L")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .onDelete { indexSet in
                    var s = storage.settings
                    for idx in indexSet {
                        let removed = s.fuelTypes[idx]
                        s.fuelPrices.removeValue(forKey: removed)
                    }
                    s.fuelTypes.remove(atOffsets: indexSet)
                    storage.updateSettings(s)
                }
                Button("Add Fuel Type") {
                    newFuelTypeName = ""
                    newFuelTypePrice = 1.50
                    showingAddFuelTypeAlert = true
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Privacy & Security Notice", systemImage: "lock.shield")
                        .font(.headline)
                    Text("FuelPump stores data locally in plain JSON format. Ensure your machine is secure and uses FileVault encryption for maximum protection of customer PII.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Backup & Restore") {
                Toggle("Auto Backup", isOn: Binding(
                    get: { storage.settings.backupEnabled },
                    set: { var s = storage.settings; s.backupEnabled = $0; storage.updateSettings(s) }
                ))
                Button("Create Backup Now") {
                    do {
                        try storage.createBackup()
                        setStatus("Backup created")
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
                Button("Restore from Backup") {
                    showingRestorePicker = true
                }
            }

            Section("Data Management") {
                Button("Export All Data (JSON)", action: exportAllJSON)
                Button("Wipe All Data", role: .destructive) {
                    showingWipeConfirmation = true
                }
            }

            Section("About") {
                LabeledContent("App Version", value: currentAppVersion())
                LabeledContent("Data Size", value: dataSizeDescription())
            }

            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Wipe All Data?", isPresented: $showingWipeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) {
                do {
                    try storage.wipeAllData()
                    setStatus(loc("All data wiped"))
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        } message: {
            Text("This will permanently delete all fuel tanks, transactions, deliveries, and expenses. This action cannot be undone.", bundle: fuelStationBundle)
        }
        .alert("Add Fuel Type", isPresented: $showingAddFuelTypeAlert) {
            TextField("Fuel Type Name", text: $newFuelTypeName)
            TextField("Price per Liter", value: $newFuelTypePrice, formatter: priceFormatter)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let trimmed = newFuelTypeName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                var s = storage.settings
                s.fuelTypes.append(trimmed)
                s.fuelPrices[trimmed] = max(0, newFuelTypePrice)
                storage.updateSettings(s)
                setStatus("Added fuel type: \(trimmed)")
            }
        }
        .fileImporter(isPresented: $showingRestorePicker, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    try storage.restore(from: url)
                    setStatus(loc("Backup restored successfully"))
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            case .failure:
                setStatus(loc("Restore cancelled"))
            }
        }
    }

    private func exportAllJSON() {
        do {
            let content = try storage.fullExportJSON()
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "FuelStationExport.json"
            panel.allowedContentTypes = [.json]
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    self.setStatus("Exported to \(url.lastPathComponent)")
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func dataSizeDescription() -> String {
        let dir = appDataDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return "Unknown" }
        let totalSize = contents.reduce(Int64(0)) { sum, url in
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey])
            return sum + Int64(attrs?.fileSize ?? 0)
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}
