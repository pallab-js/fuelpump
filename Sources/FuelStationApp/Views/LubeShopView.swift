import FuelStationCore
import SwiftUI

struct LubeShopView: View {
    @Environment(StorageManager.self) private var storage
    @State private var showingAddProduct = false
    @State private var selectedProduct: LubeProduct?
    @State private var showingSaleDialog = false
    @State private var saleQuantity = 1

    var body: some View {
        HSplitView {
            productList
                .frame(minWidth: 300, idealWidth: 400)
            if let selectedProduct {
                productDetail(selectedProduct)
                    .frame(minWidth: 300, idealWidth: 500)
                    .id(selectedProduct.id)
            } else {
                Text("Select a product")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Product", systemImage: "plus.square") {
                    showingAddProduct = true
                }
            }
        }
        .sheet(isPresented: $showingAddProduct) { AddLubeProductView() }
        .sheet(isPresented: $showingSaleDialog) {
            if let selectedProduct {
                LubeSaleView(product: selectedProduct)
            }
        }
    }

    private var productList: some View {
        List(selection: $selectedProduct) {
            ForEach(storage.lubeProducts) { product in
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.name).fontWeight(.bold)
                        Text("\(product.brand) - \(product.grade)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(product.stock) in stock")
                            .font(.caption)
                            .foregroundStyle(product.stock < 5 ? .red : .secondary)
                        Text(formatCurrency(product.price))
                            .font(.caption2).fontWeight(.semibold)
                    }
                }
                .tag(product)
            }
            .onDelete { indices in
                for idx in indices {
                    storage.deleteLubeProduct(storage.lubeProducts[idx].id)
                }
            }
        }
    }

    private func productDetail(_ product: LubeProduct) -> some View {
        Form {
            Section("Product Info") {
                TextField("Name", text: Binding(get: { product.name }, set: { var p = product; p.name = $0; storage.updateLubeProduct(p) }))
                TextField("Brand", text: Binding(get: { product.brand }, set: { var p = product; p.brand = $0; storage.updateLubeProduct(p) }))
                TextField("Grade", text: Binding(get: { product.grade }, set: { var p = product; p.grade = $0; storage.updateLubeProduct(p) }))
                TextField("Unit Size", text: Binding(get: { product.unitSize }, set: { var p = product; p.unitSize = $0; storage.updateLubeProduct(p) }))
            }
            
            Section("Pricing & Stock") {
                HStack {
                    Text("Price")
                    TextField("Amount", value: Binding(get: { product.price }, set: { var p = product; p.price = $0; storage.updateLubeProduct(p) }), formatter: currencyFormatter)
                }
                Stepper("Stock: \(product.stock)", value: Binding(get: { product.stock }, set: { var p = product; p.stock = $0; storage.updateLubeProduct(p) }), in: 0...999)
            }
            
            Section {
                Button("Record Sale") {
                    showingSaleDialog = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(product.stock == 0)
            }
            
            Section("Recent Sales") {
                let sales = storage.lubeSales.filter { $0.productID == product.id }.sorted { $0.date > $1.date }.prefix(10)
                if sales.isEmpty {
                    Text("No sales yet").foregroundStyle(.secondary)
                } else {
                    ForEach(sales) { sale in
                        HStack {
                            Text(formatDate(sale.date)).font(.caption)
                            Spacer()
                            Text("\(sale.quantity) units").font(.caption2)
                            Text(storage.formatCurrency(sale.totalAmount)).font(.caption).fontWeight(.bold)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AddLubeProductView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var grade = ""
    @State private var size = "1 Litre"
    @State private var price = 450.0
    @State private var stock = 10

    var body: some View {
        Form {
            TextField("Product Name", text: $name)
            TextField("Brand", text: $brand)
            TextField("Grade", text: $grade)
            TextField("Unit Size", text: $size)
            TextField("Price", value: $price, formatter: currencyFormatter)
            Stepper("Initial Stock: \(stock)", value: $stock, in: 0...100)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    storage.addLubeProduct(LubeProduct(name: name, brand: brand, grade: grade, unitSize: size, price: price, stock: stock))
                    dismiss()
                }
                .disabled(name.isEmpty || brand.isEmpty)
            }
        }
        .frame(minWidth: 400)
    }
}

struct LubeSaleView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss
    let product: LubeProduct
    @State private var quantity = 1
    @State private var customerID: UUID?
    @State private var attendantName: String?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Text("Selling \(product.name)").font(.headline)
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...product.stock)
            
            if let activeShift = storage.activeShift, !activeShift.attendants.isEmpty {
                Picker("Attendant", selection: $attendantName) {
                    Text("Unspecified").tag(nil as String?)
                    Divider()
                    ForEach(activeShift.attendants, id: \.self) { att in
                        Text(att).tag(att as String?)
                    }
                }
            }
            
            Picker("Customer", selection: $customerID) {
                Text("None / Guest").tag(nil as UUID?)
                ForEach(storage.customers) { cust in
                    Text(cust.name).tag(cust.id as UUID?)
                }
            }
            
            LabeledContent("Total Amount", value: storage.formatCurrency(product.price * Double(quantity)))
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm Sale") {
                    let sale = LubeSale(productID: product.id, quantity: quantity, totalAmount: product.price * Double(quantity), customerID: customerID, attendantName: attendantName)
                    do {
                        try storage.addLubeSale(sale)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .frame(minWidth: 400)
    }
}
