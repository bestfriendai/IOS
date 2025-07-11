//
//  SubscriptionSyncService.swift
//  StreamyyyApp
//
//  Cross-platform subscription synchronization service
//  Keeps iOS app subscriptions in sync with web app via Supabase
//

import Foundation
import Combine

// MARK: - Subscription Sync Service
@MainActor
public class SubscriptionSyncService: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SubscriptionSyncService()
    
    // MARK: - Published Properties
    @Published public var isSyncing = false
    @Published public var lastSyncDate: Date?
    @Published public var syncError: SyncError?
    @Published public var isOnline = true
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    private let stripeNetworking = StripeNetworkingService.shared
    private let notificationService = NotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        setupSyncService()
    }
    
    // MARK: - Setup
    private func setupSyncService() {
        // Monitor network connectivity
        setupNetworkMonitoring()
        
        // Setup periodic sync
        startPeriodicSync()
        
        // Monitor subscription changes
        setupSubscriptionObservers()
        
        // Monitor app lifecycle
        setupAppLifecycleObservers()
    }
    
    private func setupNetworkMonitoring() {
        // TODO: Implement proper network monitoring
        // For now, assume always online
        isOnline = true
    }
    
    private func startPeriodicSync() {
        // Sync every 5 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundSync()
            }
        }
    }
    
    private func setupSubscriptionObservers() {
        // Monitor Stripe subscription changes
        NotificationCenter.default.publisher(for: .subscriptionCreated)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleSubscriptionChange(notification)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .subscriptionUpdated)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleSubscriptionChange(notification)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .subscriptionCanceled)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleSubscriptionChange(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.syncOnAppActivation()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.syncBeforeBackground()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Sync Methods
    public func performFullSync() async -> Bool {
        guard !isSyncing && isOnline else {
            print("⚠️ Sync already in progress or offline")
            return false
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            print("🔄 Starting full subscription sync...")
            
            // Get current user ID
            guard let userId = getCurrentUserId() else {
                throw SyncError.userNotAuthenticated
            }
            
            // Sync subscription status from Stripe to Supabase
            let success = try await syncStripeToSupabase(userId: userId)
            
            if success {
                lastSyncDate = Date()
                print("✅ Full sync completed successfully")
                
                // Track analytics
                AnalyticsManager.shared.trackSubscriptionSyncSuccess()
                
                return true
            } else {
                throw SyncError.syncFailed("Unknown error")
            }
            
        } catch {
            syncError = error as? SyncError ?? SyncError.unknown(error)
            print("❌ Full sync failed: \(error)")
            
            // Track analytics
            AnalyticsManager.shared.trackSubscriptionSyncFailure(error)
            
            return false
        } finally {
            isSyncing = false
        }
    }
    
    public func syncSubscriptionStatus(userId: String) async -> Bool {
        do {
            // Get subscription from Stripe
            guard let stripeSubscription = try await stripeNetworking.getActiveSubscriptionForUser(userId: userId) else {
                // No active subscription, update Supabase accordingly
                try await updateSupabaseSubscription(userId: userId, subscription: nil)
                return true
            }
            
            // Convert Stripe subscription to local format
            let subscriptionData = convertStripeToSupabase(stripeSubscription)
            
            // Update Supabase
            try await updateSupabaseSubscription(userId: userId, subscription: subscriptionData)
            
            return true
            
        } catch {
            print("❌ Failed to sync subscription status: \(error)")
            return false
        }
    }
    
    public func forceSync() async {
        await performFullSync()
    }
    
    // MARK: - Private Sync Methods
    private func performBackgroundSync() async {
        guard isOnline else { return }
        
        do {
            guard let userId = getCurrentUserId() else { return }
            
            // Perform lightweight sync
            _ = try await syncSubscriptionStatus(userId: userId)
            
        } catch {
            print("⚠️ Background sync failed: \(error)")
        }
    }
    
    private func syncOnAppActivation() async {
        // Perform sync when app becomes active
        await performFullSync()
    }
    
    private func syncBeforeBackground() async {
        // Quick sync before app goes to background
        guard let userId = getCurrentUserId() else { return }
        _ = await syncSubscriptionStatus(userId: userId)
    }
    
    private func syncStripeToSupabase(userId: String) async throws -> Bool {
        // Get active subscription from Stripe
        let stripeSubscription = try await stripeNetworking.getActiveSubscriptionForUser(userId: userId)
        
        // Convert to Supabase format
        let subscriptionData = stripeSubscription.map(convertStripeToSupabase)
        
        // Update Supabase
        try await updateSupabaseSubscription(userId: userId, subscription: subscriptionData)
        
        // Sync subscription features and limits
        if let subscriptionData = subscriptionData {
            try await syncSubscriptionFeatures(userId: userId, subscription: subscriptionData)
        }
        
        return true
    }
    
    private func updateSupabaseSubscription(userId: String, subscription: SupabaseSubscriptionData?) async throws {
        do {
            if let subscription = subscription {
                // Update existing or create new subscription
                try await supabaseService.upsertSubscription(
                    userId: userId,
                    subscriptionData: subscription
                )
            } else {
                // Clear subscription (user has no active subscription)
                try await supabaseService.clearUserSubscription(userId: userId)
            }
            
        } catch {
            print("❌ Failed to update Supabase subscription: \(error)")
            throw SyncError.supabaseUpdateFailed(error.localizedDescription)
        }
    }
    
    private func syncSubscriptionFeatures(userId: String, subscription: SupabaseSubscriptionData) async throws {
        // Get plan features from config
        let planName = subscription.productName.lowercased()
        guard let features = Config.Stripe.tierFeatures[planName] else {
            print("⚠️ No features found for plan: \(planName)")
            return
        }
        
        // Update user features in Supabase
        try await supabaseService.updateUserFeatures(userId: userId, features: features)
    }
    
    private func convertStripeToSupabase(_ stripeSubscription: StripeSubscription) -> SupabaseSubscriptionData {
        return SupabaseSubscriptionData(
            id: stripeSubscription.id,
            userId: getCurrentUserId() ?? "",
            stripeSubscriptionId: stripeSubscription.id,
            stripePriceId: stripeSubscription.priceId,
            stripeCustomerId: stripeSubscription.customerId,
            status: stripeSubscription.status,
            productName: getProductNameFromPriceId(stripeSubscription.priceId),
            currentPeriodStart: Date(timeIntervalSince1970: stripeSubscription.currentPeriodStart),
            currentPeriodEnd: Date(timeIntervalSince1970: stripeSubscription.currentPeriodEnd),
            cancelAtPeriodEnd: stripeSubscription.cancelAtPeriodEnd,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func getProductNameFromPriceId(_ priceId: String) -> String {
        // Map price IDs to product names
        switch priceId {
        case Config.Stripe.basicMonthlyPlanId, Config.Stripe.basicYearlyPlanId:
            return "Basic"
        case Config.Stripe.premiumMonthlyPlanId, Config.Stripe.premiumYearlyPlanId:
            return "Premium"
        case Config.Stripe.proMonthlyPlanId, Config.Stripe.proYearlyPlanId:
            return "Pro"
        case Config.Stripe.enterpriseMonthlyPlanId, Config.Stripe.enterpriseYearlyPlanId:
            return "Enterprise"
        default:
            return "Premium" // Default fallback
        }
    }
    
    private func getCurrentUserId() -> String? {
        // TODO: Get actual user ID from authentication service
        // For now, return a placeholder
        return "user_123"
    }
    
    // MARK: - Event Handlers
    private func handleSubscriptionChange(_ notification: Notification) async {
        print("🔄 Handling subscription change notification")
        
        // Perform immediate sync when subscription changes
        await performFullSync()
        
        // Send push notification about sync completion
        await notificationService.scheduleSubscriptionNotification(
            type: .updated,
            title: "Subscription Updated",
            body: "Your subscription has been synchronized across all devices."
        )
    }
    
    // MARK: - Webhook Support
    public func handleWebhookEvent(_ event: StripeWebhookEvent) async {
        print("🔄 Handling webhook event: \(event.type)")
        
        // Process webhook events to trigger immediate sync
        switch event.type {
        case .subscriptionCreated, .subscriptionUpdated, .subscriptionDeleted:
            await performFullSync()
        case .invoicePaymentSucceeded:
            await performFullSync()
        case .invoicePaymentFailed:
            await performFullSync()
        default:
            break
        }
    }
    
    // MARK: - Health Check
    public func performHealthCheck() async -> SyncHealthStatus {
        var status = SyncHealthStatus()
        
        // Check network connectivity
        status.isOnline = isOnline
        
        // Check last sync time
        if let lastSync = lastSyncDate {
            status.lastSyncAge = Date().timeIntervalSince(lastSync)
            status.isSyncRecent = status.lastSyncAge < 600 // 10 minutes
        } else {
            status.isSyncRecent = false
            status.lastSyncAge = -1
        }
        
        // Check for sync errors
        status.hasErrors = syncError != nil
        status.errorMessage = syncError?.localizedDescription
        
        // Check service availability
        status.stripeServiceAvailable = await checkStripeServiceHealth()
        status.supabaseServiceAvailable = await checkSupabaseServiceHealth()
        
        // Overall health
        status.isHealthy = status.isOnline && 
                          status.isSyncRecent && 
                          !status.hasErrors && 
                          status.stripeServiceAvailable && 
                          status.supabaseServiceAvailable
        
        return status
    }
    
    private func checkStripeServiceHealth() async -> Bool {
        // TODO: Implement actual health check
        return true
    }
    
    private func checkSupabaseServiceHealth() async -> Bool {
        // TODO: Implement actual health check
        return true
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

// MARK: - Supabase Subscription Data Model
public struct SupabaseSubscriptionData: Codable {
    let id: String
    let userId: String
    let stripeSubscriptionId: String
    let stripePriceId: String
    let stripeCustomerId: String
    let status: String
    let productName: String
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelAtPeriodEnd: Bool
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Sync Health Status
public struct SyncHealthStatus {
    public var isHealthy = false
    public var isOnline = false
    public var isSyncRecent = false
    public var lastSyncAge: TimeInterval = -1
    public var hasErrors = false
    public var errorMessage: String?
    public var stripeServiceAvailable = false
    public var supabaseServiceAvailable = false
    
    public var statusMessage: String {
        if isHealthy {
            return "All systems operational"
        } else if !isOnline {
            return "Offline - sync will resume when online"
        } else if hasErrors {
            return errorMessage ?? "Sync error occurred"
        } else if !isSyncRecent {
            return "Sync may be outdated"
        } else {
            return "Service issues detected"
        }
    }
}

// MARK: - Sync Errors
public enum SyncError: Error, LocalizedError {
    case userNotAuthenticated
    case networkUnavailable
    case stripeServiceUnavailable
    case supabaseServiceUnavailable
    case supabaseUpdateFailed(String)
    case dataConversionError
    case syncFailed(String)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .networkUnavailable:
            return "Network unavailable"
        case .stripeServiceUnavailable:
            return "Stripe service unavailable"
        case .supabaseServiceUnavailable:
            return "Supabase service unavailable"
        case .supabaseUpdateFailed(let message):
            return "Supabase update failed: \(message)"
        case .dataConversionError:
            return "Data conversion error"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - SupabaseService Extensions
extension SupabaseService {
    func upsertSubscription(userId: String, subscriptionData: SupabaseSubscriptionData) async throws {
        // TODO: Implement actual Supabase upsert
        print("📝 Upserting subscription for user \(userId)")
    }
    
    func clearUserSubscription(userId: String) async throws {
        // TODO: Implement actual Supabase clear
        print("🗑️ Clearing subscription for user \(userId)")
    }
    
    func updateUserFeatures(userId: String, features: [String: Any]) async throws {
        // TODO: Implement actual features update
        print("🔧 Updating features for user \(userId): \(features)")
    }
}

// MARK: - Analytics Extensions
extension AnalyticsManager {
    func trackSubscriptionSyncSuccess() {
        track(name: "subscription_sync_success")
    }
    
    func trackSubscriptionSyncFailure(_ error: Error) {
        track(name: "subscription_sync_failure", properties: [
            "error": error.localizedDescription
        ])
    }
}