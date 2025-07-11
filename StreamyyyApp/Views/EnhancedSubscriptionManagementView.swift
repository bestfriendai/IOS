//
//  EnhancedSubscriptionManagementView.swift
//  StreamyyyApp
//
//  Complete subscription management with payment methods, billing history, and Apple Pay
//

import SwiftUI
import PassKit

// MARK: - Enhanced Subscription Management View
public struct EnhancedSubscriptionManagementView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @StateObject private var loadingManager = LoadingStateManager.shared
    @StateObject private var errorHandler = ProductionErrorHandler.shared
    @State private var selectedTab = 0
    @State private var showingUpgrade = false
    @State private var showingCancelDialog = false
    @State private var showingAddPaymentMethod = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with current subscription info
                subscriptionHeader
                
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Plans").tag(1)
                    Text("Payment").tag(2)
                    Text("Billing").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    subscriptionOverview.tag(0)
                    subscriptionPlans.tag(1)
                    paymentMethods.tag(2)
                    billingHistory.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .overlay(loadingOverlay)
            .alert("Error", isPresented: $errorHandler.showingError) {
                Button("OK") {
                    errorHandler.clearError()
                }
            } message: {
                Text(errorHandler.currentError?.localizedDescription ?? "Unknown error")
            }
            .task {
                await viewModel.refreshSubscriptionStatus()
            }
        }
    }
    
    // MARK: - Subscription Header
    private var subscriptionHeader: some View {
        VStack(spacing: 16) {
            // Current plan badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let subscription = viewModel.currentSubscription {
                        HStack(spacing: 8) {
                            Text(subscription.plan.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Circle()
                                .fill(subscription.statusColor)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(subscription.status.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Free Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("No active subscription")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Plan icon
                Image(systemName: viewModel.currentSubscription?.plan.icon ?? "star")
                    .font(.title)
                    .foregroundColor(viewModel.currentSubscription?.plan.color ?? .gray)
            }
            
            // Current features summary
            if let subscription = viewModel.currentSubscription {
                HStack(spacing: 16) {
                    FeatureBadge(
                        icon: "rectangle.grid.2x2",
                        text: "\(subscription.plan.maxStreams) Streams",
                        color: .blue
                    )
                    
                    if subscription.hasFeature(.advancedLayouts) {
                        FeatureBadge(
                            icon: "square.grid.3x3",
                            text: "Layouts",
                            color: .green
                        )
                    }
                    
                    if subscription.hasFeature(.analytics) {
                        FeatureBadge(
                            icon: "chart.bar",
                            text: "Analytics",
                            color: .purple
                        )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Overview Tab
    private var subscriptionOverview: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current subscription details
                if let subscription = viewModel.currentSubscription {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Subscription Details")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            DetailRow(
                                title: "Plan",
                                value: subscription.plan.displayName
                            )
                            
                            DetailRow(
                                title: "Billing",
                                value: subscription.billingCycle
                            )
                            
                            DetailRow(
                                title: "Next Payment",
                                value: viewModel.formattedNextBillingDate
                            )
                            
                            DetailRow(
                                title: "Amount",
                                value: subscription.displayPrice
                            )
                            
                            if subscription.willCancelAtPeriodEnd {
                                DetailRow(
                                    title: "Status",
                                    value: "Cancels on \(viewModel.formattedNextBillingDate)",
                                    valueColor: .orange
                                )
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if viewModel.canUpgrade {
                            Button("Upgrade Plan") {
                                showingUpgrade = true
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilitySubscriptionButton(
                                plan: "Higher tier",
                                price: "Various prices"
                            )
                        }
                        
                        if !subscription.willCancelAtPeriodEnd {
                            Button("Cancel Subscription") {
                                showingCancelDialog = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        } else {
                            Button("Reactivate Subscription") {
                                Task {
                                    await reactivateSubscription()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // No subscription - show upgrade options
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                        
                        Text("Upgrade to Pro")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Unlock unlimited streams, advanced layouts, and premium features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("View Plans") {
                            selectedTab = 1
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .cardStyle()
                }
                
                // Usage statistics
                if let subscription = viewModel.currentSubscription {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Usage This Period")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            UsageBar(
                                title: "Streams Used",
                                current: subscription.usageStats.streamsUsed,
                                limit: subscription.plan.maxStreams == Int.max ? 100 : subscription.plan.maxStreams,
                                unlimited: subscription.plan.maxStreams == Int.max
                            )
                            
                            if subscription.hasFeature(.analytics) {
                                UsageBar(
                                    title: "Bandwidth",
                                    current: Int(subscription.usageStats.bandwidthUsed / 1_000_000), // Convert to MB
                                    limit: 10000, // 10GB limit example
                                    unit: "MB"
                                )
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Plans Tab
    private var subscriptionPlans: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Billing interval toggle
                Picker("Billing Interval", selection: $viewModel.selectedBillingInterval) {
                    Text("Monthly").tag(BillingInterval.monthly)
                    Text("Yearly").tag(BillingInterval.yearly)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if viewModel.selectedBillingInterval == .yearly {
                    Text("Save \(viewModel.yearlyDiscount) with yearly billing")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                
                // Available plans
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.availablePlans, id: \.self) { plan in
                        PlanCard(
                            plan: plan,
                            interval: viewModel.selectedBillingInterval,
                            isCurrentPlan: viewModel.currentSubscription?.plan == plan,
                            isRecommended: plan == .premium
                        ) {
                            await subscribeToPlan(plan)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Payment Methods Tab
    private var paymentMethods: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Add payment method section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Payment Methods")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Add New") {
                            showingAddPaymentMethod = true
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                    
                    // Payment methods list
                    if viewModel.paymentMethods.isEmpty {
                        EmptyStateView(
                            title: "No Payment Methods",
                            subtitle: "Add a payment method to manage your subscription",
                            iconName: "creditcard",
                            actionTitle: "Add Payment Method"
                        ) {
                            showingAddPaymentMethod = true
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.paymentMethods) { paymentMethod in
                                PaymentMethodCard(
                                    paymentMethod: paymentMethod,
                                    onSetDefault: {
                                        await setDefaultPaymentMethod(paymentMethod)
                                    },
                                    onDelete: {
                                        await deletePaymentMethod(paymentMethod)
                                    }
                                )
                            }
                        }
                    }
                }
                .cardStyle()
                
                // Apple Pay section
                if StripeService.shared.isApplePayAvailable {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Payment")
                            .font(.headline)
                        
                        Text("Use Apple Pay for secure, one-touch payments")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ApplePayButton(
                            type: .pay,
                            style: .black
                        ) {
                            await processApplePayPayment()
                        }
                        .frame(height: 50)
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddPaymentMethod) {
            AddPaymentMethodView { success in
                if success {
                    Task {
                        await viewModel.refreshSubscriptionStatus()
                    }
                }
                showingAddPaymentMethod = false
            }
        }
    }
    
    // MARK: - Billing History Tab
    private var billingHistory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Billing History")
                    .font(.headline)
                    .padding(.horizontal)
                
                if viewModel.invoices.isEmpty {
                    EmptyStateView(
                        title: "No Billing History",
                        subtitle: "Your invoices and receipts will appear here",
                        iconName: "doc.text"
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.invoices) { invoice in
                            InvoiceCard(invoice: invoice) {
                                await downloadInvoice(invoice)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if loadingManager.isLoading {
                LoadingStateView(
                    message: loadingManager.loadingMessage,
                    showProgress: loadingManager.progress != nil,
                    progress: loadingManager.progress
                )
                .background(.regularMaterial)
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Actions
    private func subscribeToPlan(_ plan: SubscriptionPlan) async {
        do {
            loadingManager.startLoading(message: "Setting up subscription...")
            try await viewModel.subscribe(to: plan, billingInterval: viewModel.selectedBillingInterval)
        } catch {
            errorHandler.handle(error, context: "Subscription")
        }
        loadingManager.stopLoading()
    }
    
    private func reactivateSubscription() async {
        do {
            loadingManager.startLoading(message: "Reactivating subscription...")
            try await viewModel.reactivateSubscription()
        } catch {
            errorHandler.handle(error, context: "Reactivation")
        }
        loadingManager.stopLoading()
    }
    
    private func setDefaultPaymentMethod(_ paymentMethod: PaymentMethodDisplayModel) async {
        do {
            loadingManager.startLoading(message: "Updating payment method...")
            try await viewModel.setDefaultPaymentMethod(paymentMethod)
        } catch {
            errorHandler.handle(error, context: "Payment Method Update")
        }
        loadingManager.stopLoading()
    }
    
    private func deletePaymentMethod(_ paymentMethod: PaymentMethodDisplayModel) async {
        do {
            loadingManager.startLoading(message: "Removing payment method...")
            try await viewModel.removePaymentMethod(paymentMethod)
        } catch {
            errorHandler.handle(error, context: "Payment Method Removal")
        }
        loadingManager.stopLoading()
    }
    
    private func processApplePayPayment() async {
        do {
            loadingManager.startLoading(message: "Processing Apple Pay...")
            try await viewModel.presentApplePayPayment()
        } catch {
            errorHandler.handle(error, context: "Apple Pay")
        }
        loadingManager.stopLoading()
    }
    
    private func downloadInvoice(_ invoice: InvoiceDisplayModel) async {
        do {
            loadingManager.startLoading(message: "Downloading invoice...")
            let url = try await viewModel.downloadInvoice(invoice)
            // Present document picker or share sheet
            await presentDocument(url: url)
        } catch {
            errorHandler.handle(error, context: "Invoice Download")
        }
        loadingManager.stopLoading()
    }
    
    private func presentDocument(url: URL) async {
        // Implementation would use UIDocumentInteractionController
        print("📄 Would present document: \(url)")
    }
}

// MARK: - Supporting Views
struct FeatureBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let valueColor: Color?
    
    init(title: String, value: String, valueColor: Color? = nil) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor ?? .primary)
        }
    }
}

struct UsageBar: View {
    let title: String
    let current: Int
    let limit: Int
    let unlimited: Bool
    let unit: String
    
    init(title: String, current: Int, limit: Int, unlimited: Bool = false, unit: String = "") {
        self.title = title
        self.current = current
        self.limit = limit
        self.unlimited = unlimited
        self.unit = unit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if unlimited {
                    Text("Unlimited")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                } else {
                    Text("\(current)/\(limit) \(unit)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            if !unlimited {
                ProgressView(value: Double(current), total: Double(limit))
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(current > limit * 8 / 10 ? .orange : .blue)
            }
        }
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let interval: BillingInterval
    let isCurrentPlan: Bool
    let isRecommended: Bool
    let action: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isRecommended {
                    Text("RECOMMENDED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }
            
            // Price
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$\(String(format: "%.2f", plan.price(for: interval)))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("/ \(interval.displayName.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features.prefix(4), id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature.displayName)
                            .font(.subheadline)
                    }
                }
            }
            
            // Action button
            Button(isCurrentPlan ? "Current Plan" : "Select Plan") {
                if !isCurrentPlan {
                    Task {
                        await action()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCurrentPlan)
            .frame(maxWidth: .infinity)
            .accessibilitySubscriptionButton(
                plan: plan.displayName,
                price: "$\(String(format: "%.2f", plan.price(for: interval)))"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentPlan ? .blue : .clear, lineWidth: 2)
                )
        )
    }
}

struct PaymentMethodCard: View {
    let paymentMethod: PaymentMethodDisplayModel
    let onSetDefault: () async -> Void
    let onDelete: () async -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Card icon
            Image(systemName: "creditcard.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            // Card details
            VStack(alignment: .leading, spacing: 4) {
                Text(paymentMethod.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Expires \(paymentMethod.expirationDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 8) {
                if paymentMethod.isDefault {
                    Text("DEFAULT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                } else {
                    Button("Set Default") {
                        Task {
                            await onSetDefault()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                
                Button("Remove") {
                    Task {
                        await onDelete()
                    }
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct InvoiceCard: View {
    let invoice: InvoiceDisplayModel
    let onDownload: () async -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Invoice icon
            Circle()
                .fill(invoice.statusColor)
                .frame(width: 12, height: 12)
            
            // Invoice details
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.displayDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(invoice.status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(invoice.displayAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Download button
            Button {
                Task {
                    await onDownload()
                }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct AddPaymentMethodView: View {
    let completion: (Bool) -> Void
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Add Payment Method")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Securely add a payment method for your subscription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Add Card") {
                    addPaymentMethod()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        completion(false)
                    }
                }
            }
        }
    }
    
    private func addPaymentMethod() {
        isLoading = true
        
        Task {
            do {
                try await SubscriptionViewModel().addPaymentMethod()
                await MainActor.run {
                    completion(true)
                }
            } catch {
                await MainActor.run {
                    completion(false)
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ApplePayButton: UIViewRepresentable {
    let type: PKPaymentButtonType
    let style: PKPaymentButtonStyle
    let action: () async -> Void
    
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator {
        let action: () async -> Void
        
        init(action: @escaping () async -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            Task {
                await action()
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal)
    }
}