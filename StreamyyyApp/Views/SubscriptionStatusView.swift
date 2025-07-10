//
//  SubscriptionStatusView.swift
//  StreamyyyApp
//
//  Comprehensive subscription status view with billing info, trial details, and management options
//

import SwiftUI

struct SubscriptionStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.stripeManager) private var stripeManager
    
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingCancelConfirmation = false
    @State private var showingReactivateConfirmation = false
    @State private var showingChangePlan = false
    @State private var showingPaymentMethods = false
    @State private var showingBillingHistory = false
    @State private var refreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let subscription = subscriptionManager?.currentSubscription {
                            subscriptionHeaderCard(subscription)
                            statusCard(subscription)
                            billingCard(subscription)
                            featuresCard(subscription)
                            usageCard(subscription)
                            managementCard(subscription)
                        } else {
                            noSubscriptionView
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await refreshSubscription()
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await refreshSubscription()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .sheet(isPresented: $showingChangePlan) {
            SubscriptionPlansView()
        }
        .sheet(isPresented: $showingPaymentMethods) {
            PaymentMethodsView()
        }
        .sheet(isPresented: $showingBillingHistory) {
            BillingHistoryView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
            Button("Cancel Subscription", role: .destructive) {
                cancelSubscription()
            }
            Button("Keep Subscription", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel your subscription? You'll lose access to premium features at the end of your current billing period.")
        }
        .alert("Reactivate Subscription", isPresented: $showingReactivateConfirmation) {
            Button("Reactivate") {
                reactivateSubscription()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reactivate your subscription to continue enjoying premium features.")
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
    
    // MARK: - Subscription Header Card
    
    private func subscriptionHeaderCard(_ subscription: Subscription) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.plan.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(subscription.plan.color)
                    
                    Text(subscription.plan.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: subscription.statusIcon)
                            .foregroundColor(subscription.statusColor)
                        
                        Text(subscription.status.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(subscription.statusColor)
                    }
                    
                    Text(subscription.displayPrice)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            
            // Trial information
            if subscription.isTrialActive {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    
                    Text("Trial ends in \(subscription.daysUntilTrialEnd) days")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Cancellation notice
            if subscription.willCancelAtPeriodEnd {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Subscription will end on \(subscription.currentPeriodEnd, formatter: dateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Status Card
    
    private func statusCard(_ subscription: Subscription) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatusItem(
                    title: "Current Status",
                    value: subscription.status.displayName,
                    color: subscription.statusColor,
                    icon: subscription.statusIcon
                )
                
                StatusItem(
                    title: "Billing Cycle",
                    value: subscription.billingInterval.displayName,
                    color: .primary,
                    icon: "calendar"
                )
                
                StatusItem(
                    title: "Auto Renewal",
                    value: subscription.autoRenew ? "On" : "Off",
                    color: subscription.autoRenew ? .green : .red,
                    icon: subscription.autoRenew ? "checkmark.circle" : "xmark.circle"
                )
                
                StatusItem(
                    title: "Days Until Renewal",
                    value: "\(subscription.daysUntilRenewal)",
                    color: .primary,
                    icon: "calendar.badge.clock"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Billing Card
    
    private func billingCard(_ subscription: Subscription) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Billing Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                BillingRow(title: "Current Period", value: formatDateRange(subscription.currentPeriodStart, subscription.currentPeriodEnd))
                
                if let nextPaymentDate = subscription.nextPaymentDate {
                    BillingRow(title: "Next Payment", value: formatDate(nextPaymentDate))
                }
                
                BillingRow(title: "Amount", value: subscription.displayPrice)
                
                if subscription.discountAmount > 0 {
                    BillingRow(
                        title: "Discount Applied",
                        value: "-\(String(format: "%.2f", subscription.discountAmount))",
                        textColor: .green
                    )
                }
                
                BillingRow(title: "Currency", value: subscription.currency.uppercased())
                
                if let lastPaymentDate = subscription.lastPaymentDate {
                    BillingRow(title: "Last Payment", value: formatDate(lastPaymentDate))
                }
            }
            
            // Actions
            HStack(spacing: 16) {
                Button("Payment Methods") {
                    showingPaymentMethods = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Billing History") {
                    showingBillingHistory = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Features Card
    
    private func featuresCard(_ subscription: Subscription) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Features")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(subscription.features, id: \.self) { feature in
                    FeatureItem(feature: feature)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Usage Card
    
    private func usageCard(_ subscription: Subscription) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                UsageRow(
                    title: "Streams Used",
                    current: subscription.usageStats.streamsUsed,
                    limit: subscription.plan.maxStreams == Int.max ? nil : subscription.plan.maxStreams
                )
                
                UsageRow(
                    title: "Bandwidth Used",
                    value: subscription.usageStats.formattedBandwidth
                )
                
                UsageRow(
                    title: "API Calls",
                    current: subscription.usageStats.apiCallsUsed,
                    limit: nil
                )
                
                UsageRow(
                    title: "Storage Used",
                    value: subscription.usageStats.formattedStorage
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Management Card
    
    private func managementCard(_ subscription: Subscription) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Manage Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button("Change Plan") {
                    showingChangePlan = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                if subscription.willCancelAtPeriodEnd {
                    Button("Reactivate Subscription") {
                        showingReactivateConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Cancel Subscription") {
                        showingCancelConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - No Subscription View
    
    private var noSubscriptionView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "crown.circle")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            Text("No Active Subscription")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Subscribe to unlock premium features like unlimited streams, advanced layouts, and priority support")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("View Plans") {
                showingChangePlan = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Views
    
    private func StatusItem(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func BillingRow(title: String, value: String, textColor: Color = .primary) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(textColor)
        }
    }
    
    private func FeatureItem(feature: SubscriptionFeature) -> some View {
        HStack {
            Image(systemName: feature.icon)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(feature.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func UsageRow(title: String, current: Int? = nil, limit: Int? = nil, value: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let current = current, let limit = limit {
                Text("\(current) / \(limit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(current > limit * 8 / 10 ? .orange : .primary)
            } else if let current = current {
                Text("\(current)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else if let value = value {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    // MARK: - Actions
    
    private func refreshSubscription() async {
        refreshing = true
        await subscriptionManager?.refreshSubscription()
        refreshing = false
    }
    
    private func cancelSubscription() {
        Task {
            do {
                try await subscriptionManager?.cancelSubscription()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func reactivateSubscription() {
        Task {
            do {
                try await subscriptionManager?.reactivateSubscription()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionStatusView()
        .environment(\.subscriptionManager, nil)
        .environment(\.stripeManager, StripeManager.shared)
}