import FuelStationCore


import SwiftUI

@main
struct FuelStationApp: App {
    @State private var storage = StorageManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(storage)
                .onAppear { storage.backupStore() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    storage.backupStore()
                }
        }
        .windowResizability(.contentMinSize)
    }
}

enum AppModule: String, CaseIterable, Identifiable {
    case dashboard, inventory, pumps, transactions, lubeShop, customers, shifts, finances, reports, search, settings
    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .inventory: return "Inventory"
        case .pumps: return "Pumps"
        case .transactions: return "Transactions"
        case .lubeShop: return "Lube Shop"
        case .customers: return "Customers"
        case .shifts: return "Shifts"
        case .finances: return "Finances"
        case .reports: return "Reports"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .inventory: return "fuelpump"
        case .pumps: return "ev.charger"
        case .transactions: return "list.clipboard"
        case .lubeShop: return "drop.fill"
        case .customers: return "person.2"
        case .shifts: return "clock"
        case .finances: return "dollarsign.circle"
        case .reports: return "chart.bar.xaxis"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(StorageManager.self) private var storage
    @State private var selectedModule: AppModule = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            moduleView
        }
        .sheet(isPresented: Binding(
            get: { !storage.settings.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
    }

    private var sidebar: some View {
        List(AppModule.allCases, selection: $selectedModule) { module in
            Label(module.label, systemImage: module.icon)
                .tag(module)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }

    @ViewBuilder
    private var moduleView: some View {
        switch selectedModule {
        case .dashboard: DashboardView()
        case .inventory: InventoryView()
        case .pumps: PumpManagementView()
        case .transactions: TransactionsView()
        case .lubeShop: LubeShopView()
        case .customers: CustomersView()
        case .shifts: ShiftsView()
        case .finances: FinancesView()
        case .reports: ReportsView()
        case .search: SearchView()
        case .settings: SettingsView()
        }
    }
}
