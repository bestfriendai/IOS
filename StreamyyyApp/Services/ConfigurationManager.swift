//
//  ConfigurationManager.swift
//  StreamyyyApp
//
//  Secure configuration management for environment variables and API keys
//

import Foundation

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    // MARK: - Environment
    
    enum Environment: String, CaseIterable {
        case development = "development"
        case staging = "staging" 
        case production = "production"
        
        var displayName: String {
            switch self {
            case .development: return "Development"
            case .staging: return "Staging"
            case .production: return "Production"
            }
        }
    }
    
    @Published var currentEnvironment: Environment
    
    // MARK: - Configuration Values
    
    private var configurations: [String: Any] = [:]
    private let keychainManager = KeychainManager.shared
    
    private init() {
        // Determine environment
        #if DEBUG
        self.currentEnvironment = .development
        #else
        self.currentEnvironment = Config.isTestFlight ? .staging : .production
        #endif
        
        loadConfiguration()
        validateConfiguration()
    }
    
    // MARK: - Configuration Loading
    
    private func loadConfiguration() {
        // Load base configuration from Config.swift
        configurations = [
            // Clerk Configuration
            "clerk_publishable_key": getClerkPublishableKey(),
            "clerk_secret_key": getClerkSecretKey(),
            
            // Supabase Configuration
            "supabase_url": Config.Supabase.url,
            "supabase_anon_key": Config.Supabase.anonKey,
            
            // Platform API Keys
            "twitch_client_id": Config.Twitch.clientId,
            "twitch_client_secret": Config.Twitch.clientSecret,
            "youtube_api_key": Config.Platforms.YouTube.apiKey,
            "youtube_client_id": Config.Platforms.YouTube.clientId,
            "youtube_client_secret": Config.Platforms.YouTube.clientSecret,
            
            // Stripe Configuration
            "stripe_publishable_key": getStripePublishableKey(),
            
            // Sentry Configuration
            "sentry_dsn": getSentryDSN(),
            
            // Feature Flags
            "enable_biometric_auth": Config.Security.enableBiometricAuthentication,
            "enable_analytics": Config.Analytics.enableAnalytics,
            "enable_crash_reporting": Config.Analytics.enableCrashReporting,
            
            // URLs
            "api_base_url": getAPIBaseURL(),
            "support_url": Config.URLs.support,
            "privacy_policy_url": Config.URLs.privacyPolicy,
            "terms_url": Config.URLs.termsOfService
        ]
        
        // Load environment-specific overrides
        loadEnvironmentConfiguration()
    }
    
    private func loadEnvironmentConfiguration() {
        switch currentEnvironment {
        case .development:
            configurations["enable_debug_logging"] = true
            configurations["enable_mock_data"] = Config.Development.useMockStreams
            configurations["api_base_url"] = Config.Development.useLocalServer ? Config.Development.localServerURL : configurations["api_base_url"]
            
        case .staging:
            configurations["enable_debug_logging"] = true
            configurations["enable_mock_data"] = false
            configurations["sentry_environment"] = "staging"
            
        case .production:
            configurations["enable_debug_logging"] = false
            configurations["enable_mock_data"] = false
            configurations["sentry_environment"] = "production"
        }
    }
    
    // MARK: - Secure Key Retrieval
    
    private func getClerkPublishableKey() -> String {
        // In production, this would retrieve from secure storage or environment variables
        return Config.Clerk.publishableKey
    }
    
    private func getClerkSecretKey() -> String {
        // In production, this should NEVER be stored in the client app
        // This is only for development/staging environments
        guard currentEnvironment != .production else {
            return "" // Secret keys should never be in production client apps
        }
        return Config.Clerk.secretKey
    }
    
    private func getStripePublishableKey() -> String {
        switch currentEnvironment {
        case .development, .staging:
            return "pk_test_..." // Test key
        case .production:
            return Config.Stripe.publishableKey
        }
    }
    
    private func getSentryDSN() -> String {
        // Only enable Sentry in staging and production
        guard currentEnvironment != .development else { return "" }
        return Config.Sentry.dsn
    }
    
    private func getAPIBaseURL() -> String {
        switch currentEnvironment {
        case .development:
            return Config.Development.useLocalServer ? Config.Development.localServerURL : "https://api-dev.streamyyy.com"
        case .staging:
            return "https://api-staging.streamyyy.com"
        case .production:
            return Config.API.baseURL
        }
    }
    
    // MARK: - Configuration Access
    
    func getString(_ key: String) -> String? {
        return configurations[key] as? String
    }
    
    func getBool(_ key: String) -> Bool {
        return configurations[key] as? Bool ?? false
    }
    
    func getInt(_ key: String) -> Int? {
        return configurations[key] as? Int
    }
    
    func getDouble(_ key: String) -> Double? {
        return configurations[key] as? Double
    }
    
    func getURL(_ key: String) -> URL? {
        guard let urlString = getString(key) else { return nil }
        return URL(string: urlString)
    }
    
    // MARK: - Convenience Accessors
    
    var clerkPublishableKey: String {
        return getString("clerk_publishable_key") ?? ""
    }
    
    var supabaseURL: String {
        return getString("supabase_url") ?? ""
    }
    
    var supabaseAnonKey: String {
        return getString("supabase_anon_key") ?? ""
    }
    
    var twitchClientId: String {
        return getString("twitch_client_id") ?? ""
    }
    
    var stripePublishableKey: String {
        return getString("stripe_publishable_key") ?? ""
    }
    
    var apiBaseURL: String {
        return getString("api_base_url") ?? ""
    }
    
    var enableBiometricAuth: Bool {
        return getBool("enable_biometric_auth")
    }
    
    var enableAnalytics: Bool {
        return getBool("enable_analytics")
    }
    
    var enableDebugLogging: Bool {
        return getBool("enable_debug_logging")
    }
    
    var enableMockData: Bool {
        return getBool("enable_mock_data")
    }
    
    // MARK: - Configuration Validation
    
    private func validateConfiguration() {
        var missingConfigs: [String] = []
        
        // Critical configurations that must be present
        let requiredConfigs = [
            "clerk_publishable_key",
            "supabase_url", 
            "supabase_anon_key",
            "twitch_client_id"
        ]
        
        for config in requiredConfigs {
            if getString(config)?.isEmpty != false {
                missingConfigs.append(config)
            }
        }
        
        if !missingConfigs.isEmpty {
            print("⚠️ Missing required configurations: \(missingConfigs.joined(separator: ", "))")
            #if DEBUG
            // In debug mode, show alert or log warning
            fatalError("Missing required configurations. Please check Config.swift")
            #endif
        } else {
            print("✅ All required configurations loaded successfully")
        }
    }
    
    // MARK: - Dynamic Configuration Updates
    
    func updateConfiguration(_ key: String, value: Any) {
        configurations[key] = value
        
        // Notify observers
        objectWillChange.send()
        
        // Store persistent configurations
        if isPersistentConfiguration(key) {
            storePersistentConfiguration(key, value: value)
        }
    }
    
    private func isPersistentConfiguration(_ key: String) -> Bool {
        // Define which configurations should persist across app launches
        let persistentKeys = [
            "enable_biometric_auth",
            "enable_analytics",
            "enable_crash_reporting"
        ]
        return persistentKeys.contains(key)
    }
    
    private func storePersistentConfiguration(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: "config_\(key)")
    }
    
    private func loadPersistentConfiguration(_ key: String) -> Any? {
        return UserDefaults.standard.object(forKey: "config_\(key)")
    }
    
    // MARK: - Environment Switching (Debug Only)
    
    #if DEBUG
    func switchEnvironment(to environment: Environment) {
        currentEnvironment = environment
        loadConfiguration()
        validateConfiguration()
        
        print("🔄 Switched to \(environment.displayName) environment")
    }
    #endif
    
    // MARK: - Security Features
    
    func maskSensitiveValue(_ key: String) -> String {
        guard let value = getString(key) else { return "Not configured" }
        
        // Mask sensitive values for logging/display
        if key.contains("secret") || key.contains("private") {
            return "***HIDDEN***"
        } else if key.contains("key") || key.contains("token") {
            // Show first and last 4 characters
            guard value.count > 8 else { return "***HIDDEN***" }
            let start = value.prefix(4)
            let end = value.suffix(4)
            return "\(start)...\(end)"
        }
        
        return value
    }
    
    func printConfigurationSummary() {
        print("📋 Configuration Summary (\(currentEnvironment.displayName)):")
        print("   Clerk Key: \(maskSensitiveValue("clerk_publishable_key"))")
        print("   Supabase URL: \(supabaseURL)")
        print("   API Base URL: \(apiBaseURL)")
        print("   Biometric Auth: \(enableBiometricAuth)")
        print("   Analytics: \(enableAnalytics)")
        print("   Debug Logging: \(enableDebugLogging)")
    }
    
    // MARK: - Configuration Reset
    
    func resetToDefaults() {
        // Clear persistent configurations
        let persistentKeys = ["enable_biometric_auth", "enable_analytics", "enable_crash_reporting"]
        for key in persistentKeys {
            UserDefaults.standard.removeObject(forKey: "config_\(key)")
        }
        
        // Reload configuration
        loadConfiguration()
        
        print("🔄 Configuration reset to defaults")
    }
}

// MARK: - Configuration Errors

enum ConfigurationError: Error, LocalizedError {
    case missingRequiredConfiguration(String)
    case invalidConfigurationValue(String)
    case environmentNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredConfiguration(let key):
            return "Missing required configuration: \(key)"
        case .invalidConfigurationValue(let key):
            return "Invalid configuration value for: \(key)"
        case .environmentNotSupported(let env):
            return "Environment not supported: \(env)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingRequiredConfiguration:
            return "Please check your Config.swift file and ensure all required values are set"
        case .invalidConfigurationValue:
            return "Please verify the configuration value format and try again"
        case .environmentNotSupported:
            return "Please use one of the supported environments: development, staging, production"
        }
    }
}

// MARK: - SwiftUI Environment Extension

struct ConfigurationManagerKey: EnvironmentKey {
    static let defaultValue = ConfigurationManager.shared
}

extension EnvironmentValues {
    var configurationManager: ConfigurationManager {
        get { self[ConfigurationManagerKey.self] }
        set { self[ConfigurationManagerKey.self] = newValue }
    }
}