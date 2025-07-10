//
//  PaymentSecurityManager.swift
//  StreamyyyApp
//
//  Security practices and error handling for payment processing
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

@MainActor
class PaymentSecurityManager: ObservableObject {
    static let shared = PaymentSecurityManager()
    
    @Published var isSecureEnvironment = false
    @Published var biometricAuthenticationEnabled = false
    @Published var lastSecurityCheck: Date?
    
    private let keychain = Keychain.shared
    private let context = LAContext()
    
    private init() {
        checkSecurityEnvironment()
        checkBiometricAvailability()
    }
    
    // MARK: - Security Environment Checks
    
    private func checkSecurityEnvironment() {
        var isSecure = true
        
        // Check if device is jailbroken
        if isJailbroken() {
            isSecure = false
            logSecurityEvent("Jailbroken device detected")
        }
        
        // Check if debugging is enabled
        if isDebugging() {
            isSecure = false
            logSecurityEvent("Debugging detected")
        }
        
        // Check if running in simulator
        if isSimulator() {
            isSecure = false
            logSecurityEvent("Running in simulator")
        }
        
        // Check SSL pinning
        if !isSSLPinningEnabled() {
            isSecure = false
            logSecurityEvent("SSL pinning not enabled")
        }
        
        isSecureEnvironment = isSecure
        lastSecurityCheck = Date()
    }
    
    private func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak paths
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if we can write to system directories
        do {
            let testString = "test"
            try testString.write(toFile: "/private/test.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/test.txt")
            return true
        } catch {
            // Cannot write to system directory - good
        }
        
        // Check for suspicious URLs
        if UIApplication.shared.canOpenURL(URL(string: "cydia://package/com.example.package")!) {
            return true
        }
        
        return false
        #endif
    }
    
    private func isDebugging() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        
        return result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    private func isSimulator() -> Bool {
        return TARGET_OS_SIMULATOR != 0
    }
    
    private func isSSLPinningEnabled() -> Bool {
        return Config.Security.enableSSLPinning
    }
    
    // MARK: - Biometric Authentication
    
    private func checkBiometricAvailability() {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        biometricAuthenticationEnabled = available && error == nil
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        guard biometricAuthenticationEnabled else {
            throw PaymentSecurityError.biometricNotAvailable
        }
        
        let reason = "Authenticate to access payment information"
        
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return result
        } catch {
            throw PaymentSecurityError.biometricAuthenticationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Data Protection
    
    func securelyStorePaymentData(_ data: Data, for key: String) throws {
        guard isSecureEnvironment else {
            throw PaymentSecurityError.insecureEnvironment
        }
        
        let encryptedData = try encrypt(data)
        try keychain.set(encryptedData, forKey: key)
    }
    
    func securelyRetrievePaymentData(for key: String) throws -> Data? {
        guard isSecureEnvironment else {
            throw PaymentSecurityError.insecureEnvironment
        }
        
        guard let encryptedData = try keychain.get(key) else {
            return nil
        }
        
        return try decrypt(encryptedData)
    }
    
    func securelyDeletePaymentData(for key: String) throws {
        try keychain.delete(key)
    }
    
    // MARK: - Encryption/Decryption
    
    private func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()\n        let sealedBox = try AES.GCM.seal(data, using: key)\n        return sealedBox.combined!\n    }\n    \n    private func decrypt(_ encryptedData: Data) throws -> Data {\n        let key = try getOrCreateEncryptionKey()\n        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)\n        return try AES.GCM.open(sealedBox, using: key)\n    }\n    \n    private func getOrCreateEncryptionKey() throws -> SymmetricKey {\n        let keyData: Data\n        \n        if let existingKey = try keychain.get("payment_encryption_key") {\n            keyData = existingKey\n        } else {\n            keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }\n            try keychain.set(keyData, forKey: "payment_encryption_key")\n        }\n        \n        return SymmetricKey(data: keyData)\n    }\n    \n    // MARK: - Request Validation\n    \n    func validatePaymentRequest(_ request: PaymentRequest) throws {\n        guard isSecureEnvironment else {\n            throw PaymentSecurityError.insecureEnvironment\n        }\n        \n        // Validate amount\n        guard request.amount > 0 && request.amount <= 999999.99 else {\n            throw PaymentSecurityError.invalidAmount\n        }\n        \n        // Validate currency\n        guard ["USD", "EUR", "GBP", "CAD", "AUD"].contains(request.currency) else {\n            throw PaymentSecurityError.invalidCurrency\n        }\n        \n        // Validate customer ID format\n        guard request.customerId.count >= 8 && request.customerId.count <= 64 else {\n            throw PaymentSecurityError.invalidCustomerId\n        }\n        \n        // Check for suspicious patterns\n        if containsSuspiciousPatterns(request) {\n            throw PaymentSecurityError.suspiciousActivity\n        }\n    }\n    \n    private func containsSuspiciousPatterns(_ request: PaymentRequest) -> Bool {\n        // Check for common fraud patterns\n        let suspiciousPatterns = [\n            "test",\n            "fraud",\n            "script",\n            "injection",\n            "eval",\n            "javascript"\n        ]\n        \n        let requestString = "\\(request.amount)\\(request.currency)\\(request.customerId)"\n        \n        for pattern in suspiciousPatterns {\n            if requestString.lowercased().contains(pattern) {\n                return true\n            }\n        }\n        \n        return false\n    }\n    \n    // MARK: - Rate Limiting\n    \n    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]\n    private let maxRequestsPerMinute = 10\n    \n    func checkRateLimit(for userId: String) throws {\n        let now = Date()\n        \n        if let existing = requestCounts[userId] {\n            if now < existing.resetTime {\n                if existing.count >= maxRequestsPerMinute {\n                    throw PaymentSecurityError.rateLimitExceeded\n                }\n                requestCounts[userId] = (existing.count + 1, existing.resetTime)\n            } else {\n                // Reset window\n                requestCounts[userId] = (1, now.addingTimeInterval(60))\n            }\n        } else {\n            requestCounts[userId] = (1, now.addingTimeInterval(60))\n        }\n    }\n    \n    // MARK: - Input Sanitization\n    \n    func sanitizeInput(_ input: String) -> String {\n        var sanitized = input\n        \n        // Remove potentially dangerous characters\n        let dangerousCharacters = CharacterSet(charactersIn: "<>\"'&;()")\n        sanitized = sanitized.components(separatedBy: dangerousCharacters).joined()\n        \n        // Limit length\n        if sanitized.count > 1000 {\n            sanitized = String(sanitized.prefix(1000))\n        }\n        \n        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)\n    }\n    \n    // MARK: - Logging and Monitoring\n    \n    private func logSecurityEvent(_ event: String) {\n        let securityEvent = SecurityEvent(\n            timestamp: Date(),\n            event: event,\n            severity: .warning,\n            userId: getCurrentUserId(),\n            deviceId: getDeviceId()\n        )\n        \n        // Log to analytics\n        AnalyticsManager.shared.track(event: "security_event", properties: [\n            "event": event,\n            "severity": securityEvent.severity.rawValue,\n            "timestamp": securityEvent.timestamp.timeIntervalSince1970\n        ])\n        \n        // Log to Sentry\n        SentryManager.shared.captureMessage(event, level: .warning)\n    }\n    \n    func logPaymentEvent(_ event: String, amount: Double, currency: String, success: Bool) {\n        let paymentEvent = PaymentEvent(\n            timestamp: Date(),\n            event: event,\n            amount: amount,\n            currency: currency,\n            success: success,\n            userId: getCurrentUserId(),\n            deviceId: getDeviceId()\n        )\n        \n        // Log to analytics\n        AnalyticsManager.shared.track(event: "payment_event", properties: [\n            "event": event,\n            "amount": amount,\n            "currency": currency,\n            "success": success,\n            "timestamp": paymentEvent.timestamp.timeIntervalSince1970\n        ])\n        \n        // Log to Sentry\n        if !success {\n            SentryManager.shared.captureMessage("Payment failed: \\(event)", level: .error)\n        }\n    }\n    \n    // MARK: - Helper Methods\n    \n    private func getCurrentUserId() -> String {\n        return ProfileManager.shared.currentUser?.id ?? "anonymous"\n    }\n    \n    private func getDeviceId() -> String {\n        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"\n    }\n    \n    // MARK: - Periodic Security Checks\n    \n    func performPeriodicSecurityCheck() async {\n        checkSecurityEnvironment()\n        checkBiometricAvailability()\n        \n        // Clean up old request counts\n        let now = Date()\n        requestCounts = requestCounts.filter { $0.value.resetTime > now }\n        \n        // Validate stored payment data integrity\n        await validateStoredDataIntegrity()\n    }\n    \n    private func validateStoredDataIntegrity() async {\n        // Check if keychain data is still accessible and valid\n        do {\n            let _ = try getOrCreateEncryptionKey()\n        } catch {\n            logSecurityEvent("Encryption key validation failed")\n        }\n    }\n}\n\n// MARK: - Supporting Models\n\nstruct PaymentRequest {\n    let amount: Double\n    let currency: String\n    let customerId: String\n    let description: String?\n    let metadata: [String: String]\n}\n\nstruct SecurityEvent {\n    let timestamp: Date\n    let event: String\n    let severity: SecuritySeverity\n    let userId: String\n    let deviceId: String\n}\n\nstruct PaymentEvent {\n    let timestamp: Date\n    let event: String\n    let amount: Double\n    let currency: String\n    let success: Bool\n    let userId: String\n    let deviceId: String\n}\n\nenum SecuritySeverity: String {\n    case info = "info"\n    case warning = "warning"\n    case error = "error"\n    case critical = "critical"\n}\n\n// MARK: - Security Errors\n\nenum PaymentSecurityError: Error, LocalizedError {\n    case insecureEnvironment\n    case biometricNotAvailable\n    case biometricAuthenticationFailed(String)\n    case invalidAmount\n    case invalidCurrency\n    case invalidCustomerId\n    case suspiciousActivity\n    case rateLimitExceeded\n    case encryptionFailed\n    case decryptionFailed\n    case keychainError\n    \n    var errorDescription: String? {\n        switch self {\n        case .insecureEnvironment:\n            return "Insecure environment detected"\n        case .biometricNotAvailable:\n            return "Biometric authentication not available"\n        case .biometricAuthenticationFailed(let reason):\n            return "Biometric authentication failed: \\(reason)"\n        case .invalidAmount:\n            return "Invalid payment amount"\n        case .invalidCurrency:\n            return "Invalid currency"\n        case .invalidCustomerId:\n            return "Invalid customer ID"\n        case .suspiciousActivity:\n            return "Suspicious activity detected"\n        case .rateLimitExceeded:\n            return "Rate limit exceeded"\n        case .encryptionFailed:\n            return "Encryption failed"\n        case .decryptionFailed:\n            return "Decryption failed"\n        case .keychainError:\n            return "Keychain error"\n        }\n    }\n}\n\n// MARK: - Keychain Wrapper\n\nclass Keychain {\n    static let shared = Keychain()\n    \n    private init() {}\n    \n    func set(_ data: Data, forKey key: String) throws {\n        let query: [String: Any] = [\n            kSecClass as String: kSecClassGenericPassword,\n            kSecAttrAccount as String: key,\n            kSecValueData as String: data,\n            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly\n        ]\n        \n        SecItemDelete(query as CFDictionary)\n        \n        let status = SecItemAdd(query as CFDictionary, nil)\n        guard status == errSecSuccess else {\n            throw PaymentSecurityError.keychainError\n        }\n    }\n    \n    func get(_ key: String) throws -> Data? {\n        let query: [String: Any] = [\n            kSecClass as String: kSecClassGenericPassword,\n            kSecAttrAccount as String: key,\n            kSecReturnData as String: true,\n            kSecMatchLimit as String: kSecMatchLimitOne\n        ]\n        \n        var result: AnyObject?\n        let status = SecItemCopyMatching(query as CFDictionary, &result)\n        \n        guard status == errSecSuccess else {\n            if status == errSecItemNotFound {\n                return nil\n            }\n            throw PaymentSecurityError.keychainError\n        }\n        \n        return result as? Data\n    }\n    \n    func delete(_ key: String) throws {\n        let query: [String: Any] = [\n            kSecClass as String: kSecClassGenericPassword,\n            kSecAttrAccount as String: key\n        ]\n        \n        let status = SecItemDelete(query as CFDictionary)\n        guard status == errSecSuccess || status == errSecItemNotFound else {\n            throw PaymentSecurityError.keychainError\n        }\n    }\n}\n\n// MARK: - Environment Key\n\nstruct PaymentSecurityManagerKey: EnvironmentKey {\n    static let defaultValue = PaymentSecurityManager.shared\n}\n\nextension EnvironmentValues {\n    var paymentSecurityManager: PaymentSecurityManager {\n        get { self[PaymentSecurityManagerKey.self] }\n        set { self[PaymentSecurityManagerKey.self] = newValue }\n    }\n}