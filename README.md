# FuelPump Station Manager

FuelPump is a comprehensive, production-ready fuel station management application designed for macOS. It provides a robust suite of tools for station owners to manage inventory, track sales, monitor attendant performance, and generate accessible financial reports.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-6.3-orange.svg)
![Accessibility](https://img.shields.io/badge/accessibility-WCAG%202.2%20AA-green.svg)

## Features

- **Dashboard & Analytics**: Real-time KPI monitoring with interactive charts for sales trends, payment breakdown, and tank levels. Low-stock alerts with positive-state indicators.
- **Inventory Management**: Track fuel tank capacities and levels with delivery capacity warnings. Manage lube shop products and stock.
- **Transaction Tracking**: Record fuel sales and lube purchases with support for multiple payment methods (Cash, Card, UPI, Credit, Fuel Card).
- **Shift Management**: Track employee shifts, opening/closing cash (cash-only reconciliation), and attendant-wise performance.
- **Financial Reporting**: Generate detailed daily closure reports with automated cash reconciliation and CSV/JSON export capabilities.
- **Interactive Onboarding**: A step-by-step setup guide to configure station details, fuel types, and tanks on the first launch.
- **Dynamic Receipts**: Generate and print professional tax invoices with customizable station info and localized currency formatting.
- **Customer Loyalty**: Track customer loyalty points, credit accounts (khata), and transaction history.
- **Search**: Debounced full-text search across customers, transactions, deliveries, and expenses.

## Technical Stack

- **Framework**: SwiftUI with the `@Observable` pattern (Observation framework)
- **Architecture**: Two-target SPM package — `FuelStationCore` (models, storage, encryption, utilities) and `FuelStationApp` (views)
- **Storage**: CoreData with encrypted blob storage for settings and binary data. Individual entities for transactions, lube sales, and customers.
- **Encryption**: Keychain-stored AES-256 encryption for customer PII (name, phone, email) with automatic key generation on first launch.
- **Accessibility**: Built with WCAG 2.2 Level AA standards, featuring `ContentUnavailableView` empty states and full screen-reader support.
- **Platform**: Native macOS application optimized for macOS 14 and later. No Xcode required — builds and runs with `swift run FuelStationApp`.

## Security & Privacy

- **Local-First**: All data is stored locally on your machine. No data is sent to external servers.
- **Encrypted PII**: Customer names, phone numbers, and email addresses are encrypted at rest using AES-256 with keys stored in the macOS Keychain.
- **Data Integrity**: Built-in validation prevents transactions when fuel or stock levels are insufficient. Delivery capacity warnings prevent overfilling tanks.
- **Debounced Persistence**: Settings and configuration changes use 400ms debounced saves to prevent data loss from rapid updates.

## Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pallab-js/fuelpump.git
   cd fuelpump
   ```

2. **Build and Run** (no Xcode required):
   ```bash
   swift run FuelStationApp
   ```

3. **Or build with Xcode**:
   Open `Package.swift` in Xcode 15.0 or later, select the `FuelStationApp` scheme, and press `Cmd + R`.

4. **Initial Setup**:
   On the first launch, follow the Onboarding assistant to configure your station's currency, fuel types, and tanks.

5. **Try it with sample data** (optional):
   ```bash
   swift run FuelStationApp --seed-demo
   ```
   or use **Settings → Data Management → Load Demo Data**. Both create a
   deterministic 30-day demo station (tanks, pumps, customers, shifts, sales,
   lube sales, deliveries, expenses) — and both **replace every existing
   record**, so do not use them on a station with real data.

## Known Issues

### French localization is not applied to most UI strings

`FuelStationCore/Resources/{en,fr}.lproj/Localizable.strings` contain ~150 translated
strings, but SwiftPM nests those resources in `FuelStationApp_FuelStationCore.bundle`.
SwiftUI string literals such as `Text("…")`, `Section("…")`, `Button("…")` resolve
against `Bundle.main`, which has no `.lproj`, so they always fall back to the English
key. Only strings passed through `loc()` (`Sources/FuelStationCore/Utilities.swift`)
or `Text(_, bundle: .module)` are actually localized — chart titles/empty states today.

Fixing it properly means:

1. Wrapping every literal string call site (~430 across `Sources/FuelStationApp/Views/`)
   with `loc(...)` — safe, since a missing key falls back to the English key.
2. Adding the keys missing from `fr`: `Dashboard Layout`, `INR (₹)`,
   `Privacy & Security Notice`, `Station Details`.
3. Verifying with a French-locale run: `LANG=fr_FR.UTF-8 swift run FuelStationApp`.

Note: putting an `.lproj` in the app target does **not** help — SwiftPM also nests
executable-target resources in `FuelStationApp_FuelStationApp.bundle`, so `Bundle.main`
still never sees them.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
