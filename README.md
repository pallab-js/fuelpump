# FuelPump Station Manager

FuelPump is a comprehensive, production-ready fuel station management application designed for macOS. It provides a robust suite of tools for station owners to manage inventory, track sales, monitor attendant performance, and generate accessible financial reports.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-6.0-orange.svg)
![Accessibility](https://img.shields.io/badge/accessibility-WCAG%202.2%20AA-green.svg)

## 🚀 Features

- **Dashboard & Analytics**: Real-time KPI monitoring with interactive, screen-reader accessible charts for sales trends, payment breakdown, and tank levels.
- **Inventory Management**: Track fuel tank capacities and levels with low-stock alerts. Manage lube shop products and stock.
- **Transaction Tracking**: Record fuel sales and lube purchases with support for multiple payment methods (Cash, Card, UPI, Credit, Fuel Card).
- **Shift Management**: Track employee shifts, opening/closing cash, and attendant-wise performance.
- **Financial Reporting**: Generate detailed daily closure reports with automated cash reconciliation and CSV export capabilities.
- **Interactive Onboarding**: A step-by-step setup guide to configure station details, fuel types, and tanks on the first launch.
- **Dynamic Receipts**: Generate and print professional tax invoices with customizable station info and localized currency formatting.

## 🛠 Technical Stack

- **Framework**: SwiftUI (using the modern `Observation` framework)
- **Architecture**: Clean, modular design with a dedicated `FuelStationCore` library.
- **Storage**: Local JSON-based atomic persistence in the User's Application Support directory.
- **Accessibility**: Built with WCAG 2.2 Level AA standards, featuring full screen-reader support for data visualizations.
- **Platform**: Native macOS application optimized for macOS 14 and later.

## 🔒 Security & Privacy

- **Local-First**: All data is stored locally on your machine. No data is sent to external servers.
- **Data Integrity**: Built-in validation prevents transactions when fuel or stock levels are insufficient.
- **Privacy Awareness**: The app explicitly reminds users to use machine-level encryption (like FileVault) to protect customer PII.

## 📦 Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pallab-js/fuelpump.git
   cd fuelpump
   ```

2. **Open with Xcode**:
   Open `Package.swift` in Xcode 15.0 or later.

3. **Build and Run**:
   Select the `FuelStationApp` target and press `Cmd + R`.

4. **Initial Setup**:
   On the first launch, follow the Onboarding assistant to configure your station's currency, fuel types, and tanks.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ for station owners.
