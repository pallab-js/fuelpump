import FuelStationCore


import SwiftUI

struct OnboardingView: View {
    @Environment(StorageManager.self) private var storage
    @State private var currentStep = 0
    
    @State private var newFuelType = ""
    @State private var showingAddFuelType = false
    @State private var showingAddTank = false
    @State private var tankType = ""
    @State private var tankCapacity = 10000.0
    @State private var tankCurrent = 5000.0

    var body: some View {
        VStack {
            HStack {
                ForEach(0..<5) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top)

            Spacer()
            
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: stationInfoStep
                case 2: fuelTypesStep
                case 3: tanksStep
                case 4: pumpsStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
            Spacer()
            
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(currentStep == 4 ? "Get Started" : "Continue") {
                    if currentStep == 4 {
                        finishOnboarding()
                    } else {
                        withAnimation { currentStep += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 2 && storage.settings.fuelTypes.isEmpty)
                .disabled(currentStep == 3 && storage.fuelTanks.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .background(.background)
        .alert("Add Fuel Type", isPresented: $showingAddFuelType) {
            TextField("Name (e.g. MS Petrol)", text: $newFuelType)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let trimmed = newFuelType.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    var s = storage.settings
                    s.fuelTypes.append(trimmed)
                    storage.updateSettings(s)
                }
                newFuelType = ""
            }
        }
        .sheet(isPresented: $showingAddTank) {
            Form {
                Section("New Tank") {
                    Picker("Fuel Type", selection: $tankType) {
                        ForEach(storage.settings.fuelTypes, id: \.self) { ft in Text(ft).tag(ft) }
                    }
                    TextField("Capacity (L)", value: $tankCapacity, formatter: volumeFormatter)
                    TextField("Current Level (L)", value: $tankCurrent, formatter: volumeFormatter)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        storage.addTank(FuelTank(type: tankType, capacity: tankCapacity, current: tankCurrent))
                        showingAddTank = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddTank = false }
                }
            }
            .frame(width: 300, height: 250)
            .onAppear {
                tankType = storage.settings.fuelTypes.first ?? ""
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Welcome to FuelPump")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Let's get your station set up in just a few steps.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var stationInfoStep: some View {
        VStack(spacing: 24) {
            Text("Station Info")
                .font(.title)
                .fontWeight(.bold)
            
            Form {
                Picker("Currency", selection: Binding(
                    get: { storage.settings.currency },
                    set: { var s = storage.settings; s.currency = $0; storage.updateSettings(s) }
                )) {
                    Text("INR (₹)").tag("INR")
                    Text("USD ($)").tag("USD")
                    Text("EUR (€)").tag("EUR")
                    Text("GBP (£)").tag("GBP")
                }
                
                HStack {
                    Text("Tax Rate")
                    Slider(value: Binding(
                        get: { storage.settings.taxRate },
                        set: { var s = storage.settings; s.taxRate = $0; storage.updateSettings(s) }
                    ), in: 0...0.5, step: 0.01)
                    Text("\(Int(storage.settings.taxRate * 100))%")
                        .frame(width: 40)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var fuelTypesStep: some View {
        VStack(spacing: 24) {
            Text("Fuel Types")
                .font(.title)
                .fontWeight(.bold)
            
            Text("What fuels do you sell?")
                .foregroundStyle(.secondary)
            
            List {
                ForEach(storage.settings.fuelTypes, id: \.self) { ft in
                    Text(ft)
                }
                .onDelete { indices in
                    var s = storage.settings
                    s.fuelTypes.remove(atOffsets: indices)
                    storage.updateSettings(s)
                }
            }
            .frame(height: 200)
            
            Button("Add Fuel Type", systemImage: "plus") {
                showingAddFuelType = true
            }
            .buttonStyle(.bordered)
            
            if storage.settings.fuelTypes.isEmpty {
                Text("Add at least one fuel type to continue")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private var tanksStep: some View {
        VStack(spacing: 24) {
            Text("Tanks Setup")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Add your fuel storage tanks.")
                .foregroundStyle(.secondary)
            
            List {
                if storage.fuelTanks.isEmpty {
                    Text("No tanks added yet").foregroundStyle(.secondary)
                } else {
                    ForEach(storage.fuelTanks) { tank in
                        HStack {
                            Text(tank.type)
                            Spacer()
                            Text("\(storage.formatVolume(tank.capacity)) capacity")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indices in
                        for idx in indices {
                            storage.deleteTank(storage.fuelTanks[idx].id)
                        }
                    }
                }
            }
            .frame(height: 200)
            
            Button("Add Tank", systemImage: "plus") {
                showingAddTank = true
            }
            .buttonStyle(.bordered)
            .disabled(storage.settings.fuelTypes.isEmpty)
            
            if storage.fuelTanks.isEmpty {
                Text("Add at least one tank to continue")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private var pumpsStep: some View {
        VStack(spacing: 24) {
            Text("Pumps Setup")
                .font(.title)
                .fontWeight(.bold)
            
            Text("How many pumps do you have?")
                .foregroundStyle(.secondary)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(storage.pumps.count)")
                        .font(.system(size: 60, weight: .bold))
                    Text("Pumps")
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        let num = (storage.pumps.map { $0.number }.max() ?? 0) + 1
                        storage.addPump(Pump(number: num, fuelType: storage.settings.fuelTypes.first ?? "Petrol"))
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if let last = storage.pumps.last {
                            storage.deletePump(last.id)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(storage.pumps.isEmpty)
                }
            }
        }
        .padding()
    }

    private func finishOnboarding() {
        var s = storage.settings
        s.hasCompletedOnboarding = true
        storage.updateSettings(s)
    }
}
