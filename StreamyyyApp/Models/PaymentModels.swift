//
//  PaymentModels.swift
//  StreamyyyApp
//
//  Supporting models and extensions for enhanced payment functionality
//

import Foundation
import SwiftUI

// MARK: - Payment Intent Model

struct PaymentIntent: Identifiable, Codable {
    let id: String
    let clientSecret: String
    let amount: Double
    let currency: String
    let status: PaymentIntentStatus
    let paymentMethodId: String?
    let customerId: String?
    let description: String?
    let receiptEmail: String?
    let metadata: [String: String]
    let createdAt: Date
    let updatedAt: Date
    
    enum PaymentIntentStatus: String, CaseIterable, Codable {
        case requiresPaymentMethod = "requires_payment_method"
        case requiresConfirmation = "requires_confirmation"
        case requiresAction = "requires_action"
        case processing = "processing"
        case requiresCapture = "requires_capture"
        case canceled = "canceled"
        case succeeded = "succeeded"
        
        var displayName: String {
            switch self {
            case .requiresPaymentMethod: return "Requires Payment Method"
            case .requiresConfirmation: return "Requires Confirmation"
            case .requiresAction: return "Requires Action"
            case .processing: return "Processing"
            case .requiresCapture: return "Requires Capture"
            case .canceled: return "Canceled"
            case .succeeded: return "Succeeded"
            }
        }
        
        var color: Color {
            switch self {
            case .requiresPaymentMethod: return .orange
            case .requiresConfirmation: return .blue
            case .requiresAction: return .blue
            case .processing: return .blue
            case .requiresCapture: return .yellow
            case .canceled: return .red
            case .succeeded: return .green
            }
        }
    }
}

// MARK: - Setup Intent Model

struct SetupIntent: Identifiable, Codable {
    let id: String
    let clientSecret: String
    let status: SetupIntentStatus
    let paymentMethodId: String?
    let customerId: String?
    let usage: String
    let metadata: [String: String]
    let createdAt: Date
    let updatedAt: Date
    
    enum SetupIntentStatus: String, CaseIterable, Codable {
        case requiresPaymentMethod = "requires_payment_method"
        case requiresConfirmation = "requires_confirmation"
        case requiresAction = "requires_action"
        case processing = "processing"
        case canceled = "canceled"
        case succeeded = "succeeded"
        
        var displayName: String {
            switch self {
            case .requiresPaymentMethod: return "Requires Payment Method"
            case .requiresConfirmation: return "Requires Confirmation"
            case .requiresAction: return "Requires Action"
            case .processing: return "Processing"
            case .canceled: return "Canceled"
            case .succeeded: return "Succeeded"
            }
        }
        
        var color: Color {
            switch self {
            case .requiresPaymentMethod: return .orange
            case .requiresConfirmation: return .blue
            case .requiresAction: return .blue
            case .processing: return .blue
            case .canceled: return .red
            case .succeeded: return .green
            }
        }
    }
}

// MARK: - Customer Model

struct Customer: Identifiable, Codable {
    let id: String
    let email: String
    let name: String?
    let phone: String?
    let description: String?
    let defaultPaymentMethodId: String?
    let invoicePrefix: String?
    let metadata: [String: String]
    let createdAt: Date
    let updatedAt: Date
    
    var displayName: String {
        return name ?? email
    }
}

// MARK: - Pricing Model

struct Price: Identifiable, Codable {
    let id: String
    let productId: String
    let amount: Double
    let currency: String
    let interval: PricingInterval?
    let intervalCount: Int?
    let trialPeriodDays: Int?
    let type: PriceType
    let nickname: String?
    let metadata: [String: String]
    let active: Bool
    let createdAt: Date
    
    enum PricingInterval: String, CaseIterable, Codable {
        case day = "day"
        case week = "week"
        case month = "month"
        case year = "year"
        
        var displayName: String {
            switch self {
            case .day: return "Daily"
            case .week: return "Weekly"
            case .month: return "Monthly"
            case .year: return "Yearly"
            }
        }
    }
    
    enum PriceType: String, CaseIterable, Codable {
        case oneTime = "one_time"
        case recurring = "recurring"
        
        var displayName: String {
            switch self {
            case .oneTime: return "One-time"
            case .recurring: return "Recurring"
            }
        }
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var billingDescription: String {
        guard let interval = interval else { return "One-time" }
        let intervalString = intervalCount == 1 ? interval.displayName : "\(intervalCount!) \(interval.rawValue)s"
        return "per \(intervalString)"
    }
}

// MARK: - Product Model

struct Product: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let images: [String]
    let metadata: [String: String]
    let active: Bool
    let prices: [Price]
    let createdAt: Date
    let updatedAt: Date
    
    var primaryImage: String? {
        return images.first
    }
    
    var monthlyPrice: Price? {
        return prices.first { $0.interval == .month && $0.intervalCount == 1 }
    }
    
    var yearlyPrice: Price? {
        return prices.first { $0.interval == .year && $0.intervalCount == 1 }
    }
}

// MARK: - Coupon Model

struct Coupon: Identifiable, Codable {
    let id: String
    let name: String?
    let percentOff: Double?
    let amountOff: Double?
    let currency: String?
    let duration: CouponDuration
    let durationInMonths: Int?
    let maxRedemptions: Int?
    let timesRedeemed: Int
    let valid: Bool
    let metadata: [String: String]
    let createdAt: Date
    let expiresAt: Date?
    
    enum CouponDuration: String, CaseIterable, Codable {
        case forever = "forever"
        case once = "once"
        case repeating = "repeating"
        
        var displayName: String {
            switch self {
            case .forever: return "Forever"
            case .once: return "One-time"
            case .repeating: return "Repeating"
            }
        }
    }
    
    var discountDescription: String {
        if let percentOff = percentOff {
            return "\(Int(percentOff))% off"
        } else if let amountOff = amountOff, let currency = currency {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            return formatter.string(from: NSNumber(value: amountOff)) ?? "$0.00 off"
        }
        return "Discount"
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var isExhausted: Bool {
        guard let maxRedemptions = maxRedemptions else { return false }
        return timesRedeemed >= maxRedemptions
    }
    
    var isValid: Bool {
        return valid && !isExpired && !isExhausted
    }
}

// MARK: - Webhook Event Model

struct WebhookEvent: Identifiable, Codable {
    let id: String
    let type: String
    let data: WebhookEventData
    let createdAt: Date
    let livemode: Bool
    let pendingWebhooks: Int
    let request: WebhookRequest?
    
    struct WebhookEventData: Codable {
        let object: [String: Any]
        let previousAttributes: [String: Any]?
        
        enum CodingKeys: String, CodingKey {
            case object
            case previousAttributes = "previous_attributes"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            object = try container.decode([String: Any].self, forKey: .object)
            previousAttributes = try container.decodeIfPresent([String: Any].self, forKey: .previousAttributes)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(object, forKey: .object)
            try container.encodeIfPresent(previousAttributes, forKey: .previousAttributes)
        }
    }
    
    struct WebhookRequest: Codable {
        let id: String
        let idempotencyKey: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case idempotencyKey = "idempotency_key"
        }
    }
}

// MARK: - Payment Analytics Model

struct PaymentAnalytics: Codable {
    let period: AnalyticsPeriod
    let totalRevenue: Double
    let totalTransactions: Int
    let successfulTransactions: Int
    let failedTransactions: Int
    let averageTransactionValue: Double
    let topPaymentMethods: [PaymentMethodAnalytics]
    let revenueByPlan: [PlanRevenue]
    let churnRate: Double
    let mrr: Double // Monthly Recurring Revenue
    let arpu: Double // Average Revenue Per User
    let ltv: Double // Customer Lifetime Value
    let updatedAt: Date
    
    enum AnalyticsPeriod: String, CaseIterable, Codable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }
    
    struct PaymentMethodAnalytics: Codable {
        let method: String
        let count: Int
        let percentage: Double
        let revenue: Double
    }
    
    struct PlanRevenue: Codable {
        let plan: String
        let revenue: Double
        let subscribers: Int
        let percentage: Double
    }
    
    var successRate: Double {
        guard totalTransactions > 0 else { return 0 }
        return Double(successfulTransactions) / Double(totalTransactions) * 100
    }
    
    var formattedTotalRevenue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalRevenue)) ?? "$0.00"
    }
    
    var formattedAverageTransactionValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: averageTransactionValue)) ?? "$0.00"
    }
    
    var formattedMRR: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: mrr)) ?? "$0.00"
    }
}

// MARK: - Tax Configuration Model

struct TaxConfiguration: Codable {
    let enabled: Bool
    let automaticTax: Bool
    let taxRates: [TaxRate]
    let defaultTaxBehavior: TaxBehavior
    let taxIdCollection: Bool
    
    enum TaxBehavior: String, CaseIterable, Codable {
        case inclusive = "inclusive"
        case exclusive = "exclusive"
        case unspecified = "unspecified"
        
        var displayName: String {
            switch self {
            case .inclusive: return "Tax Inclusive"
            case .exclusive: return "Tax Exclusive"
            case .unspecified: return "Unspecified"
            }
        }
    }
    
    struct TaxRate: Identifiable, Codable {
        let id: String
        let displayName: String
        let percentage: Double
        let jurisdiction: String
        let country: String
        let state: String?
        let inclusive: Bool
        let active: Bool
        
        var formattedPercentage: String {
            return String(format: "%.2f%%", percentage)
        }
    }
}

// MARK: - Subscription Schedule Model

struct SubscriptionSchedule: Identifiable, Codable {
    let id: String
    let subscriptionId: String?
    let customerId: String
    let status: ScheduleStatus
    let phases: [SchedulePhase]
    let currentPhase: SchedulePhase?
    let defaultSettings: ScheduleSettings
    let metadata: [String: String]
    let createdAt: Date
    let updatedAt: Date
    
    enum ScheduleStatus: String, CaseIterable, Codable {
        case notStarted = "not_started"
        case active = "active"
        case completed = "completed"
        case released = "released"
        case canceled = "canceled"
        
        var displayName: String {
            switch self {
            case .notStarted: return "Not Started"
            case .active: return "Active"
            case .completed: return "Completed"
            case .released: return "Released"
            case .canceled: return "Canceled"
            }
        }
        
        var color: Color {
            switch self {
            case .notStarted: return .gray
            case .active: return .green
            case .completed: return .blue
            case .released: return .orange
            case .canceled: return .red
            }
        }
    }
    
    struct SchedulePhase: Identifiable, Codable {
        let id: String
        let startDate: Date
        let endDate: Date?
        let priceId: String
        let quantity: Int
        let couponId: String?
        let trialEnd: Date?
        let metadata: [String: String]
        
        var duration: TimeInterval {
            guard let endDate = endDate else { return 0 }
            return endDate.timeIntervalSince(startDate)
        }
        
        var isActive: Bool {
            let now = Date()
            if let endDate = endDate {
                return now >= startDate && now <= endDate
            }
            return now >= startDate
        }
    }
    
    struct ScheduleSettings: Codable {
        let defaultPaymentMethod: String?
        let invoiceSettings: InvoiceSettings?
        
        struct InvoiceSettings: Codable {
            let daysUntilDue: Int?
            let defaultPaymentMethod: String?
        }
    }
}

// MARK: - Extensions

extension PaymentMethod {
    var isExpired: Bool {
        guard let expiryDate = expiryDate else { return false }
        return Date() > expiryDate
    }
    
    var expiryWarning: String? {
        guard let expiryDate = expiryDate else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        if expiryDate < now {
            return "Expired"
        }
        
        let components = calendar.dateComponents([.day], from: now, to: expiryDate)
        
        if let days = components.day {
            if days <= 30 {
                return "Expires in \(days) days"
            }
        }
        
        return nil
    }
}

extension Invoice {
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return status == .open && Date() > dueDate
    }
    
    var daysPastDue: Int {
        guard let dueDate = dueDate, isOverdue else { return 0 }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dueDate, to: Date())
        
        return components.day ?? 0
    }
}

extension SubscriptionPlan {
    var annualDiscount: Double {
        let monthlyTotal = price(for: .monthly) * 12
        let yearlyPrice = price(for: .yearly)
        
        guard monthlyTotal > 0 else { return 0 }
        
        return ((monthlyTotal - yearlyPrice) / monthlyTotal) * 100
    }
    
    var formattedAnnualDiscount: String {
        let discount = annualDiscount
        return String(format: "%.0f%%", discount)
    }
}

extension BillingInterval {
    var priceMultiplier: Double {
        switch self {
        case .monthly: return 1.0
        case .yearly: return 10.0 // 10 months price for yearly
        }
    }
}

// MARK: - Helper Functions

func formatCurrency(_ amount: Double, currency: String = "USD") -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
}

func formatPercentage(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
}

func calculateDiscountAmount(_ originalAmount: Double, discountPercentage: Double) -> Double {
    return originalAmount * (discountPercentage / 100)
}

func calculateFinalAmount(_ originalAmount: Double, discountPercentage: Double) -> Double {
    return originalAmount - calculateDiscountAmount(originalAmount, discountPercentage: discountPercentage)
}

// MARK: - Validation Helpers

extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    var isValidCurrency: Bool {
        let validCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY", "SEK", "NZD"]
        return validCurrencies.contains(self.uppercased())
    }
    
    var isValidPromoCode: Bool {
        let pattern = "^[A-Z0-9]{4,20}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
}