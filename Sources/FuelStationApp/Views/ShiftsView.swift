import FuelStationCore


import SwiftUI

struct ShiftsView: View {
    @Environment(StorageManager.self) private var storage
    @State private var selectedShift: Shift?
    @State private var showingStartShift = false
    @State private var showingEndShift = false

    var body: some View {
        HSplitView {
            shiftList
                .frame(minWidth: 300, idealWidth: 400)
            if let selectedShift {
                shiftDetail(selectedShift)
                    .frame(minWidth: 300, idealWidth: 500)
                    .id(selectedShift.id)
            } else {
                Text("Select a shift")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if storage.activeShift != nil {
                    Button("End Shift", systemImage: "clock.badge.exclamationmark") {
                        showingEndShift = true
                    }
                    .foregroundStyle(.red)
                } else {
                    Button("Start Shift", systemImage: "clock.badge.checkmark") {
                        showingStartShift = true
                    }
                    .foregroundStyle(.green)
                }
            }
        }
        .sheet(isPresented: $showingStartShift) { StartShiftView() }
        .sheet(isPresented: $showingEndShift) { EndShiftView() }
    }

    private var shiftList: some View {
        List(selection: $selectedShift) {
            Section("Current") {
                if let active = storage.activeShift {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(active.employeeName)
                                .fontWeight(.bold)
                            if !active.attendants.isEmpty {
                                Text(active.attendants.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Started \(formatDate(active.startTime))")
                                .font(.caption)
                        }
                        Spacer()
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .padding(4)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    .tag(active)
                } else {
                    Text("No active shift")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            Section("Past Shifts") {
                let past = storage.shifts.filter { $0.status == .closed }.sorted { $0.startTime > $1.startTime }
                ForEach(past) { shift in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(shift.employeeName)
                                .fontWeight(.medium)
                            Text(formatDateOnly(shift.startTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let end = shift.endTime {
                            Text(duration(from: shift.startTime, to: end))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(shift)
                }
                .onDelete { indices in
                    let pastShifts = storage.shifts.filter { $0.status == .closed }.sorted { $0.startTime > $1.startTime }
                    for idx in indices {
                        storage.deleteShift(pastShifts[idx].id)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func shiftDetail(_ shift: Shift) -> some View {
        Form {
            Section("Employee & Time") {
                LabeledContent("Manager", value: shift.employeeName)
                if !shift.attendants.isEmpty {
                    LabeledContent("Attendants", value: shift.attendants.joined(separator: ", "))
                }
                LabeledContent("Started", value: formatDate(shift.startTime))
                if let end = shift.endTime {
                    LabeledContent("Ended", value: formatDate(end))
                }
            }

            Section("Cash Reconciliation") {
                LabeledContent("Opening Cash", value: formatCurrency(shift.openingCash))
                if let closing = shift.closingCash {
                    LabeledContent("Closing Cash", value: formatCurrency(closing))
                    LabeledContent("Net Cash", value: formatCurrency(closing - shift.openingCash))
                }
            }

            Section("Shift Sales") {
                let txs = storage.transactions.filter { $0.shiftID == shift.id }
                let total = txs.reduce(0) { $0 + $1.amount }
                let liters = txs.reduce(0) { $0 + $1.liters }
                
                LabeledContent("Total Revenue", value: formatCurrency(total))
                LabeledContent("Total Volume", value: "\(formatVolume(liters)) L")
                LabeledContent("Transaction Count", value: "\(txs.count)")
            }

            if !storage.transactions.filter({ $0.shiftID == shift.id }).isEmpty {
                Section("Transactions") {
                    ForEach(storage.transactions.filter({ $0.shiftID == shift.id }).sorted { $0.date > $1.date }) { tx in
                        HStack {
                            Text(formatDate(tx.date))
                                .font(.caption2)
                            Spacer()
                            Text(tx.fuelType)
                                .font(.caption2)
                            Text(formatCurrency(tx.amount))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func duration(from start: Date, to end: Date) -> String {
        let diff = end.timeIntervalSince(start)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct StartShiftView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var attendants: [String] = [""]
    @State private var cash = 1000.0

    private var currencyFmt: NumberFormatter { storage.makeCurrencyFormatter() }

    var body: some View {
        Form {
            Section("Manager Info") {
                TextField("Manager Name", text: $name)
            }
            
            Section("Attendants On Duty") {
                ForEach(0..<attendants.count, id: \.self) { i in
                    HStack {
                        TextField("Attendant \(i+1)", text: $attendants[i])
                        if attendants.count > 1 {
                            Button { attendants.remove(at: i) } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Add Attendant") { attendants.append("") }
            }
            
            Section("Initial Float") {
                HStack {
                    Text("Opening Cash")
                    TextField("Amount", value: $cash, formatter: currencyFmt)
                        .frame(width: 100)
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") {
                    let validAttendants = attendants.filter { !$0.isEmpty }
                    storage.startShift(employeeName: name, attendants: validAttendants, openingCash: cash)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}

struct EndShiftView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var cash = 0.0

    private var currencyFmt: NumberFormatter { storage.makeCurrencyFormatter() }

    var body: some View {
        Form {
            if let active = storage.activeShift {
                Text("Ending shift for \(active.employeeName)")
                    .font(.headline)
            }
            HStack {
                Text("Closing Cash")
                TextField("Amount", value: $cash, formatter: currencyFmt)
                    .frame(width: 100)
            }
        }
        .padding()
        .onAppear {
            let activeID = storage.activeShift?.id
            let cashSales = storage.transactions.filter { $0.shiftID == activeID && $0.paymentMethod == "Cash" }.reduce(0) { $0 + $1.amount }
            cash = (storage.activeShift?.openingCash ?? 0) + cashSales
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("End Shift") {
                    storage.endShift(closingCash: cash)
                    dismiss()
                }
            }
        }
        .frame(minWidth: 400, idealWidth: 400)
    }
}
