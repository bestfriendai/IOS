//
//  BillingHistoryView.swift
//  StreamyyyApp
//
//  Comprehensive billing history view with payment history, invoices, and transaction details
//

import SwiftUI
import SafariServices

struct BillingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.stripeManager) private var stripeManager
    
    @State private var paymentHistory: [PaymentHistory] = []
    @State private var invoices: [Invoice] = []
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedPayment: PaymentHistory?
    @State private var showingPaymentDetails = false
    @State private var selectedInvoice: Invoice?
    @State private var showingInvoiceDetails = false
    @State private var selectedSegment: HistorySegment = .payments
    @State private var showingFilters = false
    @State private var filterStartDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var filterEndDate = Date()
    @State private var filterStatus: PaymentStatus?
    
    private enum HistorySegment: String, CaseIterable {
        case payments = "Payments"
        case invoices = "Invoices"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack {
                    segmentedControl
                    
                    if isLoading {
                        loadingView
                    } else {
                        switch selectedSegment {
                        case .payments:
                            paymentsView
                        case .invoices:
                            invoicesView
                        }
                    }
                }
            }
            .navigationTitle("Billing History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filter") {
                        showingFilters = true
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable {
                await loadData()
            }
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
        .sheet(isPresented: $showingPaymentDetails) {
            if let payment = selectedPayment {
                PaymentDetailsView(payment: payment)
            }
        }
        .sheet(isPresented: $showingInvoiceDetails) {
            if let invoice = selectedInvoice {
                InvoiceDetailsView(invoice: invoice)
            }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersView(
                startDate: $filterStartDate,
                endDate: $filterEndDate,
                status: $filterStatus
            ) {
                Task {
                    await loadData()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        Picker("History Type", selection: $selectedSegment) {
            ForEach(HistorySegment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading billing history...")
                .scaleEffect(1.2)
            Spacer()
        }
    }
    
    // MARK: - Payments View
    
    private var paymentsView: some View {
        Group {
            if filteredPayments.isEmpty {
                emptyPaymentsView
            } else {
                paymentsListView
            }
        }
    }
    
    private var emptyPaymentsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "creditcard.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Payment History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your payment history will appear here once you make your first payment")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var paymentsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredPayments) { payment in
                    PaymentHistoryCard(payment: payment) {
                        selectedPayment = payment
                        showingPaymentDetails = true
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Invoices View
    
    private var invoicesView: some View {
        Group {
            if filteredInvoices.isEmpty {
                emptyInvoicesView
            } else {
                invoicesListView
            }
        }
    }
    
    private var emptyInvoicesView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Invoices")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your invoices will appear here once you have active subscriptions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var invoicesListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredInvoices) { invoice in
                    InvoiceCard(invoice: invoice) {
                        selectedInvoice = invoice
                        showingInvoiceDetails = true
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredPayments: [PaymentHistory] {
        paymentHistory.filter { payment in
            let dateInRange = payment.paymentDate >= filterStartDate && payment.paymentDate <= filterEndDate
            let statusMatches = filterStatus == nil || payment.status == filterStatus
            return dateInRange && statusMatches
        }
    }
    
    private var filteredInvoices: [Invoice] {
        invoices.filter { invoice in
            let dateInRange = invoice.createdDate >= filterStartDate && invoice.createdDate <= filterEndDate
            return dateInRange
        }
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        isLoading = true
        
        do {
            async let paymentsTask = loadPaymentHistory()
            async let invoicesTask = loadInvoices()
            
            let (payments, invoices) = try await (paymentsTask, invoicesTask)
            
            await MainActor.run {
                self.paymentHistory = payments
                self.invoices = invoices
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func loadPaymentHistory() async throws -> [PaymentHistory] {
        return subscriptionManager?.paymentHistory ?? []
    }
    
    private func loadInvoices() async throws -> [Invoice] {
        guard let subscription = subscriptionManager?.currentSubscription,
              let stripeCustomerId = subscription.stripeCustomerId else {
            return []
        }
        
        return try await stripeManager.getInvoices(for: stripeCustomerId)
    }
}

// MARK: - Payment History Card

struct PaymentHistoryCard: View {
    let payment: PaymentHistory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.paymentMethod ?? "Payment")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(payment.paymentDate, formatter: dateFormatter)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatAmount(payment.amount, currency: payment.currency))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: payment.status.iconName)
                                .foregroundColor(payment.status.color)
                            
                            Text(payment.status.displayName)
                                .font(.caption)
                                .foregroundColor(payment.status.color)
                        }
                    }
                }
                
                if payment.status == .failed, let failureReason = payment.failureReason {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text(failureReason)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Invoice Card

struct InvoiceCard: View {
    let invoice: Invoice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invoice #\(invoice.number)")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(invoice.createdDate, formatter: dateFormatter)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatAmount(invoice.amount, currency: invoice.currency))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: invoice.status.iconName)
                                .foregroundColor(invoice.status.color)
                            
                            Text(invoice.status.displayName)
                                .font(.caption)
                                .foregroundColor(invoice.status.color)
                        }
                    }
                }
                
                if let dueDate = invoice.dueDate {
                    HStack {
                        Text("Due: \(dueDate, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if invoice.status == .open && dueDate < Date() {
                            Text("Overdue")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Payment Details View

struct PaymentDetailsView: View {
    let payment: PaymentHistory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(formatAmount(payment.amount, currency: payment.currency))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: payment.status.iconName)
                                .foregroundColor(payment.status.color)
                            
                            Text(payment.status.displayName)
                                .font(.headline)
                                .foregroundColor(payment.status.color)
                        }
                    }
                    .padding()
                    
                    // Details
                    VStack(spacing: 16) {
                        DetailRow(title: "Payment ID", value: payment.id)
                        DetailRow(title: "Date", value: payment.paymentDate, formatter: dateTimeFormatter)
                        DetailRow(title: "Amount", value: formatAmount(payment.amount, currency: payment.currency))
                        DetailRow(title: "Currency", value: payment.currency.uppercased())
                        
                        if let paymentMethod = payment.paymentMethod {
                            DetailRow(title: "Payment Method", value: paymentMethod)
                        }
                        
                        if let stripeId = payment.stripePaymentIntentId {
                            DetailRow(title: "Stripe ID", value: stripeId)
                        }
                        
                        if let failureReason = payment.failureReason {
                            DetailRow(title: "Failure Reason", value: failureReason, valueColor: .red)
                        }
                        
                        if let receiptURL = payment.receiptURL {
                            Button("View Receipt") {
                                if let url = URL(string: receiptURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Payment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Invoice Details View

struct InvoiceDetailsView: View {
    let invoice: Invoice
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Invoice #\(invoice.number)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(formatAmount(invoice.amount, currency: invoice.currency))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: invoice.status.iconName)
                                .foregroundColor(invoice.status.color)
                            
                            Text(invoice.status.displayName)
                                .font(.headline)
                                .foregroundColor(invoice.status.color)
                        }
                    }
                    .padding()
                    
                    // Details
                    VStack(spacing: 16) {
                        DetailRow(title: "Invoice Number", value: invoice.number)
                        DetailRow(title: "Created", value: invoice.createdDate, formatter: dateFormatter)
                        
                        if let dueDate = invoice.dueDate {
                            DetailRow(title: "Due Date", value: dueDate, formatter: dateFormatter)
                        }
                        
                        if let paidDate = invoice.paidDate {
                            DetailRow(title: "Paid Date", value: paidDate, formatter: dateFormatter)
                        }
                        
                        DetailRow(title: "Amount", value: formatAmount(invoice.amount, currency: invoice.currency))
                        DetailRow(title: "Currency", value: invoice.currency.uppercased())
                        
                        if let description = invoice.description {
                            DetailRow(title: "Description", value: description)
                        }
                        
                        if let stripeId = invoice.stripeInvoiceId {
                            DetailRow(title: "Stripe ID", value: stripeId)
                        }
                        
                        if let hostedURL = invoice.hostedInvoiceURL {
                            Button("View Invoice") {
                                if let url = URL(string: hostedURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if let pdfURL = invoice.invoicePDFURL {
                            Button("Download PDF") {
                                if let url = URL(string: pdfURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Invoice Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let title: String
    let value: String
    let valueColor: Color
    
    init(title: String, value: String, valueColor: Color = .primary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    init(title: String, value: Date, formatter: DateFormatter) {
        self.title = title
        self.value = formatter.string(from: value)
        self.valueColor = .primary
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Filters View

struct FiltersView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var status: PaymentStatus?
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("All").tag(PaymentStatus?.none)
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(PaymentStatus?.some(status))
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Invoice Model

struct Invoice: Identifiable, Codable {
    let id: String
    let number: String
    let stripeInvoiceId: String?
    let amount: Double
    let currency: String
    let status: InvoiceStatus
    let createdDate: Date
    let dueDate: Date?
    let paidDate: Date?
    let description: String?
    let hostedInvoiceURL: String?
    let invoicePDFURL: String?
    let metadata: [String: String]
    
    enum InvoiceStatus: String, CaseIterable, Codable {
        case draft = "draft"
        case open = "open"
        case paid = "paid"
        case uncollectible = "uncollectible"
        case void = "void"
        
        var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .open: return "Open"
            case .paid: return "Paid"
            case .uncollectible: return "Uncollectible"
            case .void: return "Void"
            }
        }
        
        var color: Color {
            switch self {
            case .draft: return .gray
            case .open: return .orange
            case .paid: return .green
            case .uncollectible: return .red
            case .void: return .gray
            }
        }
        
        var iconName: String {
            switch self {
            case .draft: return "doc.circle"
            case .open: return "clock.circle"
            case .paid: return "checkmark.circle.fill"
            case .uncollectible: return "exclamationmark.triangle.fill"
            case .void: return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - Extensions

extension PaymentStatus {
    var iconName: String {
        switch self {
        case .succeeded: return "checkmark.circle.fill"
        case .pending: return "clock.circle"
        case .failed: return "xmark.circle.fill"
        case .canceled: return "xmark.circle"
        case .refunded: return "arrow.counterclockwise.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    BillingHistoryView()
        .environment(\.subscriptionManager, nil)
        .environment(\.stripeManager, StripeManager.shared)
}