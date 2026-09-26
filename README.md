# FuelPump

A native macOS app for running a fuel station: inventory, sales, shifts, customers, and financial reports — all stored locally, no server required.

![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-6.3-orange.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## Features

- **Dashboard** — KPIs, sales trends, payment breakdown, tank levels, low-stock alerts
- **Inventory** — fuel tanks with delivery capacity warnings, lube shop stock
- **Sales** — fuel and lube transactions; Cash, UPI, Card, Credit, Fuel Card
- **Shifts** — opening/closing cash reconciliation and attendant performance
- **Reports** — daily closure reports with CSV/JSON export
- **Receipts** — printable tax invoices with localized currency formatting
- **Customers** — loyalty points, credit (khata) accounts, transaction history
- **Search** — debounced search across customers, transactions, deliveries, expenses
- **Onboarding** — first-launch setup wizard for station details, fuel types, and tanks

## Requirements

- macOS 14 or later
- Swift 6.3+ toolchain (no Xcode required)

## Getting started

```bash
git clone https://github.com/pallab-js/fuelpump.git
cd fuelpump
swift run FuelStationApp
```

Or open `Package.swift` in Xcode 15+, select the `FuelStationApp` scheme, and press `Cmd + R`.

On first launch, follow the onboarding assistant to configure currency, fuel types, and tanks.

### Sample data

```bash
swift run FuelStationApp --seed-demo
```

Also available in **Settings → Data Management → Load Demo Data**. Both create a deterministic 30-day demo station (tanks, pumps, customers, shifts, sales, lube sales, deliveries, expenses) — and both **replace every existing record**, so don't use them on a station with real data.

## Development

```bash
swift build                 # debug build
swift test                  # run tests (10 tests)
bash validate.sh            # release build + binary check + tests
```

CI (GitHub Actions) builds debug and release, then runs `validate.sh` on macOS with Swift 6.3.3.

## Architecture

- **Two-target Swift package** — `FuelStationCore` (models, storage, encryption, utilities) and `FuelStationApp` (SwiftUI views)
- **UI** — SwiftUI with `@Observable`; WCAG 2.2 AA accessibility
- **Storage** — CoreData; settings and lists stored as blobs, transactions/lube sales as entities; serialized writes through a single background context
- **Encryption** — customer PII (name, phone, email) encrypted at rest with AES-256; key in the macOS Keychain
- **Persistence** — debounced (400 ms) blob saves; `flush()` on termination; backups as JSON

## Security & privacy

- Local-first: data never leaves the machine
- Customer PII encrypted at rest, key in Keychain
- Validation blocks overspending tanks/stock and warns on tank overfill

## Known limitations

**French localization applies only to `loc()`-wrapped strings.** SwiftPM nests `Localizable.strings` in `FuelStationApp_FuelStationCore.bundle`, so bare SwiftUI literals like `Text("…")` resolve against `Bundle.main` and fall back to English — ~430 call sites in `Sources/FuelStationApp/Views/` would need `loc(...)`. See `Sources/FuelStationCore/Utilities.swift` for the wrapper.

## License

MIT — see [LICENSE](LICENSE).
