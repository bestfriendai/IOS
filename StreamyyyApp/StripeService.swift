//
//  StripeService.swift
//  StreamyyyApp
//
//  Complete Stripe payment integration service
//  Handles subscriptions, payments, customers, and Apple Pay
//

import Foundation
import Stripe
import StripePaymentSheet
import StripeApplePay
import PassKit
import SwiftUI
import Combine

// MARK: - Stripe Service
@MainActor
public class StripeService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isLoading = false
    @Published public var error: StripeServiceError?
    @Published public var paymentSheet: PaymentSheet?
    @Published public var setupIntentSheet: PaymentSheet?
    @Published public var paymentResult: PaymentSheetResult?
    @Published public var currentSubscription: StripeSubscription?
    @Published public var customer: StripeCustomer?
    @Published public var paymentMethods: [StripePaymentMethod] = []
    @Published public var invoices: [StripeInvoice] = []
    @Published public var subscriptionStatus: SubscriptionStatus = .canceled
    @Published public var isApplePayAvailable = false
    
    // MARK: - Private Properties
    private let networking = StripeNetworking()
    private var cancellables = Set<AnyCancellable>()
    private var webhookEndpoint: String?
    private var ephemeralKey: String?
    private var customerId: String?
    
    // MARK: - Singleton
    public static let shared = StripeService()
    
    // MARK: - Initialization
    override init() {
        super.init()
        configure()
        setupObservers()
    }
    
    // MARK: - Configuration
    private func configure() {
        // Configure Stripe
        StripeAPI.defaultPublishableKey = Config.Stripe.publishableKey
        StripeAPI.defaultMerchantIdentifier = Config.Stripe.merchantIdentifier
        
        // Check Apple Pay availability
        checkApplePayAvailability()
    }
    
    private func setupObservers() {
        // Monitor network changes
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] _ in
                self?.handleNetworkChange()
            }
            .store(in: &cancellables)
        
        // Monitor subscription changes
        NotificationCenter.default.publisher(for: .subscriptionStatusChanged)
            .sink { [weak self] notification in
                if let status = notification.object as? SubscriptionStatus {
                    self?.subscriptionStatus = status
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Customer Management
    public func createCustomer(email: String, name: String, metadata: [String: String] = [:]) async throws -> StripeCustomer {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let customer = try await networking.createCustomer(
                email: email,
                name: name,
                metadata: metadata
            )
            
            self.customer = customer
            self.customerId = customer.id
            
            // Create ephemeral key for the customer
            ephemeralKey = try await networking.createEphemeralKey(customerId: customer.id)
            
            return customer
        } catch {
            let stripeError = StripeServiceError.customerCreationFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func retrieveCustomer(customerId: String) async throws -> StripeCustomer {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let customer = try await networking.retrieveCustomer(customerId: customerId)
            self.customer = customer
            self.customerId = customer.id
            
            // Refresh ephemeral key
            ephemeralKey = try await networking.createEphemeralKey(customerId: customer.id)
            
            return customer
        } catch {
            let stripeError = StripeServiceError.customerRetrievalFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func updateCustomer(customerId: String, email: String?, name: String?, metadata: [String: String]? = nil) async throws -> StripeCustomer {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let customer = try await networking.updateCustomer(
                customerId: customerId,
                email: email,
                name: name,
                metadata: metadata
            )
            
            self.customer = customer
            return customer
        } catch {
            let stripeError = StripeServiceError.customerUpdateFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    // MARK: - Subscription Management
    public func createSubscription(
        customerId: String,
        priceId: String,
        paymentMethodId: String? = nil,
        trialDays: Int? = nil,
        metadata: [String: String] = [:]
    ) async throws -> StripeSubscription {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let subscription = try await networking.createSubscription(
                customerId: customerId,
                priceId: priceId,
                paymentMethodId: paymentMethodId,
                trialDays: trialDays,
                metadata: metadata
            )
            
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .active
            
            // Post notification
            NotificationCenter.default.post(
                name: .subscriptionCreated,
                object: subscription
            )
            
            return subscription
        } catch {
            let stripeError = StripeServiceError.subscriptionCreationFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func retrieveSubscription(subscriptionId: String) async throws -> StripeSubscription {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let subscription = try await networking.retrieveSubscription(subscriptionId: subscriptionId)
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .active
            
            return subscription
        } catch {
            let stripeError = StripeServiceError.subscriptionRetrievalFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func updateSubscription(
        subscriptionId: String,
        priceId: String,
        prorationBehavior: ProrationBehavior = .createProrations
    ) async throws -> StripeSubscription {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let subscription = try await networking.updateSubscription(
                subscriptionId: subscriptionId,
                priceId: priceId,
                prorationBehavior: prorationBehavior
            )
            
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .active
            
            // Post notification
            NotificationCenter.default.post(
                name: .subscriptionUpdated,
                object: subscription
            )
            
            return subscription
        } catch {
            let stripeError = StripeServiceError.subscriptionUpdateFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func cancelSubscription(
        subscriptionId: String,
        immediately: Bool = false,
        cancelReason: String? = nil
    ) async throws -> StripeSubscription {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let subscription = try await networking.cancelSubscription(
                subscriptionId: subscriptionId,
                immediately: immediately,
                cancelReason: cancelReason
            )
            
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .canceled
            
            // Post notification
            NotificationCenter.default.post(
                name: .subscriptionCanceled,
                object: subscription
            )
            
            return subscription
        } catch {
            let stripeError = StripeServiceError.subscriptionCancellationFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func reactivateSubscription(subscriptionId: String) async throws -> StripeSubscription {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let subscription = try await networking.reactivateSubscription(subscriptionId: subscriptionId)
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .active
            
            // Post notification
            NotificationCenter.default.post(
                name: .subscriptionReactivated,
                object: subscription
            )
            
            return subscription
        } catch {
            let stripeError = StripeServiceError.subscriptionReactivationFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    // MARK: - Payment Methods
    public func attachPaymentMethod(paymentMethodId: String, customerId: String) async throws -> StripePaymentMethod {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let paymentMethod = try await networking.attachPaymentMethod(
                paymentMethodId: paymentMethodId,
                customerId: customerId
            )
            
            await refreshPaymentMethods(customerId: customerId)
            return paymentMethod
        } catch {
            let stripeError = StripeServiceError.paymentMethodAttachmentFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func detachPaymentMethod(paymentMethodId: String) async throws -> StripePaymentMethod {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let paymentMethod = try await networking.detachPaymentMethod(paymentMethodId: paymentMethodId)
            
            if let customerId = self.customerId {
                await refreshPaymentMethods(customerId: customerId)
            }
            
            return paymentMethod
        } catch {
            let stripeError = StripeServiceError.paymentMethodDetachmentFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func listPaymentMethods(customerId: String) async throws -> [StripePaymentMethod] {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let paymentMethods = try await networking.listPaymentMethods(customerId: customerId)
            self.paymentMethods = paymentMethods
            return paymentMethods
        } catch {
            let stripeError = StripeServiceError.paymentMethodListFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func updateDefaultPaymentMethod(customerId: String, paymentMethodId: String) async throws -> StripeCustomer {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let customer = try await networking.updateDefaultPaymentMethod(
                customerId: customerId,
                paymentMethodId: paymentMethodId
            )
            
            self.customer = customer
            return customer
        } catch {
            let stripeError = StripeServiceError.defaultPaymentMethodUpdateFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    // MARK: - Payment Sheet
    public func createPaymentSheet(
        customerId: String,
        amount: Int,
        currency: String = "usd",
        setupFutureUsage: Bool = false
    ) async throws -> PaymentSheet {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let paymentIntent = try await networking.createPaymentIntent(
                customerId: customerId,
                amount: amount,
                currency: currency,
                setupFutureUsage: setupFutureUsage
            )
            
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = Config.App.name
            configuration.allowsDelayedPaymentMethods = true
            configuration.returnURL = "streamyyy://payment-return"
            
            // Configure Apple Pay
            if isApplePayAvailable {
                configuration.applePay = .init(
                    merchantId: Config.Stripe.merchantIdentifier,
                    merchantCountryCode: "US"
                )
            }
            
            // Configure customer
            if let ephemeralKey = ephemeralKey {
                configuration.customer = .init(
                    id: customerId,
                    ephemeralKeySecret: ephemeralKey
                )
            }
            
            // Configure appearance
            configuration.appearance = createPaymentSheetAppearance()
            
            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: paymentIntent.clientSecret,
                configuration: configuration
            )
            
            self.paymentSheet = paymentSheet
            return paymentSheet
        } catch {
            let stripeError = StripeServiceError.paymentSheetCreationFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func createSetupIntentSheet(customerId: String) async throws -> PaymentSheet {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let setupIntent = try await networking.createSetupIntent(customerId: customerId)
            
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = Config.App.name
            configuration.returnURL = "streamyyy://setup-return"
            
            // Configure customer
            if let ephemeralKey = ephemeralKey {
                configuration.customer = .init(
                    id: customerId,
                    ephemeralKeySecret: ephemeralKey
                )
            }
            
            // Configure appearance
            configuration.appearance = createPaymentSheetAppearance()
            
            let setupSheet = PaymentSheet(
                setupIntentClientSecret: setupIntent.clientSecret,
                configuration: configuration
            )
            
            self.setupIntentSheet = setupSheet
            return setupSheet
        } catch {
            let stripeError = StripeServiceError.setupIntentCreationFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func presentPaymentSheet() async throws -> PaymentSheetResult {
        guard let paymentSheet = paymentSheet else {
            throw StripeServiceError.paymentSheetNotConfigured
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
                continuation.resume(throwing: StripeServiceError.noPresentingViewController)
                return
            }
            
            paymentSheet.present(from: presentingViewController) { result in
                self.paymentResult = result
                self.handlePaymentResult(result)
                continuation.resume(returning: result)
            }
        }
    }
    
    public func presentSetupIntentSheet() async throws -> PaymentSheetResult {
        guard let setupSheet = setupIntentSheet else {
            throw StripeServiceError.setupIntentSheetNotConfigured
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
                continuation.resume(throwing: StripeServiceError.noPresentingViewController)
                return
            }
            
            setupSheet.present(from: presentingViewController) { result in
                self.paymentResult = result
                self.handlePaymentResult(result)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Apple Pay
    public func checkApplePayAvailability() {
        isApplePayAvailable = StripeAPI.canMakeApplePayPayments()
    }
    
    public func createApplePayPayment(
        amount: Int,
        currency: String = "USD",
        description: String = "Streamyyy Subscription"
    ) async throws -> STPApplePayContext {
        guard isApplePayAvailable else {
            throw StripeServiceError.applePayNotAvailable
        }
        
        let paymentRequest = StripeAPI.paymentRequest(
            withMerchantIdentifier: Config.Stripe.merchantIdentifier,
            amount: amount,
            currency: currency
        )
        
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: description,
                amount: NSDecimalNumber(value: Double(amount) / 100)
            )
        ]
        
        // Configure required billing and shipping address fields
        paymentRequest.requiredBillingContactFields = [.emailAddress, .name]
        paymentRequest.requiredShippingContactFields = []
        
        let applePayContext = STPApplePayContext(
            paymentRequest: paymentRequest,
            delegate: self
        )
        
        return applePayContext
    }
    
    // MARK: - Invoice Management
    public func retrieveInvoices(customerId: String) async throws -> [StripeInvoice] {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let invoices = try await networking.retrieveInvoices(customerId: customerId)
            self.invoices = invoices
            return invoices
        } catch {
            let stripeError = StripeServiceError.invoiceRetrievalFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func retrieveInvoice(invoiceId: String) async throws -> StripeInvoice {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let invoice = try await networking.retrieveInvoice(invoiceId: invoiceId)
            return invoice
        } catch {
            let stripeError = StripeServiceError.invoiceRetrievalFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    public func downloadInvoicePDF(invoiceId: String) async throws -> URL {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let pdfURL = try await networking.downloadInvoicePDF(invoiceId: invoiceId)
            return pdfURL
        } catch {
            let stripeError = StripeServiceError.invoiceDownloadFailed(error.localizedDescription)
            self.error = stripeError
            throw stripeError
        }
    }
    
    // MARK: - Webhook Handling
    public func handleWebhookEvent(_ event: StripeWebhookEvent) async {
        switch event.type {
        case .subscriptionCreated:
            await handleSubscriptionCreated(event)
        case .subscriptionUpdated:
            await handleSubscriptionUpdated(event)
        case .subscriptionDeleted:
            await handleSubscriptionDeleted(event)
        case .invoicePaymentSucceeded:
            await handleInvoicePaymentSucceeded(event)
        case .invoicePaymentFailed:
            await handleInvoicePaymentFailed(event)
        case .customerSubscriptionTrialWillEnd:
            await handleTrialWillEnd(event)
        case .paymentMethodAttached:
            await handlePaymentMethodAttached(event)
        case .paymentMethodDetached:
            await handlePaymentMethodDetached(event)
        default:
            print("Unhandled webhook event: \(event.type)")
        }
    }
    
    // MARK: - Private Methods
    private func setLoading(_ loading: Bool) {
        Task { @MainActor in
            self.isLoading = loading
        }
    }
    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            print("Payment completed successfully")
            // Track success
            AnalyticsManager.shared.trackPaymentSuccess()
            
        case .canceled:
            print("Payment canceled by user")
            // Track cancellation
            AnalyticsManager.shared.trackPaymentCanceled()
            
        case .failed(let error):
            print("Payment failed: \(error)")
            self.error = StripeServiceError.paymentFailed(error.localizedDescription)
            // Track failure
            AnalyticsManager.shared.trackPaymentFailed(error)
        }
    }
    
    private func createPaymentSheetAppearance() -> PaymentSheet.Appearance {
        var appearance = PaymentSheet.Appearance()
        
        // Colors
        appearance.colors.primary = UIColor.systemPurple
        appearance.colors.background = UIColor.systemBackground
        appearance.colors.componentBackground = UIColor.secondarySystemBackground
        appearance.colors.componentBorder = UIColor.separator
        appearance.colors.componentDivider = UIColor.separator
        appearance.colors.text = UIColor.label
        appearance.colors.textSecondary = UIColor.secondaryLabel
        appearance.colors.componentText = UIColor.label
        appearance.colors.componentPlaceholderText = UIColor.placeholderText
        appearance.colors.icon = UIColor.label
        appearance.colors.danger = UIColor.systemRed
        
        // Primary button
        appearance.primaryButton.backgroundColor = UIColor.systemPurple
        appearance.primaryButton.textColor = UIColor.white
        appearance.primaryButton.cornerRadius = 12
        appearance.primaryButton.borderWidth = 0
        appearance.primaryButton.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        // Corner radius
        appearance.cornerRadius = 12
        appearance.borderWidth = 1
        
        return appearance
    }
    
    private func refreshPaymentMethods(customerId: String) async {
        do {
            let paymentMethods = try await networking.listPaymentMethods(customerId: customerId)
            await MainActor.run {
                self.paymentMethods = paymentMethods
            }
        } catch {
            print("Failed to refresh payment methods: \(error)")
        }
    }
    
    private func handleNetworkChange() {
        // Handle network status changes
        // Retry failed requests if network is back online
    }
    
    // MARK: - Webhook Event Handlers
    private func handleSubscriptionCreated(_ event: StripeWebhookEvent) async {
        guard let subscription = event.data as? StripeSubscription else { return }
        
        await MainActor.run {
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .active
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .subscriptionCreated,
            object: subscription
        )
    }
    
    private func handleSubscriptionUpdated(_ event: StripeWebhookEvent) async {
        guard let subscription = event.data as? StripeSubscription else { return }
        
        await MainActor.run {
            self.currentSubscription = subscription
            self.subscriptionStatus = SubscriptionStatus(rawValue: subscription.status) ?? .active
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .subscriptionUpdated,
            object: subscription
        )
    }
    
    private func handleSubscriptionDeleted(_ event: StripeWebhookEvent) async {
        guard let subscription = event.data as? StripeSubscription else { return }
        
        await MainActor.run {
            self.currentSubscription = nil
            self.subscriptionStatus = .canceled
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .subscriptionDeleted,
            object: subscription
        )
    }
    
    private func handleInvoicePaymentSucceeded(_ event: StripeWebhookEvent) async {
        // Handle successful payment
        // Update local subscription data
        // Send confirmation notification
        
        // Post notification
        NotificationCenter.default.post(
            name: .invoicePaymentSucceeded,
            object: event.data
        )
    }
    
    private func handleInvoicePaymentFailed(_ event: StripeWebhookEvent) async {
        // Handle failed payment
        // Update subscription status
        // Notify user about payment failure
        
        // Post notification
        NotificationCenter.default.post(
            name: .invoicePaymentFailed,
            object: event.data
        )
    }
    
    private func handleTrialWillEnd(_ event: StripeWebhookEvent) async {
        // Handle trial ending soon
        // Send notification to user
        
        // Post notification
        NotificationCenter.default.post(
            name: .trialWillEnd,
            object: event.data
        )
    }
    
    private func handlePaymentMethodAttached(_ event: StripeWebhookEvent) async {
        // Refresh payment methods
        if let customerId = self.customerId {
            await refreshPaymentMethods(customerId: customerId)
        }
    }
    
    private func handlePaymentMethodDetached(_ event: StripeWebhookEvent) async {
        // Refresh payment methods
        if let customerId = self.customerId {
            await refreshPaymentMethods(customerId: customerId)
        }
    }
    
    // MARK: - Error Handling
    public func clearError() {
        error = nil
    }
    
    public func reset() {
        paymentSheet = nil
        setupIntentSheet = nil
        paymentResult = nil
        currentSubscription = nil
        customer = nil
        paymentMethods = []
        invoices = []
        error = nil
        isLoading = false
    }
}

// MARK: - Apple Pay Context Delegate
extension StripeService: STPApplePayContextDelegate {
    public func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: STPPaymentMethod,
        paymentInformation: PKPayment,
        completion: @escaping STPIntentClientSecretCompletionBlock
    ) {
        Task {
            do {
                let paymentIntent = try await networking.createPaymentIntent(
                    customerId: customerId ?? "",
                    amount: Int(paymentInformation.amount.doubleValue * 100),
                    currency: "usd",
                    paymentMethodId: paymentMethod.stripeId
                )
                
                completion(paymentIntent.clientSecret, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    public func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPPaymentStatus,
        error: Error?
    ) {
        if let error = error {
            self.error = StripeServiceError.applePayFailed(error.localizedDescription)
        }
        
        switch status {
        case .success:
            print("Apple Pay payment succeeded")
            AnalyticsManager.shared.trackApplePaySuccess()
            
        case .error:
            print("Apple Pay payment failed")
            AnalyticsManager.shared.trackApplePayFailed()
            
        case .userCancellation:
            print("Apple Pay payment canceled")
            AnalyticsManager.shared.trackApplePayCanceled()
            
        @unknown default:
            break
        }
    }
}

// MARK: - Proration Behavior
public enum ProrationBehavior: String, CaseIterable {
    case createProrations = "create_prorations"
    case none = "none"
    case alwaysInvoice = "always_invoice"
}

// MARK: - Notification Names
extension Notification.Name {
    static let subscriptionCreated = Notification.Name("subscriptionCreated")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
    static let subscriptionDeleted = Notification.Name("subscriptionDeleted")
    static let subscriptionCanceled = Notification.Name("subscriptionCanceled")
    static let subscriptionReactivated = Notification.Name("subscriptionReactivated")
    static let invoicePaymentSucceeded = Notification.Name("invoicePaymentSucceeded")
    static let invoicePaymentFailed = Notification.Name("invoicePaymentFailed")
    static let trialWillEnd = Notification.Name("trialWillEnd")
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Stripe Service Error
public enum StripeServiceError: Error, LocalizedError {
    case customerCreationFailed(String)
    case customerRetrievalFailed(String)
    case customerUpdateFailed(String)
    case subscriptionCreationFailed(String)
    case subscriptionRetrievalFailed(String)
    case subscriptionUpdateFailed(String)
    case subscriptionCancellationFailed(String)
    case subscriptionReactivationFailed(String)
    case paymentMethodAttachmentFailed(String)
    case paymentMethodDetachmentFailed(String)
    case paymentMethodListFailed(String)
    case defaultPaymentMethodUpdateFailed(String)
    case paymentSheetCreationFailed(String)
    case setupIntentCreationFailed(String)
    case paymentSheetNotConfigured
    case setupIntentSheetNotConfigured
    case noPresentingViewController
    case paymentFailed(String)
    case applePayNotAvailable
    case applePayFailed(String)
    case invoiceRetrievalFailed(String)
    case invoiceDownloadFailed(String)
    case networkError(String)
    case invalidConfiguration
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .customerCreationFailed(let message):
            return "Customer creation failed: \(message)"
        case .customerRetrievalFailed(let message):
            return "Customer retrieval failed: \(message)"
        case .customerUpdateFailed(let message):
            return "Customer update failed: \(message)"
        case .subscriptionCreationFailed(let message):
            return "Subscription creation failed: \(message)"
        case .subscriptionRetrievalFailed(let message):
            return "Subscription retrieval failed: \(message)"
        case .subscriptionUpdateFailed(let message):
            return "Subscription update failed: \(message)"
        case .subscriptionCancellationFailed(let message):
            return "Subscription cancellation failed: \(message)"
        case .subscriptionReactivationFailed(let message):
            return "Subscription reactivation failed: \(message)"
        case .paymentMethodAttachmentFailed(let message):
            return "Payment method attachment failed: \(message)"
        case .paymentMethodDetachmentFailed(let message):
            return "Payment method detachment failed: \(message)"
        case .paymentMethodListFailed(let message):
            return "Payment method list failed: \(message)"
        case .defaultPaymentMethodUpdateFailed(let message):
            return "Default payment method update failed: \(message)"
        case .paymentSheetCreationFailed(let message):
            return "Payment sheet creation failed: \(message)"
        case .setupIntentCreationFailed(let message):
            return "Setup intent creation failed: \(message)"
        case .paymentSheetNotConfigured:
            return "Payment sheet is not configured"
        case .setupIntentSheetNotConfigured:
            return "Setup intent sheet is not configured"
        case .noPresentingViewController:
            return "No presenting view controller available"
        case .paymentFailed(let message):
            return "Payment failed: \(message)"
        case .applePayNotAvailable:
            return "Apple Pay is not available"
        case .applePayFailed(let message):
            return "Apple Pay failed: \(message)"
        case .invoiceRetrievalFailed(let message):
            return "Invoice retrieval failed: \(message)"
        case .invoiceDownloadFailed(let message):
            return "Invoice download failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidConfiguration:
            return "Invalid configuration"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}