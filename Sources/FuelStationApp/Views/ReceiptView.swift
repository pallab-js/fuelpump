import FuelStationCore


import SwiftUI
import AppKit

struct ReceiptView: View {
    let transaction: FuelTransaction
    @Environment(StorageManager.self) private var storage

    var body: some View {
        VStack(spacing: 16) {
            header
            
            Divider()
            
            details
            
            Divider()
            
            if !storage.settings.upiID.isEmpty {
                upiSection
                Divider()
            }
            
            footer
        }
        .padding(30)
        .frame(width: 350)
        .background(Color.white)
        .foregroundStyle(.black)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(storage.settings.stationName)
                .font(.title2)
                .fontWeight(.bold)
            Text(storage.settings.address)
                .font(.caption)
            if !storage.settings.phone.isEmpty {
                Text(storage.settings.phone)
                    .font(.caption)
            }
            
            if !storage.settings.gstin.isEmpty {
                Text("GSTIN: \(storage.settings.gstin)")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.top, 2)
            }
            
            Text("TAX INVOICE")
                .font(.headline)
                .padding(.top, 4)
        }
    }

    private var details: some View {
        VStack(spacing: 8) {
            detailRow(label: "Invoice No:", value: transaction.id.uuidString.prefix(8).uppercased())
            detailRow(label: "Date:", value: formatDate(transaction.date))
            detailRow(label: "Pump:", value: "\(transaction.pumpID)")
            detailRow(label: "Product:", value: transaction.fuelType)
            detailRow(label: "Quantity:", value: storage.formatVolume(transaction.liters))
            detailRow(label: "Rate/Litre:", value: storage.formatCurrency(transaction.amount / transaction.liters))
            detailRow(label: "Payment:", value: transaction.paymentMethod)
            
            Divider()
            
            HStack {
                Text("TOTAL AMOUNT")
                    .fontWeight(.bold)
                Spacer()
                Text(storage.formatCurrency(transaction.amount))
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private var upiSection: some View {
        VStack(spacing: 4) {
            Text("Pay via UPI")
                .font(.caption)
                .fontWeight(.semibold)
            Text(storage.settings.upiID)
                .font(.system(size: 10, design: .monospaced))
            Text("Scan QR or pay to VPA above")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Thank you for your business!")
                .italic()
            Text("Please come again.")
            Text(formatDate(Date()))
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
class PrintUtility {
    static func printReceipt(transaction: FuelTransaction) {
        let receiptView = ReceiptView(transaction: transaction)
        let view = NSHostingView(rootView: receiptView)
        view.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        
        let operation = NSPrintOperation(view: view, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.run()
    }
}
