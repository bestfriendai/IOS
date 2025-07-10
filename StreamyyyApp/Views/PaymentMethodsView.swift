//
//  PaymentMethodsView.swift
//  StreamyyyApp
//
//  Comprehensive payment methods management view with add/remove/update functionality
//

import SwiftUI
import Stripe
import PassKit

struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.stripeManager) private var stripeManager
    
    @State private var paymentMethods: [PaymentMethod] = []
    @State private var isLoading = false
    @State private var showingAddPaymentMethod = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingDeleteConfirmation = false
    @State private var methodToDelete: PaymentMethod?
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack {
                    if isLoading {
                        loadingView
                    } else if paymentMethods.isEmpty {
                        emptyStateView
                    } else {
                        paymentMethodsList
                    }
                }
            }
            .navigationTitle("Payment Methods")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddPaymentMethod = true
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable {
                await loadPaymentMethods()
            }
        }
        .onAppear {
            Task {
                await loadPaymentMethods()
            }
        }
        .sheet(isPresented: $showingAddPaymentMethod) {
            AddPaymentMethodView { newMethod in
                if let newMethod = newMethod {
                    paymentMethods.append(newMethod)
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
        .alert("Delete Payment Method", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let method = methodToDelete {
                    deletePaymentMethod(method)
                }
            }
            Button("Cancel", role: .cancel) {
                methodToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this payment method?")
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
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading payment methods...")
                .scaleEffect(1.2)
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "creditcard.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Payment Methods")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add a payment method to start your subscription and manage billing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add Payment Method") {
                showingAddPaymentMethod = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Payment Methods List
    
    private var paymentMethodsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(paymentMethods) { method in
                    PaymentMethodCard(
                        method: method,
                        isDefault: method.isDefault,
                        onSetDefault: {
                            setDefaultPaymentMethod(method)
                        },
                        onDelete: {
                            methodToDelete = method
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func loadPaymentMethods() async {
        isLoading = true
        
        do {
            let methods = try await stripeManager.getPaymentMethods()
            await MainActor.run {
                paymentMethods = methods
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
    
    private func setDefaultPaymentMethod(_ method: PaymentMethod) {
        Task {
            do {
                try await stripeManager.setDefaultPaymentMethod(method.id)
                
                // Update local state
                await MainActor.run {
                    for i in paymentMethods.indices {
                        paymentMethods[i].isDefault = paymentMethods[i].id == method.id
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func deletePaymentMethod(_ method: PaymentMethod) {
        Task {
            do {
                try await stripeManager.deletePaymentMethod(method.id)
                
                await MainActor.run {
                    paymentMethods.removeAll { $0.id == method.id }
                    methodToDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    methodToDelete = nil
                }
            }
        }
    }
}

// MARK: - Payment Method Card

struct PaymentMethodCard: View {
    let method: PaymentMethod
    let isDefault: Bool
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Payment method icon and info
                HStack(spacing: 12) {
                    Image(systemName: method.iconName)
                        .font(.title2)
                        .foregroundColor(method.brandColor)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(method.displayName)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(method.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isDefault {
                        Text("Default")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                Menu {
                    if !isDefault {
                        Button("Set as Default") {
                            onSetDefault()
                        }
                    }
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Additional information
            if let expiryDate = method.expiryDate {
                HStack {
                    Text("Expires: \(expiryDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if method.isExpiringSoon {
                        Text("Expiring Soon")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - Add Payment Method View

struct AddPaymentMethodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stripeManager) private var stripeManager
    
    let onPaymentMethodAdded: (PaymentMethod?) -> Void
    
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedPaymentType: PaymentType = .card
    @State private var showingApplePay = false
    
    private enum PaymentType: String, CaseIterable {
        case card = "card"
        case applePay = "apple_pay"
        
        var displayName: String {
            switch self {
            case .card: return "Credit/Debit Card"
            case .applePay: return "Apple Pay"
            }
        }
        
        var iconName: String {
            switch self {
            case .card: return "creditcard"
            case .applePay: return "applelogo"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Payment type selector
                VStack(spacing: 16) {
                    Text("Choose Payment Method")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(PaymentType.allCases, id: \.self) { type in
                        if type == .applePay && !stripeManager.canMakeApplePayPayments() {
                            // Skip Apple Pay if not available
                        } else {
                            PaymentTypeCard(
                                type: type,
                                isSelected: selectedPaymentType == type
                            ) {
                                selectedPaymentType = type
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Add button
                Button(action: addPaymentMethod) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add Payment Method")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
                
                Text("Your payment information is securely processed by Stripe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    
    private func addPaymentMethod() {
        isProcessing = true
        
        Task {
            do {
                let paymentMethod: PaymentMethod
                
                switch selectedPaymentType {
                case .card:
                    paymentMethod = try await stripeManager.addCardPaymentMethod()
                case .applePay:
                    paymentMethod = try await stripeManager.addApplePayPaymentMethod()
                }
                
                await MainActor.run {
                    isProcessing = false
                    onPaymentMethodAdded(paymentMethod)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Payment Type Card

struct PaymentTypeCard: View {
    let type: AddPaymentMethodView.PaymentType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.purple : Color(.systemGray6))
                    .cornerRadius(8)
                
                Text(type.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Payment Method Model

struct PaymentMethod: Identifiable, Codable {
    let id: String
    let type: String
    let brand: String?
    let last4: String?
    let expiryMonth: Int?
    let expiryYear: Int?
    let isDefault: Bool
    let fingerprint: String?
    let country: String?
    let funding: String?
    let wallet: String?
    
    var displayName: String {
        switch type {
        case "card":
            if let brand = brand, let last4 = last4 {
                return "\(brand.capitalized) •••• \(last4)"
            }
            return "Card"
        case "apple_pay":
            return "Apple Pay"
        case "google_pay":
            return "Google Pay"
        default:
            return type.capitalized
        }
    }
    
    var description: String {
        switch type {
        case "card":
            if let funding = funding {
                return funding.capitalized
            }
            return "Credit/Debit Card"
        case "apple_pay":
            return "Apple Pay"
        default:
            return ""
        }
    }
    
    var iconName: String {
        switch type {
        case "card":
            return "creditcard"
        case "apple_pay":
            return "applelogo"
        case "google_pay":
            return "g.circle"
        default:
            return "creditcard"
        }
    }
    
    var brandColor: Color {
        guard let brand = brand else { return .primary }
        
        switch brand.lowercased() {
        case "visa":
            return .blue
        case "mastercard":
            return .red
        case "amex", "american_express":
            return .green
        case "discover":
            return .orange
        case "jcb":
            return .purple
        case "diners":
            return .gray
        case "unionpay":
            return .blue
        default:
            return .primary
        }
    }
    
    var expiryDate: Date? {
        guard let month = expiryMonth, let year = expiryYear else { return nil }
        
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        
        let calendar = Calendar.current
        return calendar.date(from: components)
    }
    
    var isExpiringSoon: Bool {
        guard let expiryDate = expiryDate else { return false }
        
        let calendar = Calendar.current
        let threeMonthsFromNow = calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        
        return expiryDate < threeMonthsFromNow
    }
}

// MARK: - Preview

#Preview {
    PaymentMethodsView()
        .environment(\.subscriptionManager, nil)
        .environment(\.stripeManager, StripeManager.shared)
}