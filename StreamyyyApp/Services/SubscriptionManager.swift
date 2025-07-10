//
//  SubscriptionManager.swift
//  StreamyyyApp
//
//  Comprehensive subscription management service with Stripe integration
//

import Foundation
import SwiftUI
import Combine
import SwiftData
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var currentSubscription: Subscription?
    @Published var isSubscribed = false
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var isLoading = false
    @Published var error: Error?
    @Published var availablePlans: [SubscriptionPlan] = []
    @Published var paymentHistory: [PaymentHistory] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let stripeManager: StripeManager
    private let profileManager: ProfileManager
    private let modelContext: ModelContext
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    init(stripeManager: StripeManager, profileManager: ProfileManager, modelContext: ModelContext) {
        self.stripeManager = stripeManager
        self.profileManager = profileManager
        self.modelContext = modelContext
        
        setupSubscriptionObserver()
        loadAvailablePlans()
        loadCurrentSubscription()
    }
    
    // MARK: - Setup
    
    private func setupSubscriptionObserver() {
        profileManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                if let user = user {
                    self?.loadUserSubscription(for: user)
                } else {
                    self?.clearSubscriptionData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadAvailablePlans() {
        availablePlans = SubscriptionPlan.allCases.filter { $0 != .free }
    }
    
    // MARK: - Subscription Loading
    
    private func loadCurrentSubscription() {
        guard let user = profileManager.currentUser else { return }
        loadUserSubscription(for: user)
    }
    
    private func loadUserSubscription(for user: User) {
        isLoading = true
        
        Task {
            do {
                // Load active subscription from database
                let descriptor = FetchDescriptor<Subscription>(
                    predicate: #Predicate<Subscription> { 
                        $0.user?.id == user.id && $0.status == .active 
                    }
                )
                
                let subscriptions = try modelContext.fetch(descriptor)
                let activeSubscription = subscriptions.first
                
                // Update subscription status
                if let subscription = activeSubscription {
                    currentSubscription = subscription
                    isSubscribed = subscription.isActive
                    subscriptionStatus = subscription.status
                    
                    // Check if subscription needs renewal
                    if subscription.isExpired {
                        await handleExpiredSubscription(subscription)
                    }
                } else {
                    // Check for any subscription in other statuses
                    let allSubscriptionsDescriptor = FetchDescriptor<Subscription>(
                        predicate: #Predicate<Subscription> { $0.user?.id == user.id }
                    )
                    let allSubscriptions = try modelContext.fetch(allSubscriptionsDescriptor)
                    
                    if let latestSubscription = allSubscriptions.sorted(by: { $0.createdAt > $1.createdAt }).first {
                        currentSubscription = latestSubscription
                        isSubscribed = latestSubscription.isActive
                        subscriptionStatus = latestSubscription.status
                    } else {
                        // No subscription found, user is on free plan
                        isSubscribed = false
                        subscriptionStatus = .free
                        currentSubscription = nil
                    }
                }
                
                // Load payment history
                await loadPaymentHistory(for: user)
                
                isLoading = false
                
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    private func loadPaymentHistory(for user: User) async {
        guard let subscription = currentSubscription else { return }
        
        do {
            let descriptor = FetchDescriptor<PaymentHistory>(
                predicate: #Predicate<PaymentHistory> { 
                    $0.subscription?.id == subscription.id 
                },
                sortBy: [SortDescriptor(\.paymentDate, order: .reverse)]
            )
            
            paymentHistory = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load payment history: \(error)")
        }
    }
    
    // MARK: - Subscription Management
    
    func subscribe(to plan: SubscriptionPlan, billingInterval: BillingInterval = .monthly) async throws {
        guard let user = profileManager.currentUser else {
            throw SubscriptionError.userNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            // Create subscription through Stripe
            let stripeResult = try await stripeManager.createSubscription(
                for: user,
                plan: plan,
                billingInterval: billingInterval
            )
            
            // Create local subscription record
            let subscription = Subscription(
                id: stripeResult.subscriptionId,
                plan: plan,
                billingInterval: billingInterval,
                user: user
            )
            
            subscription.stripeSubscriptionId = stripeResult.subscriptionId
            subscription.stripeCustomerId = stripeResult.customerId
            subscription.stripePriceId = stripeResult.priceId
            subscription.status = .active
            subscription.startTrial(days: 7) // 7-day trial
            
            // Save to database
            modelContext.insert(subscription)
            try modelContext.save()
            
            // Update user subscription status
            user.updateSubscriptionStatus(plan == .basic ? .premium : .pro)
            user.subscriptionId = subscription.id
            user.stripeCustomerId = stripeResult.customerId
            
            // Update current state
            currentSubscription = subscription
            isSubscribed = true
            subscriptionStatus = subscription.status
            
            // Record initial payment
            let payment = PaymentHistory(
                amount: subscription.effectiveAmount,
                currency: subscription.currency,
                status: .succeeded,
                subscription: subscription
            )
            payment.stripePaymentIntentId = stripeResult.paymentIntentId
            
            modelContext.insert(payment)
            try modelContext.save()
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func cancelSubscription(reason: String? = nil) async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            // Cancel through Stripe
            try await stripeManager.cancelSubscription(subscription.stripeSubscriptionId!)
            
            // Update local subscription
            subscription.scheduleCancel(reason: reason)
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func reactivateSubscription() async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            // Reactivate through Stripe
            try await stripeManager.reactivateSubscription(subscription.stripeSubscriptionId!)
            
            // Update local subscription
            subscription.reactivate()
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            isSubscribed = true
            subscriptionStatus = subscription.status
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func changePlan(to newPlan: SubscriptionPlan) async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            // Update through Stripe
            try await stripeManager.updateSubscription(
                subscription.stripeSubscriptionId!,
                toPlan: newPlan
            )
            
            // Update local subscription
            subscription.plan = newPlan
            subscription.amount = newPlan.price(for: subscription.billingInterval)
            subscription.features = newPlan.features
            subscription.updatedAt = Date()
            
            try modelContext.save()
            
            // Update user subscription status
            if let user = profileManager.currentUser {
                user.updateSubscriptionStatus(newPlan == .basic ? .premium : .pro)
            }
            
            // Update current state
            currentSubscription = subscription
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Subscription Status Handling
    
    private func handleExpiredSubscription(_ subscription: Subscription) async {
        subscription.updateStatus(.canceled)
        
        // Update user status
        if let user = profileManager.currentUser {
            user.updateSubscriptionStatus(.free)
        }
        
        try? modelContext.save()
        
        // Update current state
        isSubscribed = false
        subscriptionStatus = .canceled
    }
    
    func checkSubscriptionStatus() async {
        guard let subscription = currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else {
            return
        }
        
        do {
            let stripeStatus = try await stripeManager.getSubscriptionStatus(stripeSubscriptionId)
            
            // Update local subscription with Stripe data
            subscription.updateFromStripe(stripeStatus)
            try modelContext.save()
            
            // Update current state
            isSubscribed = subscription.isActive
            subscriptionStatus = subscription.status
            
        } catch {
            print("Failed to check subscription status: \(error)")
        }
    }
    
    // MARK: - Payment Methods
    
    func updatePaymentMethod() async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        try await stripeManager.updatePaymentMethod(for: subscription.stripeCustomerId!)
    }
    
    func processPayment(for subscription: Subscription) async throws {
        do {
            try await stripeManager.processPayment(
                amount: subscription.effectiveAmount,
                customerId: subscription.stripeCustomerId!
            )
            
            // Record successful payment
            subscription.recordPayment(amount: subscription.effectiveAmount)
            
            let payment = PaymentHistory(
                amount: subscription.effectiveAmount,
                currency: subscription.currency,
                status: .succeeded,
                subscription: subscription
            )
            
            modelContext.insert(payment)
            try modelContext.save()
            
        } catch {
            // Record failed payment
            subscription.recordFailedPayment()
            
            let payment = PaymentHistory(
                amount: subscription.effectiveAmount,
                currency: subscription.currency,
                status: .failed,
                subscription: subscription
            )
            payment.failureReason = error.localizedDescription
            
            modelContext.insert(payment)
            try modelContext.save()
            
            throw error
        }
    }
    
    // MARK: - Promo Codes and Discounts
    
    func validatePromoCode(_ code: String) async throws -> Double {
        guard !code.isEmpty else {
            throw SubscriptionError.invalidPromoCode
        }
        
        do {
            let discount = try await stripeManager.validatePromoCode(code)
            return discount
        } catch {
            throw SubscriptionError.invalidPromoCode
        }
    }
    
    func applyPromoCode(_ code: String, to subscriptionId: String) async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        do {
            let discount = try await stripeManager.applyPromoCode(code, to: subscriptionId)
            
            // Update local subscription
            subscription.applyDiscount(code: code, amount: discount, type: .percentage)
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            
        } catch {
            throw SubscriptionError.promoCodeApplicationFailed
        }
    }
    
    func removePromoCode() async throws {
        guard let subscription = currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        do {
            try await stripeManager.removePromoCode(from: stripeSubscriptionId)
            
            // Update local subscription
            subscription.removeDiscount()
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            
        } catch {
            throw SubscriptionError.promoCodeRemovalFailed
        }
    }
    
    // MARK: - Usage Tracking
    
    func updateUsage(streams: Int, bandwidth: Double) async {
        guard let subscription = currentSubscription else { return }
        
        subscription.updateUsage(streamsUsed: streams, bandwidthUsed: bandwidth)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update usage: \(error)")
        }
    }
    
    func checkUsageLimits() -> UsageLimitResult {
        guard let subscription = currentSubscription else {
            return .noSubscription
        }
        
        let maxStreams = subscription.plan.maxStreams
        let currentStreams = subscription.usageStats.streamsUsed
        
        if maxStreams != Int.max && currentStreams >= maxStreams {
            return .streamLimitExceeded
        }
        
        if currentStreams >= maxStreams * 8 / 10 {
            return .streamLimitWarning
        }
        
        return .withinLimits
    }
    
    // MARK: - Subscription Health
    
    func checkSubscriptionHealth() async -> SubscriptionHealthStatus {
        guard let subscription = currentSubscription else {
            return .noSubscription
        }
        
        // Check if subscription is active
        if !subscription.isActive {
            return .inactive
        }
        
        // Check if subscription is expiring soon
        if subscription.daysUntilRenewal <= 3 {
            return .expiringSoon
        }
        
        // Check for payment failures
        if subscription.failedPaymentCount > 0 {
            return .paymentIssues
        }
        
        // Check usage limits
        let usageResult = checkUsageLimits()
        if usageResult == .streamLimitExceeded {
            return .usageLimitExceeded
        }
        
        return .healthy
    }
    
    // MARK: - Advanced Subscription Management
    
    func pauseSubscription() async throws {
        guard let subscription = currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            try await stripeManager.pauseSubscription(stripeSubscriptionId)
            
            // Update local subscription
            subscription.updateStatus(.paused)
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            isSubscribed = false
            subscriptionStatus = .paused
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func resumeSubscription() async throws {
        guard let subscription = currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            try await stripeManager.resumeSubscription(stripeSubscriptionId)
            
            // Update local subscription
            subscription.updateStatus(.active)
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            isSubscribed = true
            subscriptionStatus = .active
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func updateBillingInterval(to interval: BillingInterval) async throws {
        guard let subscription = currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        error = nil
        
        do {
            try await stripeManager.updateBillingInterval(stripeSubscriptionId, to: interval)
            
            // Update local subscription
            subscription.billingInterval = interval
            subscription.amount = subscription.plan.price(for: interval)
            subscription.updatedAt = Date()
            
            try modelContext.save()
            
            // Update current state
            currentSubscription = subscription
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Webhook Handling
    
    func handleWebhookEvent(_ event: [String: Any]) async {
        guard let type = event["type"] as? String else { return }
        
        switch type {
        case "invoice.payment_succeeded":
            await handleInvoicePaymentSucceeded(event)
        case "invoice.payment_failed":
            await handleInvoicePaymentFailed(event)
        case "customer.subscription.updated":
            await handleSubscriptionUpdated(event)
        case "customer.subscription.deleted":
            await handleSubscriptionDeleted(event)
        default:
            break
        }
    }
    
    private func handleInvoicePaymentSucceeded(_ event: [String: Any]) async {
        guard let subscription = currentSubscription,
              let data = event["data"] as? [String: Any],
              let object = data["object"] as? [String: Any],
              let amount = object["amount_paid"] as? Double else {
            return
        }
        
        subscription.recordPayment(amount: amount / 100) // Convert from cents
        
        let payment = PaymentHistory(
            amount: amount / 100,
            currency: subscription.currency,
            status: .succeeded,
            subscription: subscription
        )
        
        modelContext.insert(payment)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save payment history: \(error)")
        }
    }
    
    private func handleInvoicePaymentFailed(_ event: [String: Any]) async {
        guard let subscription = currentSubscription else { return }
        
        subscription.recordFailedPayment()
        
        let payment = PaymentHistory(
            amount: subscription.amount,
            currency: subscription.currency,
            status: .failed,
            subscription: subscription
        )
        
        modelContext.insert(payment)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save payment history: \(error)")
        }
    }
    
    private func handleSubscriptionUpdated(_ event: [String: Any]) async {
        guard let subscription = currentSubscription,
              let data = event["data"] as? [String: Any],
              let object = data["object"] as? [String: Any] else {
            return
        }
        
        subscription.updateFromStripe(object)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update subscription: \(error)")
        }
        
        // Update current state
        isSubscribed = subscription.isActive
        subscriptionStatus = subscription.status
    }
    
    private func handleSubscriptionDeleted(_ event: [String: Any]) async {
        guard let subscription = currentSubscription else { return }
        
        subscription.updateStatus(.canceled)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update subscription: \(error)")
        }
        
        // Update current state
        isSubscribed = false
        subscriptionStatus = .canceled
    }
    
    // MARK: - Utility Methods
    
    private func clearSubscriptionData() {
        currentSubscription = nil
        isSubscribed = false
        subscriptionStatus = .free
        paymentHistory = []
    }
    
    func refreshSubscription() async {
        await loadCurrentSubscription()
        await checkSubscriptionStatus()
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Computed Properties
    
    var canAddMoreStreams: Bool {
        guard let user = profileManager.currentUser else { return false }
        return user.canAddMoreStreams
    }
    
    var maxStreams: Int {
        return profileManager.currentUser?.maxStreams ?? Config.App.maxStreamsForFreeUsers
    }
    
    var currentPlan: SubscriptionPlan {
        return currentSubscription?.plan ?? .free
    }
    
    var nextBillingDate: Date? {
        return currentSubscription?.nextPaymentDate
    }
    
    var trialDaysRemaining: Int {
        return currentSubscription?.daysUntilTrialEnd ?? 0
    }
    
    var isInTrial: Bool {
        return currentSubscription?.isTrialActive ?? false
    }
    
    var monthlyPrice: Double {
        return currentPlan.price(for: .monthly)
    }
    
    var yearlyPrice: Double {
        return currentPlan.price(for: .yearly)
    }
    
    var hasPaymentMethod: Bool {
        return currentSubscription?.paymentMethodId != nil
    }
    
    var subscriptionDisplayName: String {
        return currentPlan.displayName
    }
    
    var subscriptionDescription: String {
        return currentPlan.description
    }
    
    var subscriptionColor: Color {
        return currentPlan.color
    }
    
    var formattedNextBillingDate: String {
        guard let nextBillingDate = nextBillingDate else { return "N/A" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: nextBillingDate)
    }
    
    var formattedSubscriptionPrice: String {
        guard let subscription = currentSubscription else { return "$0.00" }
        return subscription.displayPrice
    }
    
    var subscriptionHealth: SubscriptionHealthStatus {
        guard let subscription = currentSubscription else { return .noSubscription }
        
        if !subscription.isActive {
            return .inactive
        }
        
        if subscription.daysUntilRenewal <= 3 {
            return .expiringSoon
        }
        
        if subscription.failedPaymentCount > 0 {
            return .paymentIssues
        }
        
        let usageResult = checkUsageLimits()
        if usageResult == .streamLimitExceeded {
            return .usageLimitExceeded
        }
        
        return .healthy
    }
    
    var canPauseSubscription: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.isActive && !subscription.isTrialActive
    }
    
    var canResumeSubscription: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.status == .paused
    }
    
    var canChangeBillingInterval: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.isActive && !subscription.willCancelAtPeriodEnd
    }
    
    var hasActiveDiscount: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.discountAmount > 0
    }
    
    var discountDescription: String? {
        guard let subscription = currentSubscription,
              subscription.discountAmount > 0,
              let discountCode = subscription.discountCode else {
            return nil
        }
        
        return "\(discountCode): \(Int(subscription.discountAmount))% off"
    }
}

// MARK: - Stripe Manager Extension

extension SubscriptionManager {
    struct StripeResult {
        let subscriptionId: String
        let customerId: String
        let priceId: String
        let paymentIntentId: String?
    }
    
    // MARK: - Notification Methods
    
    func scheduleTrialExpirationNotification() {
        guard let subscription = currentSubscription,
              subscription.isTrialActive,
              let trialEnd = subscription.trialEnd else {
            return
        }
        
        let notificationManager = NotificationManager.shared
        
        // Schedule notification 24 hours before trial ends
        let notificationDate = Calendar.current.date(byAdding: .hour, value: -24, to: trialEnd)
        
        if let notificationDate = notificationDate, notificationDate > Date() {
            notificationManager.scheduleNotification(
                id: "trial_expiration_warning",
                title: "Trial Expiring Soon",
                body: "Your free trial expires in 24 hours. Subscribe to continue enjoying premium features.",
                date: notificationDate
            )
        }
    }
    
    func scheduleRenewalNotification() {
        guard let subscription = currentSubscription,
              let nextPaymentDate = subscription.nextPaymentDate else {
            return
        }
        
        let notificationManager = NotificationManager.shared
        
        // Schedule notification 3 days before renewal
        let notificationDate = Calendar.current.date(byAdding: .day, value: -3, to: nextPaymentDate)
        
        if let notificationDate = notificationDate, notificationDate > Date() {
            notificationManager.scheduleNotification(
                id: "subscription_renewal_reminder",
                title: "Subscription Renewal",
                body: "Your subscription will renew on \(DateFormatter.localizedString(from: nextPaymentDate, dateStyle: .medium, timeStyle: .none)).",
                date: notificationDate
            )
        }
    }
    
    func cancelScheduledNotifications() {
        let notificationManager = NotificationManager.shared
        notificationManager.cancelNotification(id: "trial_expiration_warning")
        notificationManager.cancelNotification(id: "subscription_renewal_reminder")
    }
    
    // MARK: - Analytics Methods
    
    func trackSubscriptionEvent(_ event: String, metadata: [String: Any] = [:]) {
        var eventMetadata = metadata
        eventMetadata["subscription_plan"] = currentPlan.rawValue
        eventMetadata["subscription_status"] = subscriptionStatus.rawValue
        eventMetadata["is_trial_active"] = isInTrial
        
        AnalyticsManager.shared.track(event: event, properties: eventMetadata)
    }
    
    func trackSubscriptionStart() {
        guard let subscription = currentSubscription else { return }
        
        trackSubscriptionEvent("subscription_started", metadata: [
            "plan": subscription.plan.rawValue,
            "billing_interval": subscription.billingInterval.rawValue,
            "amount": subscription.amount,
            "currency": subscription.currency,
            "is_trial": subscription.isTrialActive
        ])
    }
    
    func trackSubscriptionCancellation() {
        guard let subscription = currentSubscription else { return }
        
        trackSubscriptionEvent("subscription_cancelled", metadata: [
            "plan": subscription.plan.rawValue,
            "reason": subscription.cancelReason ?? "unknown",
            "days_active": Calendar.current.dateComponents([.day], from: subscription.startDate, to: Date()).day ?? 0
        ])
    }
    
    func trackPlanChange(from oldPlan: SubscriptionPlan, to newPlan: SubscriptionPlan) {
        trackSubscriptionEvent("plan_changed", metadata: [
            "old_plan": oldPlan.rawValue,
            "new_plan": newPlan.rawValue,
            "change_type": newPlan.rawValue.compare(oldPlan.rawValue) == .orderedDescending ? "upgrade" : "downgrade"
        ])
    }
}

// MARK: - Supporting Enums

enum UsageLimitResult {
    case withinLimits
    case streamLimitWarning
    case streamLimitExceeded
    case noSubscription
}

enum SubscriptionHealthStatus {
    case healthy
    case expiringSoon
    case paymentIssues
    case usageLimitExceeded
    case inactive
    case noSubscription
    
    var displayName: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .expiringSoon:
            return "Expiring Soon"
        case .paymentIssues:
            return "Payment Issues"
        case .usageLimitExceeded:
            return "Usage Limit Exceeded"
        case .inactive:
            return "Inactive"
        case .noSubscription:
            return "No Subscription"
        }
    }
    
    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .expiringSoon:
            return .orange
        case .paymentIssues:
            return .red
        case .usageLimitExceeded:
            return .red
        case .inactive:
            return .gray
        case .noSubscription:
            return .gray
        }
    }
}

// MARK: - Subscription Errors

enum SubscriptionError: Error, LocalizedError {
    case userNotFound
    case subscriptionNotFound
    case alreadySubscribed
    case paymentFailed
    case stripeError(String)
    case unknown(Error)
    case invalidPromoCode
    case promoCodeApplicationFailed
    case promoCodeRemovalFailed
    case subscriptionPauseFailed
    case subscriptionResumeFailed
    case billingIntervalUpdateFailed
    case usageLimitExceeded
    case trialExpired
    case subscriptionExpired
    case paymentMethodRequired
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .subscriptionNotFound:
            return "Subscription not found"
        case .alreadySubscribed:
            return "Already subscribed"
        case .paymentFailed:
            return "Payment failed"
        case .stripeError(let message):
            return "Payment error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        case .invalidPromoCode:
            return "Invalid promo code"
        case .promoCodeApplicationFailed:
            return "Failed to apply promo code"
        case .promoCodeRemovalFailed:
            return "Failed to remove promo code"
        case .subscriptionPauseFailed:
            return "Failed to pause subscription"
        case .subscriptionResumeFailed:
            return "Failed to resume subscription"
        case .billingIntervalUpdateFailed:
            return "Failed to update billing interval"
        case .usageLimitExceeded:
            return "Usage limit exceeded"
        case .trialExpired:
            return "Trial period has expired"
        case .subscriptionExpired:
            return "Subscription has expired"
        case .paymentMethodRequired:
            return "Payment method required"
        case .insufficientPermissions:
            return "Insufficient permissions"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .paymentFailed:
            return "Please check your payment method and try again"
        case .invalidPromoCode:
            return "Please check the promo code and try again"
        case .usageLimitExceeded:
            return "Please upgrade your plan to increase limits"
        case .trialExpired:
            return "Please subscribe to continue using premium features"
        case .subscriptionExpired:
            return "Please renew your subscription to continue"
        case .paymentMethodRequired:
            return "Please add a payment method to continue"
        default:
            return nil
        }
    }
}

// MARK: - Environment Key

struct SubscriptionManagerKey: EnvironmentKey {
    static let defaultValue: SubscriptionManager? = nil
    
    // MARK: - Shared Instance for Testing
    static func createShared(stripeManager: StripeManager, profileManager: ProfileManager, modelContext: ModelContext) -> SubscriptionManager {
        return SubscriptionManager(stripeManager: stripeManager, profileManager: profileManager, modelContext: modelContext)
    }
}

extension EnvironmentValues {
    var subscriptionManager: SubscriptionManager? {
        get { self[SubscriptionManagerKey.self] }
        set { self[SubscriptionManagerKey.self] = newValue }
    }
}