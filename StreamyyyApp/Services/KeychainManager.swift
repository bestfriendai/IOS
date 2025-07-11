//
//  KeychainManager.swift
//  StreamyyyApp
//
//  Secure Keychain storage for authentication tokens and sensitive data
//

import Foundation
import Security
import CryptoKit

@MainActor
public class KeychainManager: ObservableObject {
    public static let shared = KeychainManager()
    
    private let service = "com.streamyyy.app"
    private let accessGroup = "com.streamyyy.app.shared"
    
    private init() {}
    
    // MARK: - Token Storage
    
    public enum TokenType: String {
        case clerkToken = "clerk_token"
        case clerkRefreshToken = "clerk_refresh_token"
        case twitchAccessToken = "twitch_access_token"
        case twitchRefreshToken = "twitch_refresh_token"
        case youtubeAccessToken = "youtube_access_token"
        case youtubeRefreshToken = "youtube_refresh_token"
        case supabaseToken = "supabase_token"
        case biometricSalt = "biometric_salt"
    }
    
    public enum UserDataType: String {
        case clerkUserId = "clerk_user_id"
        case userEmail = "user_email"
        case userProfile = "user_profile"
        case authState = "auth_state"
        case sessionData = "session_data"
    }
    
    // MARK: - Token Management
    
    public func storeToken(_ token: String, type: TokenType) throws {
        let tokenData = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.failedToStore
        }
    }
    
    public func retrieveToken(type: TokenType) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.failedToRetrieve
        }
        
        guard let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return token
    }
    
    public func deleteToken(type: TokenType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.failedToDelete
        }
    }
    
    // MARK: - User Data Storage
    
    public func storeUserData<T: Codable>(_ data: T, type: UserDataType) throws {
        let jsonData = try JSONEncoder().encode(data)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
            kSecValueData as String: jsonData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.failedToStore
        }
    }
    
    public func retrieveUserData<T: Codable>(type: UserDataType, as dataType: T.Type) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.failedToRetrieve
        }
        
        guard let jsonData = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return try JSONDecoder().decode(dataType, from: jsonData)
    }
    
    public func deleteUserData(type: UserDataType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.failedToDelete
        }
    }
    
    // MARK: - Biometric Authentication Support
    
    public func storeBiometricProtectedData<T: Codable>(_ data: T, type: UserDataType) throws {
        let jsonData = try JSONEncoder().encode(data)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(type.rawValue)_biometric",
            kSecValueData as String: jsonData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryAny,
                nil
            )!
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.biometricAuthFailed
        }
    }
    
    public func retrieveBiometricProtectedData<T: Codable>(type: UserDataType, as dataType: T.Type, reason: String) async throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(type.rawValue)_biometric",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: reason
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                
                DispatchQueue.main.async {
                    do {
                        guard status == errSecSuccess else {
                            if status == errSecItemNotFound {
                                continuation.resume(returning: nil)
                                return
                            }
                            throw KeychainError.biometricAuthFailed
                        }
                        
                        guard let jsonData = result as? Data else {
                            throw KeychainError.invalidData
                        }
                        
                        let decodedData = try JSONDecoder().decode(dataType, from: jsonData)
                        continuation.resume(returning: decodedData)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    public func storeAuthSession(_ session: AuthSession) throws {
        try storeUserData(session, type: .sessionData)
        try storeToken(session.accessToken, type: .clerkToken)
        if let refreshToken = session.refreshToken {
            try storeToken(refreshToken, type: .clerkRefreshToken)
        }
    }
    
    public func retrieveAuthSession() throws -> AuthSession? {
        return try retrieveUserData(type: .sessionData, as: AuthSession.self)
    }
    
    public func clearAuthSession() throws {
        try deleteUserData(type: .sessionData)
        try deleteToken(type: .clerkToken)
        try deleteToken(type: .clerkRefreshToken)
        try deleteUserData(type: .clerkUserId)
        try deleteUserData(type: .userEmail)
        try deleteUserData(type: .userProfile)
        try deleteUserData(type: .authState)
    }
    
    // MARK: - Bulk Operations
    
    public func clearAllData() throws {
        let tokenTypes: [TokenType] = [
            .clerkToken, .clerkRefreshToken,
            .twitchAccessToken, .twitchRefreshToken,
            .youtubeAccessToken, .youtubeRefreshToken,
            .supabaseToken, .biometricSalt
        ]
        
        let userDataTypes: [UserDataType] = [
            .clerkUserId, .userEmail, .userProfile,
            .authState, .sessionData
        ]
        
        for tokenType in tokenTypes {
            try deleteToken(type: tokenType)
        }
        
        for userDataType in userDataTypes {
            try deleteUserData(type: userDataType)
        }
    }
    
    // MARK: - Utility Methods
    
    public func isTokenStored(type: TokenType) -> Bool {
        do {
            return try retrieveToken(type: type) != nil
        } catch {
            return false
        }
    }
    
    public func isUserDataStored(type: UserDataType) -> Bool {
        do {
            return try retrieveUserData(type: type, as: String.self) != nil
        } catch {
            return false
        }
    }
    
    public func generateSecureRandom() -> String {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return data.base64EncodedString()
    }
}

// MARK: - Supporting Types

public struct AuthSession: Codable {
    let userId: String
    let email: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let createdAt: Date
    let deviceId: String
    
    public var isExpired: Bool {
        return Date() >= expiresAt
    }
    
    public var isValid: Bool {
        return !isExpired && !accessToken.isEmpty
    }
}

public enum KeychainError: Error, LocalizedError {
    case failedToStore
    case failedToRetrieve
    case failedToDelete
    case invalidData
    case biometricAuthFailed
    case tokenExpired
    case sessionInvalid
    
    public var errorDescription: String? {
        switch self {
        case .failedToStore:
            return "Failed to store data in Keychain"
        case .failedToRetrieve:
            return "Failed to retrieve data from Keychain"
        case .failedToDelete:
            return "Failed to delete data from Keychain"
        case .invalidData:
            return "Invalid data format in Keychain"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .tokenExpired:
            return "Authentication token has expired"
        case .sessionInvalid:
            return "Authentication session is invalid"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .failedToStore, .failedToRetrieve, .failedToDelete:
            return "Please try again or restart the app"
        case .invalidData:
            return "Please sign out and sign in again"
        case .biometricAuthFailed:
            return "Please use your device passcode or sign in again"
        case .tokenExpired, .sessionInvalid:
            return "Please sign in again"
        }
    }
}

// MARK: - Biometric Support Extensions

extension KeychainManager {
    
    public func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        default:
            return .none
        }
    }
}

public enum BiometricType {
    case none
    case touchID
    case faceID
    
    public var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        }
    }
    
    public var icon: String {
        switch self {
        case .none:
            return "lock"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        }
    }
}

