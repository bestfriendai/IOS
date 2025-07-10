//
//  UserExtensions.swift
//  StreamyyyApp
//
//  User model extensions for UI, validation, and API
//

import Foundation
import SwiftUI
// import ClerkSDK // Commented out until SDK is properly integrated

// MARK: - User UI Extensions
extension User {
    
    // MARK: - Avatar and Profile
    public var avatarImage: Image {
        if let profileImageURL = profileImageURL {
            return Image(systemName: "person.crop.circle.fill")
                .foregroundColor(.blue)
        } else {
            return Image(systemName: "person.crop.circle")
                .foregroundColor(.gray)
        }
    }
    
    public var profileBackgroundColor: Color {
        // Generate consistent color based on user ID
        let hash = id.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .cyan]
        return colors[abs(hash) % colors.count]
    }
    
    public var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    public var subscriptionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: subscriptionStatus.icon)
                .foregroundColor(subscriptionStatus.color)
            
            Text(subscriptionStatus.displayName)
                .font(.caption)
                .foregroundColor(subscriptionStatus.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(subscriptionStatus.color.opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Stats Views
    public var statsView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Streams")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(streams.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Favorites")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(favorites.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Joined")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lastSeenFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Validation Helpers
    public var validationErrors: [String] {
        var errors: [String] = []
        
        if !validateEmail() {
            errors.append("Invalid email address")
        }
        
        if let username = username, !username.isEmpty && !validateUsername() {
            errors.append("Username must be 3-20 characters and contain only letters, numbers, and underscores")
        }
        
        if let phoneNumber = phoneNumber, !phoneNumber.isEmpty && !validatePhoneNumber() {
            errors.append("Invalid phone number format")
        }
        
        return errors
    }
    
    public var isValidForCreation: Bool {
        return validateEmail() && !firstName.isEmptyOrNil && !lastName.isEmptyOrNil
    }
    
    public var completionPercentage: Double {
        let fields = [
            firstName,
            lastName,
            username,
            phoneNumber,
            profileImageURL
        ]
        
        let filledFields = fields.compactMap { $0 }.filter { !$0.isEmpty }
        return Double(filledFields.count) / Double(fields.count) * 100
    }
    
    // MARK: - Action Buttons
    public func editButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "pencil")
                Text("Edit Profile")
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    public func subscriptionButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isPremium ? "crown.fill" : "arrow.up.circle")
                Text(isPremium ? "Manage Subscription" : "Upgrade to Premium")
            }
            .foregroundColor(isPremium ? .orange : .blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background((isPremium ? Color.orange : Color.blue).opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Feature Access
    public func hasFeature(_ feature: UserFeature) -> Bool {
        switch feature {
        case .basicStreaming:
            return true
        case .unlimitedStreams:
            return isPremium
        case .advancedLayouts:
            return isPremium
        case .prioritySupport:
            return isPremium
        case .analytics:
            return isProUser
        case .customBranding:
            return isProUser
        case .apiAccess:
            return isProUser
        }
    }
    
    public func featureAccessView(for feature: UserFeature) -> some View {
        HStack {
            Image(systemName: hasFeature(feature) ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(hasFeature(feature) ? .green : .red)
            
            Text(feature.displayName)
                .foregroundColor(hasFeature(feature) ? .primary : .secondary)
            
            Spacer()
            
            if !hasFeature(feature) {
                Text("Premium")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - User API Extensions
extension User {
    
    // MARK: - API Serialization
    public func toAPIDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "created_at": createdAt.timeIntervalSince1970,
            "updated_at": updatedAt.timeIntervalSince1970,
            "last_active_at": lastActiveAt.timeIntervalSince1970,
            "is_email_verified": isEmailVerified,
            "is_phone_verified": isPhoneVerified,
            "timezone": timezone,
            "locale": locale,
            "subscription_status": subscriptionStatus.rawValue,
            "is_active": isActive,
            "is_banned": isBanned,
            "metadata": metadata
        ]
        
        if let clerkId = clerkId {
            dict["clerk_id"] = clerkId
        }
        
        if let firstName = firstName {
            dict["first_name"] = firstName
        }
        
        if let lastName = lastName {
            dict["last_name"] = lastName
        }
        
        if let username = username {
            dict["username"] = username
        }
        
        if let profileImageURL = profileImageURL {
            dict["profile_image_url"] = profileImageURL
        }
        
        if let phoneNumber = phoneNumber {
            dict["phone_number"] = phoneNumber
        }
        
        if let subscriptionId = subscriptionId {
            dict["subscription_id"] = subscriptionId
        }
        
        if let stripeCustomerId = stripeCustomerId {
            dict["stripe_customer_id"] = stripeCustomerId
        }
        
        if let banReason = banReason {
            dict["ban_reason"] = banReason
        }
        
        if let banExpiresAt = banExpiresAt {
            dict["ban_expires_at"] = banExpiresAt.timeIntervalSince1970
        }
        
        return dict
    }
    
    public static func fromAPIDict(_ dict: [String: Any]) -> User? {
        guard let id = dict["id"] as? String,
              let email = dict["email"] as? String,
              let createdAtTimestamp = dict["created_at"] as? TimeInterval else {
            return nil
        }
        
        let user = User(
            id: id,
            email: email,
            firstName: dict["first_name"] as? String,
            lastName: dict["last_name"] as? String,
            username: dict["username"] as? String,
            profileImageURL: dict["profile_image_url"] as? String,
            phoneNumber: dict["phone_number"] as? String,
            timezone: dict["timezone"] as? String ?? TimeZone.current.identifier,
            locale: dict["locale"] as? String ?? Locale.current.identifier
        )
        
        user.clerkId = dict["clerk_id"] as? String
        user.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        user.updatedAt = Date(timeIntervalSince1970: dict["updated_at"] as? TimeInterval ?? createdAtTimestamp)
        user.lastActiveAt = Date(timeIntervalSince1970: dict["last_active_at"] as? TimeInterval ?? createdAtTimestamp)
        user.isEmailVerified = dict["is_email_verified"] as? Bool ?? false
        user.isPhoneVerified = dict["is_phone_verified"] as? Bool ?? false
        user.isActive = dict["is_active"] as? Bool ?? true
        user.isBanned = dict["is_banned"] as? Bool ?? false
        user.subscriptionId = dict["subscription_id"] as? String
        user.stripeCustomerId = dict["stripe_customer_id"] as? String
        user.banReason = dict["ban_reason"] as? String
        user.metadata = dict["metadata"] as? [String: String] ?? [:]
        
        if let subscriptionStatusRaw = dict["subscription_status"] as? String {
            user.subscriptionStatus = SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free
        }
        
        if let banExpiresAtTimestamp = dict["ban_expires_at"] as? TimeInterval {
            user.banExpiresAt = Date(timeIntervalSince1970: banExpiresAtTimestamp)
        }
        
        return user
    }
    
    // MARK: - Clerk Integration (Mock)
    public func syncWithClerk() async throws {
        // Mock implementation - replace with actual Clerk integration
        print("Syncing with Clerk (mock)")
        updatedAt = Date()
    }
    
    public func updateClerkProfile() async throws {
        // Mock implementation - replace with actual Clerk integration
        print("Updating Clerk profile (mock)")
        updatedAt = Date()
    }
    
    // MARK: - Supabase Integration
    public func uploadToSupabase() async throws {
        // Implementation would depend on your Supabase setup
        // This is a placeholder for the actual implementation
        print("Uploading user to Supabase: \(id)")
    }
    
    public func updateInSupabase() async throws {
        // Implementation would depend on your Supabase setup
        print("Updating user in Supabase: \(id)")
    }
    
    // MARK: - Analytics
    public func trackEvent(_ event: UserAnalyticsEvent, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["user_id"] = id
        eventProperties["subscription_status"] = subscriptionStatus.rawValue
        eventProperties["is_premium"] = isPremium
        eventProperties["account_age_days"] = Int(accountAge / 86400)
        
        // Send to analytics service
        AnalyticsManager.shared.track(event.rawValue, properties: eventProperties)
    }
}

// MARK: - User Analytics Events
public enum UserAnalyticsEvent: String, CaseIterable {
    case profileCreated = "profile_created"
    case profileUpdated = "profile_updated"
    case subscriptionUpgraded = "subscription_upgraded"
    case subscriptionDowngraded = "subscription_downgraded"
    case subscriptionCanceled = "subscription_canceled"
    case streamAdded = "stream_added"
    case streamRemoved = "stream_removed"
    case favoriteAdded = "favorite_added"
    case favoriteRemoved = "favorite_removed"
    case settingsChanged = "settings_changed"
    case accountDeactivated = "account_deactivated"
    case accountReactivated = "account_reactivated"
    case loginSuccess = "login_success"
    case loginFailed = "login_failed"
    case logoutSuccess = "logout_success"
    
    public var displayName: String {
        switch self {
        case .profileCreated: return "Profile Created"
        case .profileUpdated: return "Profile Updated"
        case .subscriptionUpgraded: return "Subscription Upgraded"
        case .subscriptionDowngraded: return "Subscription Downgraded"
        case .subscriptionCanceled: return "Subscription Canceled"
        case .streamAdded: return "Stream Added"
        case .streamRemoved: return "Stream Removed"
        case .favoriteAdded: return "Favorite Added"
        case .favoriteRemoved: return "Favorite Removed"
        case .settingsChanged: return "Settings Changed"
        case .accountDeactivated: return "Account Deactivated"
        case .accountReactivated: return "Account Reactivated"
        case .loginSuccess: return "Login Success"
        case .loginFailed: return "Login Failed"
        case .logoutSuccess: return "Logout Success"
        }
    }
}

// MARK: - User Features
public enum UserFeature: String, CaseIterable {
    case basicStreaming = "basic_streaming"
    case unlimitedStreams = "unlimited_streams"
    case advancedLayouts = "advanced_layouts"
    case prioritySupport = "priority_support"
    case analytics = "analytics"
    case customBranding = "custom_branding"
    case apiAccess = "api_access"
    
    public var displayName: String {
        switch self {
        case .basicStreaming: return "Basic Streaming"
        case .unlimitedStreams: return "Unlimited Streams"
        case .advancedLayouts: return "Advanced Layouts"
        case .prioritySupport: return "Priority Support"
        case .analytics: return "Analytics"
        case .customBranding: return "Custom Branding"
        case .apiAccess: return "API Access"
        }
    }
    
    public var icon: String {
        switch self {
        case .basicStreaming: return "play.circle"
        case .unlimitedStreams: return "infinity.circle"
        case .advancedLayouts: return "grid.circle"
        case .prioritySupport: return "star.circle"
        case .analytics: return "chart.bar.circle"
        case .customBranding: return "paintbrush.circle"
        case .apiAccess: return "gearshape.circle"
        }
    }
}

// MARK: - Helper Extensions
extension String? {
    var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }
}

extension SubscriptionStatus {
    var icon: String {
        switch self {
        case .free: return "person.circle"
        case .premium: return "star.circle.fill"
        case .pro: return "crown.fill"
        }
    }
}