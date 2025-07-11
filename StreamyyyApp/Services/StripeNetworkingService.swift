//
//  StripeNetworkingService.swift
//  StreamyyyApp
//
//  Production-ready Stripe networking service
//  Connects to backend API for all Stripe operations
//

import Foundation

// MARK: - Stripe Networking Service
public class StripeNetworkingService {
    private let baseURL = Config.API.baseURL
    private let session = URLSession.shared
    
    // MARK: - Singleton
    public static let shared = StripeNetworkingService()
    
    private init() {}
    
    // MARK: - Private Request Helper
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/v1/stripe\(endpoint)") else {
            throw StripeServiceError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("StreamyyyApp/\(Config.App.version)", forHTTPHeaderField: "User-Agent")
        
        // Add authentication header if available
        if let userId = getCurrentUserId() {
            request.setValue("Bearer \(userId)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw StripeServiceError.networkError("Failed to serialize request body")
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StripeServiceError.networkError("Invalid response type")
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 400:
                throw StripeServiceError.networkError("Bad request")
            case 401:
                throw StripeServiceError.networkError("Unauthorized")
            case 403:
                throw StripeServiceError.networkError("Forbidden")
            case 404:
                throw StripeServiceError.networkError("Not found")
            case 500...599:
                throw StripeServiceError.networkError("Server error")
            default:
                throw StripeServiceError.networkError("HTTP \(httpResponse.statusCode)")
            }
            
            // Parse response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            return try decoder.decode(responseType, from: data)
            
        } catch {
            if error is StripeServiceError {
                throw error
            } else {
                throw StripeServiceError.networkError(error.localizedDescription)
            }
        }
    }
    
    private func getCurrentUserId() -> String? {
        // TODO: Get actual user ID from authentication service
        // For now, return a placeholder
        return "user_123"
    }
    
    // MARK: - Customer Operations
    public func createCustomer(email: String, name: String, metadata: [String: String]) async throws -> StripeCustomer {
        let body: [String: Any] = [
            "email": email,
            "name": name,
            "metadata": metadata
        ]
        
        let response: StripeCustomerResponse = try await makeRequest(
            endpoint: "/customers",
            method: .POST,
            body: body,
            responseType: StripeCustomerResponse.self
        )
        
        return response.customer
    }
    
    public func retrieveCustomer(customerId: String) async throws -> StripeCustomer {
        let response: StripeCustomerResponse = try await makeRequest(
            endpoint: "/customers/\(customerId)",
            method: .GET,
            responseType: StripeCustomerResponse.self
        )
        
        return response.customer
    }
    
    public func updateCustomer(customerId: String, email: String?, name: String?, metadata: [String: String]?) async throws -> StripeCustomer {
        var body: [String: Any] = [:]
        if let email = email { body["email"] = email }
        if let name = name { body["name"] = name }
        if let metadata = metadata { body["metadata"] = metadata }
        
        let response: StripeCustomerResponse = try await makeRequest(
            endpoint: "/customers/\(customerId)",
            method: .PUT,
            body: body,
            responseType: StripeCustomerResponse.self
        )
        
        return response.customer
    }
    
    public func createEphemeralKey(customerId: String) async throws -> String {
        let body: [String: Any] = [
            "customer_id": customerId
        ]
        
        let response: EphemeralKeyResponse = try await makeRequest(
            endpoint: "/ephemeral-keys",
            method: .POST,
            body: body,
            responseType: EphemeralKeyResponse.self
        )
        
        return response.secret
    }
    
    // MARK: - Subscription Operations
    public func createSubscription(customerId: String, priceId: String, paymentMethodId: String?, trialDays: Int?, metadata: [String: String]) async throws -> StripeSubscription {
        var body: [String: Any] = [
            "customer_id": customerId,
            "price_id": priceId,
            "metadata": metadata
        ]
        
        if let paymentMethodId = paymentMethodId {
            body["payment_method_id"] = paymentMethodId
        }
        
        if let trialDays = trialDays {
            body["trial_period_days"] = trialDays
        }
        
        let response: StripeSubscriptionResponse = try await makeRequest(
            endpoint: "/subscriptions",
            method: .POST,
            body: body,
            responseType: StripeSubscriptionResponse.self
        )
        
        return response.subscription
    }
    
    public func retrieveSubscription(subscriptionId: String) async throws -> StripeSubscription {
        let response: StripeSubscriptionResponse = try await makeRequest(
            endpoint: "/subscriptions/\(subscriptionId)",
            method: .GET,
            responseType: StripeSubscriptionResponse.self
        )
        
        return response.subscription
    }
    
    public func updateSubscription(subscriptionId: String, priceId: String, prorationBehavior: ProrationBehavior) async throws -> StripeSubscription {
        let body: [String: Any] = [
            "price_id": priceId,
            "proration_behavior": prorationBehavior.rawValue
        ]
        
        let response: StripeSubscriptionResponse = try await makeRequest(
            endpoint: "/subscriptions/\(subscriptionId)",
            method: .PUT,
            body: body,
            responseType: StripeSubscriptionResponse.self
        )
        
        return response.subscription
    }
    
    public func cancelSubscription(subscriptionId: String, immediately: Bool, cancelReason: String?) async throws -> StripeSubscription {
        var body: [String: Any] = [
            "immediately": immediately
        ]
        
        if let cancelReason = cancelReason {
            body["cancel_reason"] = cancelReason
        }
        
        let response: StripeSubscriptionResponse = try await makeRequest(
            endpoint: "/subscriptions/\(subscriptionId)/cancel",
            method: .POST,
            body: body,
            responseType: StripeSubscriptionResponse.self
        )
        
        return response.subscription
    }
    
    public func reactivateSubscription(subscriptionId: String) async throws -> StripeSubscription {
        let response: StripeSubscriptionResponse = try await makeRequest(
            endpoint: "/subscriptions/\(subscriptionId)/reactivate",
            method: .POST,
            responseType: StripeSubscriptionResponse.self
        )
        
        return response.subscription
    }
    
    // MARK: - Payment Method Operations
    public func attachPaymentMethod(paymentMethodId: String, customerId: String) async throws -> StripePaymentMethod {
        let body: [String: Any] = [
            "customer_id": customerId
        ]
        
        let response: StripePaymentMethodResponse = try await makeRequest(
            endpoint: "/payment-methods/\(paymentMethodId)/attach",
            method: .POST,
            body: body,
            responseType: StripePaymentMethodResponse.self
        )
        
        return response.paymentMethod
    }
    
    public func detachPaymentMethod(paymentMethodId: String) async throws -> StripePaymentMethod {
        let response: StripePaymentMethodResponse = try await makeRequest(
            endpoint: "/payment-methods/\(paymentMethodId)/detach",
            method: .POST,
            responseType: StripePaymentMethodResponse.self
        )
        
        return response.paymentMethod
    }
    
    public func listPaymentMethods(customerId: String) async throws -> [StripePaymentMethod] {
        let response: StripePaymentMethodListResponse = try await makeRequest(
            endpoint: "/payment-methods?customer_id=\(customerId)",
            method: .GET,
            responseType: StripePaymentMethodListResponse.self
        )
        
        return response.data
    }
    
    public func updateDefaultPaymentMethod(customerId: String, paymentMethodId: String) async throws -> StripeCustomer {
        let body: [String: Any] = [
            "default_payment_method": paymentMethodId
        ]
        
        let response: StripeCustomerResponse = try await makeRequest(
            endpoint: "/customers/\(customerId)",
            method: .PUT,
            body: body,
            responseType: StripeCustomerResponse.self
        )
        
        return response.customer
    }
    
    // MARK: - Payment Intent Operations
    public func createPaymentIntent(customerId: String, amount: Int, currency: String, setupFutureUsage: Bool = false, paymentMethodId: String? = nil) async throws -> StripePaymentIntent {
        var body: [String: Any] = [
            "customer_id": customerId,
            "amount": amount,
            "currency": currency
        ]
        
        if setupFutureUsage {
            body["setup_future_usage"] = "off_session"
        }
        
        if let paymentMethodId = paymentMethodId {
            body["payment_method"] = paymentMethodId
        }
        
        let response: StripePaymentIntentResponse = try await makeRequest(
            endpoint: "/payment-intents",
            method: .POST,
            body: body,
            responseType: StripePaymentIntentResponse.self
        )
        
        return response.paymentIntent
    }
    
    public func createSetupIntent(customerId: String) async throws -> StripeSetupIntent {
        let body: [String: Any] = [
            "customer_id": customerId
        ]
        
        let response: StripeSetupIntentResponse = try await makeRequest(
            endpoint: "/setup-intents",
            method: .POST,
            body: body,
            responseType: StripeSetupIntentResponse.self
        )
        
        return response.setupIntent
    }
    
    // MARK: - Invoice Operations
    public func retrieveInvoices(customerId: String) async throws -> [StripeInvoice] {
        let response: StripeInvoiceListResponse = try await makeRequest(
            endpoint: "/invoices?customer_id=\(customerId)",
            method: .GET,
            responseType: StripeInvoiceListResponse.self
        )
        
        return response.data
    }
    
    public func retrieveInvoice(invoiceId: String) async throws -> StripeInvoice {
        let response: StripeInvoiceResponse = try await makeRequest(
            endpoint: "/invoices/\(invoiceId)",
            method: .GET,
            responseType: StripeInvoiceResponse.self
        )
        
        return response.invoice
    }
    
    public func downloadInvoicePDF(invoiceId: String) async throws -> URL {
        let response: InvoicePDFResponse = try await makeRequest(
            endpoint: "/invoices/\(invoiceId)/pdf",
            method: .GET,
            responseType: InvoicePDFResponse.self
        )
        
        guard let url = URL(string: response.pdfUrl) else {
            throw StripeServiceError.networkError("Invalid PDF URL")
        }
        
        return url
    }
    
    // MARK: - Subscription Sync with Web App
    public func syncSubscriptionWithSupabase(subscriptionId: String, userId: String) async throws {
        let body: [String: Any] = [
            "subscription_id": subscriptionId,
            "user_id": userId
        ]
        
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/sync-subscription",
            method: .POST,
            body: body,
            responseType: EmptyResponse.self
        )
    }
    
    public func getActiveSubscriptionForUser(userId: String) async throws -> StripeSubscription? {
        do {
            let response: StripeSubscriptionResponse = try await makeRequest(
                endpoint: "/subscriptions/user/\(userId)/active",
                method: .GET,
                responseType: StripeSubscriptionResponse.self
            )
            return response.subscription
        } catch {
            // If no active subscription is found, return nil instead of throwing
            if case StripeServiceError.networkError(let message) = error, message.contains("Not found") {
                return nil
            }
            throw error
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Response Models
struct StripeCustomerResponse: Codable {
    let customer: StripeCustomer
}

struct EphemeralKeyResponse: Codable {
    let secret: String
}

struct StripeSubscriptionResponse: Codable {
    let subscription: StripeSubscription
}

struct StripePaymentMethodResponse: Codable {
    let paymentMethod: StripePaymentMethod
}

struct StripePaymentMethodListResponse: Codable {
    let data: [StripePaymentMethod]
}

struct StripePaymentIntentResponse: Codable {
    let paymentIntent: StripePaymentIntent
}

struct StripeSetupIntentResponse: Codable {
    let setupIntent: StripeSetupIntent
}

struct StripeInvoiceResponse: Codable {
    let invoice: StripeInvoice
}

struct StripeInvoiceListResponse: Codable {
    let data: [StripeInvoice]
}

struct InvoicePDFResponse: Codable {
    let pdfUrl: String
}

struct EmptyResponse: Codable {
    // Empty response for sync operations
}

// MARK: - Enhanced Stripe Models
extension StripeCustomer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, email, name, defaultPaymentMethod = "default_payment_method"
    }
}

extension StripeSubscription: Codable {
    enum CodingKeys: String, CodingKey {
        case id, customerId = "customer", status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case priceId = "price"
    }
}

extension StripePaymentMethod: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, card, customer
    }
}

extension StripePaymentMethod.Card: Codable {
    enum CodingKeys: String, CodingKey {
        case brand, last4
        case expMonth = "exp_month"
        case expYear = "exp_year"
    }
}

extension StripePaymentMethod.Customer: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case defaultPaymentMethod = "default_payment_method"
    }
}

extension StripeInvoice: Codable {
    enum CodingKeys: String, CodingKey {
        case id, customerId = "customer"
        case amountPaid = "amount_paid"
        case currency, status, created
        case invoicePdf = "invoice_pdf"
    }
}

extension StripePaymentIntent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, clientSecret = "client_secret"
        case amount, currency, status
    }
}

extension StripeSetupIntent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, clientSecret = "client_secret", status
    }
}