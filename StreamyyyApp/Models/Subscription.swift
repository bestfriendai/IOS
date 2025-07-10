//
//  Subscription.swift
//  StreamyyyApp
//
//  Stripe-integrated subscription model
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Subscription Model
@Model
public class Subscription: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    @Attribute(.unique) public var stripeSubscriptionId: String?
    @Attribute(.unique) public var stripePriceId: String?
    public var stripeCustomerId: String?
    public var stripeInvoiceId: String?
    public var plan: SubscriptionPlan
    public var status: SubscriptionStatus
    public var billingInterval: BillingInterval
    public var amount: Double
    public var currency: String
    public var startDate: Date
    public var endDate: Date?
    public var currentPeriodStart: Date
    public var currentPeriodEnd: Date
    public var cancelAtPeriodEnd: Bool
    public var canceledAt: Date?
    public var cancelReason: String?
    public var trialStart: Date?
    public var trialEnd: Date?
    public var isTrialActive: Bool
    public var autoRenew: Bool
    public var paymentMethodId: String?
    public var lastPaymentDate: Date?
    public var nextPaymentDate: Date?
    public var failedPaymentCount: Int
    public var lastFailedPaymentDate: Date?
    public var discountCode: String?
    public var discountAmount: Double
    public var discountType: DiscountType
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    public var features: [SubscriptionFeature]
    public var usageStats: SubscriptionUsage
    
    // MARK: - Relationships
    @Relationship(inverse: \User.subscriptions)
    public var user: User?
    
    @Relationship(deleteRule: .cascade, inverse: \PaymentHistory.subscription)
    public var paymentHistory: [PaymentHistory] = []
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        plan: SubscriptionPlan,
        billingInterval: BillingInterval,
        user: User? = nil
    ) {
        self.id = id
        self.stripeSubscriptionId = nil
        self.stripePriceId = nil
        self.stripeCustomerId = nil
        self.stripeInvoiceId = nil
        self.plan = plan
        self.status = .active
        self.billingInterval = billingInterval
        self.amount = plan.price(for: billingInterval)
        self.currency = "USD"
        self.startDate = Date()
        self.endDate = nil
        self.currentPeriodStart = Date()
        self.currentPeriodEnd = Calendar.current.date(byAdding: billingInterval.dateComponent, value: 1, to: Date()) ?? Date()
        self.cancelAtPeriodEnd = false
        self.canceledAt = nil
        self.cancelReason = nil
        self.trialStart = nil
        self.trialEnd = nil
        self.isTrialActive = false
        self.autoRenew = true
        self.paymentMethodId = nil
        self.lastPaymentDate = nil
        self.nextPaymentDate = currentPeriodEnd
        self.failedPaymentCount = 0
        self.lastFailedPaymentDate = nil
        self.discountCode = nil
        self.discountAmount = 0.0
        self.discountType = .none
        self.metadata = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
        self.features = plan.features
        self.usageStats = SubscriptionUsage()
        self.user = user
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, stripeSubscriptionId, stripePriceId, stripeCustomerId, stripeInvoiceId
        case plan, status, billingInterval, amount, currency, startDate, endDate
        case currentPeriodStart, currentPeriodEnd, cancelAtPeriodEnd, canceledAt, cancelReason
        case trialStart, trialEnd, isTrialActive, autoRenew, paymentMethodId
        case lastPaymentDate, nextPaymentDate, failedPaymentCount, lastFailedPaymentDate
        case discountCode, discountAmount, discountType, metadata, createdAt, updatedAt
        case features, usageStats
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        stripeSubscriptionId = try container.decodeIfPresent(String.self, forKey: .stripeSubscriptionId)
        stripePriceId = try container.decodeIfPresent(String.self, forKey: .stripePriceId)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        stripeInvoiceId = try container.decodeIfPresent(String.self, forKey: .stripeInvoiceId)
        plan = try container.decode(SubscriptionPlan.self, forKey: .plan)
        status = try container.decode(SubscriptionStatus.self, forKey: .status)
        billingInterval = try container.decode(BillingInterval.self, forKey: .billingInterval)
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        currentPeriodStart = try container.decode(Date.self, forKey: .currentPeriodStart)
        currentPeriodEnd = try container.decode(Date.self, forKey: .currentPeriodEnd)
        cancelAtPeriodEnd = try container.decode(Bool.self, forKey: .cancelAtPeriodEnd)
        canceledAt = try container.decodeIfPresent(Date.self, forKey: .canceledAt)
        cancelReason = try container.decodeIfPresent(String.self, forKey: .cancelReason)
        trialStart = try container.decodeIfPresent(Date.self, forKey: .trialStart)
        trialEnd = try container.decodeIfPresent(Date.self, forKey: .trialEnd)
        isTrialActive = try container.decode(Bool.self, forKey: .isTrialActive)
        autoRenew = try container.decode(Bool.self, forKey: .autoRenew)
        paymentMethodId = try container.decodeIfPresent(String.self, forKey: .paymentMethodId)
        lastPaymentDate = try container.decodeIfPresent(Date.self, forKey: .lastPaymentDate)
        nextPaymentDate = try container.decodeIfPresent(Date.self, forKey: .nextPaymentDate)
        failedPaymentCount = try container.decode(Int.self, forKey: .failedPaymentCount)
        lastFailedPaymentDate = try container.decodeIfPresent(Date.self, forKey: .lastFailedPaymentDate)
        discountCode = try container.decodeIfPresent(String.self, forKey: .discountCode)
        discountAmount = try container.decode(Double.self, forKey: .discountAmount)
        discountType = try container.decode(DiscountType.self, forKey: .discountType)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        features = try container.decode([SubscriptionFeature].self, forKey: .features)
        usageStats = try container.decode(SubscriptionUsage.self, forKey: .usageStats)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(stripeSubscriptionId, forKey: .stripeSubscriptionId)
        try container.encodeIfPresent(stripePriceId, forKey: .stripePriceId)
        try container.encodeIfPresent(stripeCustomerId, forKey: .stripeCustomerId)
        try container.encodeIfPresent(stripeInvoiceId, forKey: .stripeInvoiceId)
        try container.encode(plan, forKey: .plan)
        try container.encode(status, forKey: .status)
        try container.encode(billingInterval, forKey: .billingInterval)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(currentPeriodStart, forKey: .currentPeriodStart)
        try container.encode(currentPeriodEnd, forKey: .currentPeriodEnd)
        try container.encode(cancelAtPeriodEnd, forKey: .cancelAtPeriodEnd)
        try container.encodeIfPresent(canceledAt, forKey: .canceledAt)
        try container.encodeIfPresent(cancelReason, forKey: .cancelReason)
        try container.encodeIfPresent(trialStart, forKey: .trialStart)
        try container.encodeIfPresent(trialEnd, forKey: .trialEnd)
        try container.encode(isTrialActive, forKey: .isTrialActive)
        try container.encode(autoRenew, forKey: .autoRenew)
        try container.encodeIfPresent(paymentMethodId, forKey: .paymentMethodId)
        try container.encodeIfPresent(lastPaymentDate, forKey: .lastPaymentDate)
        try container.encodeIfPresent(nextPaymentDate, forKey: .nextPaymentDate)
        try container.encode(failedPaymentCount, forKey: .failedPaymentCount)
        try container.encodeIfPresent(lastFailedPaymentDate, forKey: .lastFailedPaymentDate)
        try container.encodeIfPresent(discountCode, forKey: .discountCode)
        try container.encode(discountAmount, forKey: .discountAmount)
        try container.encode(discountType, forKey: .discountType)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(features, forKey: .features)
        try container.encode(usageStats, forKey: .usageStats)
    }
}

// MARK: - Subscription Extensions
extension Subscription {
    
    // MARK: - Computed Properties
    public var isActive: Bool {
        return status == .active && !isExpired
    }
    
    public var isExpired: Bool {
        return Date() > currentPeriodEnd
    }
    
    public var isPastDue: Bool {
        return status == .pastDue
    }
    
    public var isCanceled: Bool {
        return status == .canceled
    }
    
    public var willCancelAtPeriodEnd: Bool {
        return cancelAtPeriodEnd && !isCanceled
    }
    
    public var daysUntilRenewal: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: currentPeriodEnd)
        return components.day ?? 0
    }
    
    public var daysUntilTrialEnd: Int {
        guard let trialEnd = trialEnd else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: trialEnd)
        return max(0, components.day ?? 0)
    }
    
    public var effectiveAmount: Double {
        let discountedAmount = amount - discountAmount
        return max(0, discountedAmount)
    }
    
    public var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: effectiveAmount)) ?? "$0.00"
    }
    
    public var billingCycle: String {
        return billingInterval.displayName
    }
    
    public var statusColor: Color {
        switch status {
        case .active: return .green
        case .trialing: return .blue
        case .pastDue: return .orange
        case .canceled: return .red
        case .unpaid: return .red
        case .incomplete: return .yellow
        case .incompleteExpired: return .red
        case .paused: return .gray
        }
    }
    
    public var statusIcon: String {
        switch status {
        case .active: return "checkmark.circle.fill"
        case .trialing: return "clock.fill"
        case .pastDue: return "exclamationmark.triangle.fill"
        case .canceled: return "xmark.circle.fill"
        case .unpaid: return "creditcard.fill"
        case .incomplete: return "hourglass.fill"
        case .incompleteExpired: return "hourglass.fill"
        case .paused: return "pause.circle.fill"
        }
    }
    
    public var hasFeature: (SubscriptionFeature) -> Bool {
        return { feature in
            self.features.contains(feature)
        }
    }
    
    // MARK: - Update Methods
    public func updateStatus(_ newStatus: SubscriptionStatus) {
        status = newStatus
        updatedAt = Date()
        
        if newStatus == .canceled {
            canceledAt = Date()
            endDate = currentPeriodEnd
        }
    }
    
    public func updateFromStripe(_ stripeSubscription: [String: Any]) {
        if let stripeId = stripeSubscription["id"] as? String {
            stripeSubscriptionId = stripeId
        }
        
        if let stripeStatus = stripeSubscription["status"] as? String {
            status = SubscriptionStatus(rawValue: stripeStatus) ?? .active
        }
        
        if let currentPeriodStart = stripeSubscription["current_period_start"] as? TimeInterval {
            self.currentPeriodStart = Date(timeIntervalSince1970: currentPeriodStart)
        }
        
        if let currentPeriodEnd = stripeSubscription["current_period_end"] as? TimeInterval {
            self.currentPeriodEnd = Date(timeIntervalSince1970: currentPeriodEnd)
        }
        
        if let cancelAtPeriodEnd = stripeSubscription["cancel_at_period_end"] as? Bool {
            self.cancelAtPeriodEnd = cancelAtPeriodEnd
        }
        
        updatedAt = Date()
    }
    
    public func startTrial(days: Int) {
        let calendar = Calendar.current
        trialStart = Date()
        trialEnd = calendar.date(byAdding: .day, value: days, to: Date())
        isTrialActive = true
        status = .trialing
        updatedAt = Date()
    }
    
    public func endTrial() {
        isTrialActive = false
        trialEnd = Date()
        status = .active
        updatedAt = Date()
    }
    
    public func scheduleCancel(reason: String? = nil) {
        cancelAtPeriodEnd = true
        cancelReason = reason
        updatedAt = Date()
    }
    
    public func cancelImmediately(reason: String? = nil) {
        status = .canceled
        canceledAt = Date()
        cancelReason = reason
        endDate = Date()
        updatedAt = Date()
    }
    
    public func reactivate() {
        status = .active
        cancelAtPeriodEnd = false
        canceledAt = nil
        cancelReason = nil
        endDate = nil
        updatedAt = Date()
    }
    
    public func applyDiscount(code: String, amount: Double, type: DiscountType) {
        discountCode = code
        discountAmount = amount
        discountType = type
        updatedAt = Date()
    }
    
    public func removeDiscount() {
        discountCode = nil
        discountAmount = 0.0
        discountType = .none
        updatedAt = Date()
    }
    
    public func recordPayment(amount: Double, date: Date = Date()) {
        lastPaymentDate = date
        failedPaymentCount = 0
        lastFailedPaymentDate = nil
        
        // Calculate next payment date
        let calendar = Calendar.current
        nextPaymentDate = calendar.date(byAdding: billingInterval.dateComponent, value: 1, to: date)
        
        updatedAt = Date()
    }
    
    public func recordFailedPayment(date: Date = Date()) {
        failedPaymentCount += 1
        lastFailedPaymentDate = date
        
        if failedPaymentCount >= 3 {
            status = .pastDue
        }
        
        updatedAt = Date()
    }
    
    public func updateUsage(streamsUsed: Int, bandwidthUsed: Double) {
        usageStats.streamsUsed = streamsUsed
        usageStats.bandwidthUsed = bandwidthUsed
        usageStats.lastUpdated = Date()
        updatedAt = Date()
    }
}

// MARK: - Subscription Plan
public enum SubscriptionPlan: String, CaseIterable, Codable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"
    case pro = "pro"
    case enterprise = "enterprise"
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .premium: return "Premium"
        case .pro: return "Pro"
        case .enterprise: return "Enterprise"
        }
    }
    
    public var description: String {
        switch self {
        case .free: return "Basic streaming features"
        case .basic: return "Essential streaming tools"
        case .premium: return "Advanced streaming features"
        case .pro: return "Professional streaming suite"
        case .enterprise: return "Enterprise-grade solution"
        }
    }
    
    public func price(for interval: BillingInterval) -> Double {
        switch self {
        case .free:
            return 0.0
        case .basic:
            return interval == .monthly ? 4.99 : 49.99
        case .premium:
            return interval == .monthly ? 9.99 : 99.99
        case .pro:
            return interval == .monthly ? 19.99 : 199.99
        case .enterprise:
            return interval == .monthly ? 49.99 : 499.99
        }
    }
    
    public var features: [SubscriptionFeature] {
        switch self {
        case .free:
            return [.basicStreaming, .limitedStreams]
        case .basic:
            return [.basicStreaming, .moderateStreams, .basicSupport]
        case .premium:
            return [.basicStreaming, .premiumStreams, .advancedLayouts, .prioritySupport, .noAds]
        case .pro:
            return [.basicStreaming, .unlimitedStreams, .advancedLayouts, .prioritySupport, .noAds, .analytics, .customBranding]
        case .enterprise:
            return [.basicStreaming, .unlimitedStreams, .advancedLayouts, .prioritySupport, .noAds, .analytics, .customBranding, .apiAccess, .ssoIntegration]
        }
    }
    
    public var maxStreams: Int {
        switch self {
        case .free: return 4
        case .basic: return 8
        case .premium: return 16
        case .pro: return 50
        case .enterprise: return Int.max
        }
    }
    
    public var color: Color {
        switch self {
        case .free: return .gray
        case .basic: return .blue
        case .premium: return .purple
        case .pro: return .orange
        case .enterprise: return .green
        }
    }
    
    public var stripePriceId: String {
        switch self {
        case .free: return ""
        case .basic: return Config.Stripe.basicPlanId
        case .premium: return Config.Stripe.monthlyPlanId
        case .pro: return Config.Stripe.proPlanId
        case .enterprise: return Config.Stripe.enterprisePlanId
        }
    }
}

// MARK: - Billing Interval
public enum BillingInterval: String, CaseIterable, Codable {
    case monthly = "monthly"
    case yearly = "yearly"
    
    public var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    public var dateComponent: Calendar.Component {
        switch self {
        case .monthly: return .month
        case .yearly: return .year
        }
    }
    
    public var discountPercentage: Int {
        switch self {
        case .monthly: return 0
        case .yearly: return 17 // ~2 months free
        }
    }
}

// MARK: - Subscription Status
public enum SubscriptionStatus: String, CaseIterable, Codable {
    case active = "active"
    case trialing = "trialing"
    case pastDue = "past_due"
    case canceled = "canceled"
    case unpaid = "unpaid"
    case incomplete = "incomplete"
    case incompleteExpired = "incomplete_expired"
    case paused = "paused"
    
    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .trialing: return "Trial"
        case .pastDue: return "Past Due"
        case .canceled: return "Canceled"
        case .unpaid: return "Unpaid"
        case .incomplete: return "Incomplete"
        case .incompleteExpired: return "Expired"
        case .paused: return "Paused"
        }
    }
}

// MARK: - Subscription Feature
public enum SubscriptionFeature: String, CaseIterable, Codable {
    case basicStreaming = "basic_streaming"
    case limitedStreams = "limited_streams"
    case moderateStreams = "moderate_streams"
    case premiumStreams = "premium_streams"
    case unlimitedStreams = "unlimited_streams"
    case advancedLayouts = "advanced_layouts"
    case basicSupport = "basic_support"
    case prioritySupport = "priority_support"
    case noAds = "no_ads"
    case analytics = "analytics"
    case customBranding = "custom_branding"
    case apiAccess = "api_access"
    case ssoIntegration = "sso_integration"
    
    public var displayName: String {
        switch self {
        case .basicStreaming: return "Basic Streaming"
        case .limitedStreams: return "Limited Streams"
        case .moderateStreams: return "Moderate Streams"
        case .premiumStreams: return "Premium Streams"
        case .unlimitedStreams: return "Unlimited Streams"
        case .advancedLayouts: return "Advanced Layouts"
        case .basicSupport: return "Basic Support"
        case .prioritySupport: return "Priority Support"
        case .noAds: return "No Ads"
        case .analytics: return "Analytics"
        case .customBranding: return "Custom Branding"
        case .apiAccess: return "API Access"
        case .ssoIntegration: return "SSO Integration"
        }
    }
    
    public var description: String {
        switch self {
        case .basicStreaming: return "Stream from major platforms"
        case .limitedStreams: return "Up to 4 concurrent streams"
        case .moderateStreams: return "Up to 8 concurrent streams"
        case .premiumStreams: return "Up to 16 concurrent streams"
        case .unlimitedStreams: return "Unlimited concurrent streams"
        case .advancedLayouts: return "Custom layouts and arrangements"
        case .basicSupport: return "Email support"
        case .prioritySupport: return "Priority customer support"
        case .noAds: return "Ad-free experience"
        case .analytics: return "Detailed usage analytics"
        case .customBranding: return "Custom branding options"
        case .apiAccess: return "API access for integrations"
        case .ssoIntegration: return "Single sign-on integration"
        }
    }
    
    public var icon: String {
        switch self {
        case .basicStreaming: return "play.circle"
        case .limitedStreams: return "4.circle"
        case .moderateStreams: return "8.circle"
        case .premiumStreams: return "16.circle"
        case .unlimitedStreams: return "infinity.circle"
        case .advancedLayouts: return "grid.circle"
        case .basicSupport: return "envelope.circle"
        case .prioritySupport: return "star.circle"
        case .noAds: return "nosign"
        case .analytics: return "chart.bar.circle"
        case .customBranding: return "paintbrush.circle"
        case .apiAccess: return "gearshape.circle"
        case .ssoIntegration: return "key.circle"
        }
    }
}

// MARK: - Discount Type
public enum DiscountType: String, CaseIterable, Codable {
    case none = "none"
    case percentage = "percentage"
    case fixed = "fixed"
    case freeMonths = "free_months"
    
    public var displayName: String {
        switch self {
        case .none: return "No Discount"
        case .percentage: return "Percentage Off"
        case .fixed: return "Fixed Amount Off"
        case .freeMonths: return "Free Months"
        }
    }
}

// MARK: - Subscription Usage
public struct SubscriptionUsage: Codable {
    public var streamsUsed: Int
    public var bandwidthUsed: Double
    public var apiCallsUsed: Int
    public var storageUsed: Double
    public var lastUpdated: Date
    
    public init() {
        self.streamsUsed = 0
        self.bandwidthUsed = 0.0
        self.apiCallsUsed = 0
        self.storageUsed = 0.0
        self.lastUpdated = Date()
    }
    
    public var formattedBandwidth: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bandwidthUsed))
    }
    
    public var formattedStorage: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(storageUsed))
    }
}

// MARK: - Payment History
@Model
public class PaymentHistory: Identifiable, Codable {
    @Attribute(.unique) public var id: String
    public var stripePaymentIntentId: String?
    public var amount: Double
    public var currency: String
    public var status: PaymentStatus
    public var paymentMethod: String?
    public var paymentDate: Date
    public var failureReason: String?
    public var receiptURL: String?
    public var metadata: [String: String]
    
    @Relationship(inverse: \Subscription.paymentHistory)
    public var subscription: Subscription?
    
    public init(
        id: String = UUID().uuidString,
        amount: Double,
        currency: String = "USD",
        status: PaymentStatus = .succeeded,
        paymentMethod: String? = nil,
        subscription: Subscription? = nil
    ) {
        self.id = id
        self.stripePaymentIntentId = nil
        self.amount = amount
        self.currency = currency
        self.status = status
        self.paymentMethod = paymentMethod
        self.paymentDate = Date()
        self.failureReason = nil
        self.receiptURL = nil
        self.metadata = [:]
        self.subscription = subscription
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, stripePaymentIntentId, amount, currency, status, paymentMethod
        case paymentDate, failureReason, receiptURL, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stripePaymentIntentId = try container.decodeIfPresent(String.self, forKey: .stripePaymentIntentId)
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        status = try container.decode(PaymentStatus.self, forKey: .status)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        paymentDate = try container.decode(Date.self, forKey: .paymentDate)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        receiptURL = try container.decodeIfPresent(String.self, forKey: .receiptURL)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(stripePaymentIntentId, forKey: .stripePaymentIntentId)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
        try container.encode(paymentDate, forKey: .paymentDate)
        try container.encodeIfPresent(failureReason, forKey: .failureReason)
        try container.encodeIfPresent(receiptURL, forKey: .receiptURL)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - Payment Status
public enum PaymentStatus: String, CaseIterable, Codable {
    case succeeded = "succeeded"
    case pending = "pending"
    case failed = "failed"
    case canceled = "canceled"
    case refunded = "refunded"
    
    public var displayName: String {
        switch self {
        case .succeeded: return "Succeeded"
        case .pending: return "Pending"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        case .refunded: return "Refunded"
        }
    }
    
    public var color: Color {
        switch self {
        case .succeeded: return .green
        case .pending: return .orange
        case .failed: return .red
        case .canceled: return .gray
        case .refunded: return .blue
        }
    }
}

// MARK: - Subscription Errors
public enum SubscriptionError: Error, LocalizedError {
    case invalidPlan
    case paymentFailed
    case subscriptionNotFound
    case alreadySubscribed
    case cancellationFailed
    case trialExpired
    case upgradeRequired
    case downgradeNotAllowed
    case stripeError(String)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPlan:
            return "Invalid subscription plan"
        case .paymentFailed:
            return "Payment failed"
        case .subscriptionNotFound:
            return "Subscription not found"
        case .alreadySubscribed:
            return "Already subscribed"
        case .cancellationFailed:
            return "Cancellation failed"
        case .trialExpired:
            return "Trial expired"
        case .upgradeRequired:
            return "Upgrade required"
        case .downgradeNotAllowed:
            return "Downgrade not allowed"
        case .stripeError(let message):
            return "Stripe error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Config Extensions
extension Config.Stripe {
    static let basicPlanId = "streamyyy_basic_monthly"
    static let proPlanId = "streamyyy_pro_monthly"
    static let enterprisePlanId = "streamyyy_enterprise_monthly"
}