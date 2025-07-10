//
//  Config.swift
//  StreamyyyApp
//
//  Configuration file for API keys and endpoints
//

import Foundation

struct Config {
    // MARK: - Clerk Configuration
    struct Clerk {
        static let publishableKey = "pk_live_Y2xlcmsuc3RyZWFteXl5LmNvbSQ"
        static let secretKey = "sk_test_RQc3HdVhrlsURQMw3EosutCsMDJUnbRm9VdHkD4Vts"
        static let webhookSecret = "whsec_1OXhtTgzKkZOoggp3KK00Uq6p7I7pkxw"
        static let signInUrl = "/sign-in"
        static let signUpUrl = "/sign-up"
        static let afterSignInUrl = "/"
        static let afterSignUpUrl = "/"
        
        // OAuth Providers
        static let enabledProviders = ["oauth_google", "oauth_apple", "oauth_github"]
    }
    
    // MARK: - Sentry Configuration
    struct Sentry {
        static let dsn = "YOUR_SENTRY_DSN_HERE"
        static let environment = isProduction ? "production" : "development"
        static let release = "\(App.name)@\(App.version)+\(App.build)"
        static let debug = !isProduction
        static let tracesSampleRate = 1.0
    }
    
    // MARK: - Supabase Configuration
    struct Supabase {
        static let url = "https://wzqtfzxcfhccvhomitau.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6cXRmenhxZmhjY3Zob21pdGF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY0NzY1MjcsImV4cCI6MjA1MjA1MjUyN30.1ZYpRdGiQXjLLUAGgqTNxNWUNZj8tYrjUYjKjHqVjg"
        static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrd3ZtbGpvcHVjc25vcnZkd3V1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NDc1MjUzMiwiZXhwIjoyMDYwMzI4NTMyfQ.J-LVAtCa116zSmNBPe5WnYw1eL09VWL9qvlc-kGFU6s"
        
        // Database Tables
        static let usersTable = "users"
        static let streamsTable = "streams"
        static let favoritesTable = "favorites"
        static let subscriptionsTable = "subscriptions"
    }
    
    // MARK: - Twitch Configuration
    struct Twitch {
        static let clientId = "840q0uzqa2ny9oob3yp8ako6dqs31g"
        static let clientSecret = "6359is1cljkasakhaobken9r0shohc"
        static let redirectUri = "streamyyy://auth/twitch/callback"
        
        // API Endpoints
        static let baseURL = "https://api.twitch.tv/helix"
        static let authURL = "https://id.twitch.tv/oauth2"
        
        // Scopes
        static let scopes = ["user:read:email", "user:read:follows"]
        
        // Stream Categories
        static let popularGameIds = [
            "509658", // Just Chatting
            "32982",  // Grand Theft Auto V
            "21779",  // League of Legends
            "33214",  // Fortnite
            "512710", // Call of Duty: Warzone
            "518203", // Sports
            "27471",  // Minecraft
            "29595",  // Dota 2
            "511224", // Apex Legends
            "18122"   // World of Warcraft
        ]
    }
    
    // MARK: - Stripe Configuration
    struct Stripe {
        static let publishableKey = "YOUR_STRIPE_PUBLISHABLE_KEY_HERE"
        static let merchantIdentifier = "merchant.com.streamyyy.app"
        
        // Product IDs
        static let monthlyPlanId = "streamyyy_pro_monthly"
        static let yearlyPlanId = "streamyyy_pro_yearly"
        
        // Pricing
        static let monthlyPrice = 9.99
        static let yearlyPrice = 99.99
    }
    
    // MARK: - Firebase Configuration (Optional)
    struct Firebase {
        static let projectId = "YOUR_FIREBASE_PROJECT_ID"
        static let apiKey = "YOUR_FIREBASE_API_KEY"
    }
    
    // MARK: - API Endpoints
    struct API {
        static let baseURL = "https://api.streamyyy.com"
        static let twitchAPI = "https://api.twitch.tv/helix"
        static let youtubeAPI = "https://www.googleapis.com/youtube/v3"
        static let kickAPI = "https://kick.com/api/v1"
    }
    
    // MARK: - App Configuration
    struct App {
        static let name = "Streamyyy"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        // Feature Flags
        static let enablePictureInPicture = true
        static let enableNotifications = true
        static let enableAnalytics = true
        
        // Limits
        static let maxStreamsForFreeUsers = 4
        static let maxStreamsForProUsers = 20
        static let maxFavorites = 100
    }
    
    // MARK: - Stream Platforms
    struct Platforms {
        static let supported = ["twitch", "youtube", "kick", "discord", "facebook", "instagram"]
        
        struct Twitch {
            static let baseURL = "https://www.twitch.tv"
            static let embedURL = "https://player.twitch.tv"
            static let embedJSURL = "https://embed.twitch.tv/embed/v1.js"
            static let clientId = "840q0uzqa2ny9oob3yp8ako6dqs31g"
            static let clientSecret = "6359is1cljkasakhaobken9r0shohc"
            static let parentDomain = "streamyyy.com"
            static let redirectURI = "streamyyy://oauth/twitch"
            
            // iOS WebView specific configuration
            static let iOSEmbedApproach = "html_wrapper" // html_wrapper, iframe, or direct
            static let allowAutoplay = true
            static let defaultMuted = false
            static let defaultQuality = "auto"
            static let enableChat = true
            static let enableLowLatency = true
            static let enableClips = true
            static let enableVOD = true
            
            // Stream quality options
            static let supportedQualities = ["auto", "source", "720p60", "720p", "480p", "360p", "160p"]
            
            // API Scopes
            static let scopes = [
                "user:read:email",
                "user:read:follows",
                "user:read:subscriptions",
                "clips:edit",
                "chat:read",
                "chat:edit"
            ]
        }
        
        struct YouTube {
            static let baseURL = "https://www.youtube.com"
            static let embedURL = "https://www.youtube.com/embed"
            static let apiKey = "YOUR_YOUTUBE_API_KEY"
            static let clientId = "YOUR_YOUTUBE_CLIENT_ID"
            static let clientSecret = "YOUR_YOUTUBE_CLIENT_SECRET"
            static let redirectURI = "streamyyy://oauth/youtube"
            
            // Supported content types
            static let supportedTypes = ["live", "video", "playlist", "channel"]
            
            // API Scopes
            static let scopes = [
                "https://www.googleapis.com/auth/youtube.readonly",
                "https://www.googleapis.com/auth/youtube.force-ssl"
            ]
        }
        
        struct Kick {
            static let baseURL = "https://kick.com"
            static let embedURL = "https://player.kick.com"
            static let apiURL = "https://kick.com/api/v1"
            static let websocketURL = "wss://ws-us2.pusher.app"
            
            // Chat configuration
            static let enableChat = true
            static let chatRateLimit = 1.0 // seconds between messages
        }
        
        struct Discord {
            static let baseURL = "https://discord.com"
            static let apiURL = "https://discord.com/api/v10"
            static let clientId = "YOUR_DISCORD_CLIENT_ID"
            static let clientSecret = "YOUR_DISCORD_CLIENT_SECRET"
            static let redirectURI = "streamyyy://oauth/discord"
            
            // Bot configuration
            static let enableBot = true
            static let botToken = "YOUR_DISCORD_BOT_TOKEN"
            
            // Scopes
            static let scopes = ["identify", "guilds", "guilds.join"]
        }
        
        struct Facebook {
            static let baseURL = "https://www.facebook.com"
            static let apiURL = "https://graph.facebook.com/v18.0"
            static let appId = "YOUR_FACEBOOK_APP_ID"
            static let appSecret = "YOUR_FACEBOOK_APP_SECRET"
            static let redirectURI = "streamyyy://oauth/facebook"
            
            // Permissions
            static let permissions = ["public_profile", "email", "user_videos"]
        }
        
        struct Instagram {
            static let baseURL = "https://www.instagram.com"
            static let apiURL = "https://graph.instagram.com"
            static let clientId = "YOUR_INSTAGRAM_CLIENT_ID"
            static let clientSecret = "YOUR_INSTAGRAM_CLIENT_SECRET"
            static let redirectURI = "streamyyy://oauth/instagram"
            
            // Basic Display API scopes
            static let scopes = ["user_profile", "user_media"]
        }
    }
    
    // MARK: - URLs
    struct URLs {
        static let privacyPolicy = "https://streamyyy.com/privacy"
        static let termsOfService = "https://streamyyy.com/terms"
        static let support = "https://streamyyy.com/support"
        static let website = "https://streamyyy.com"
        static let appStore = "https://apps.apple.com/app/streamyyy/id123456789"
    }
    
    // MARK: - WebKit Configuration
    struct WebKit {
        static let enableJavaScript = true
        static let enableJavaScriptCanOpenWindowsAutomatically = false
        static let enableMediaPlaybackRequiresUserAction = false
        static let enableAllowsInlineMediaPlayback = true
        static let enableAllowsAirPlayForMediaPlayback = true
        static let enableAllowsPictureInPictureMediaPlayback = true
        static let enableSuppressesIncrementalRendering = false
        static let enableIgnoresViewportScaleLimits = false
        static let enableTextInteractionEnabled = true
        static let enableDataDetectorTypes = true
        static let enableDragInteraction = true
        static let enableScrolling = true
        static let enableBouncing = true
        static let enableZooming = true
        static let javaScriptEnabled = true
        static let domStorageEnabled = true
        static let allowsBackForwardNavigationGestures = true
        static let allowsLinkPreview = true
        static let customUserAgent = "StreamyyyApp/1.0.0 (iOS)"
        
        // Content blocking and security
        static let blockPopups = true
        static let blockAds = false  // Set to true if you want to block ads
        static let enablePrivateBrowsing = false
        static let fraudulentWebsiteWarning = true
        
        // Media configuration
        static let allowsInlineMediaPlayback = true
        static let mediaPlaybackRequiresUserAction = false
        static let mediaPlaybackAllowsAirPlay = true
        static let mediaTypesRequiringUserActionForPlayback: [String] = []
        
        // Performance settings
        static let enableCaching = true
        static let cacheSize = 100 * 1024 * 1024 // 100MB
        static let clearCacheOnAppLaunch = false
        static let processPoolSizeLimit = 4
    }
    
    // MARK: - Push Notifications Configuration
    struct Notifications {
        static let enablePushNotifications = true
        static let enableBadgeUpdates = true
        static let enableSoundAlerts = true
        static let enableVibration = true
        
        // Notification categories
        static let categories = [
            "stream_live": "Stream Live",
            "stream_offline": "Stream Offline",
            "new_follower": "New Follower",
            "subscription_expires": "Subscription Expires",
            "system_update": "System Update"
        ]
        
        // Firebase Cloud Messaging
        static let fcmEnabled = true
        static let fcmSenderId = "YOUR_FCM_SENDER_ID"
        static let fcmServerKey = "YOUR_FCM_SERVER_KEY"
        
        // Apple Push Notification Service
        static let apnsEnabled = true
        static let apnsEnvironment = isProduction ? "production" : "development"
        static let apnsKeyId = "YOUR_APNS_KEY_ID"
        static let apnsTeamId = "YOUR_APNS_TEAM_ID"
        static let apnsPrivateKey = "YOUR_APNS_PRIVATE_KEY"
    }
    
    // MARK: - SwiftData Configuration
    struct SwiftData {
        static let enableCloudKitSync = true
        static let cloudKitContainerIdentifier = "iCloud.com.streamyyy.app"
        static let enablePersistentHistory = true
        static let enableRemoteChangeNotifications = true
        static let enableAutomaticMigration = true
        static let enableLightweightMigration = true
        
        // Storage settings
        static let enableExternalBinaryDataStorage = true
        static let enableDeduplication = true
        static let enableCompression = true
        
        // Performance settings
        static let batchSize = 50
        static let fetchLimit = 100
        static let prefetchRelationships = true
        static let enableAsyncFetching = true
        
        // Backup and restore
        static let enableAutoBackup = true
        static let backupInterval = 24 * 60 * 60 // 24 hours in seconds
        static let maxBackupFiles = 7
    }
    
    // MARK: - Analytics Configuration
    struct Analytics {
        static let enableAnalytics = true
        static let enableCrashReporting = true
        static let enablePerformanceMonitoring = true
        static let enableNetworkMonitoring = true
        static let enableUserTracking = false // Privacy-focused
        
        // Data collection settings
        static let collectDeviceInfo = true
        static let collectAppUsage = true
        static let collectNetworkStats = true
        static let collectPerformanceMetrics = true
        
        // Retention and privacy
        static let dataRetentionDays = 90
        static let enableDataAnonymization = true
        static let enableOptOut = true
        static let respectDNT = true // Do Not Track
    }
    
    // MARK: - Performance Configuration
    struct Performance {
        static let enableLazyLoading = true
        static let enableImageCaching = true
        static let enableMemoryWarningHandling = true
        static let enableBackgroundTasking = true
        static let enablePreloading = true
        
        // Memory management
        static let maxMemoryUsage = 256 * 1024 * 1024 // 256MB
        static let enableMemoryPressureHandling = true
        static let enableAutomaticMemoryCleanup = true
        static let memoryCleanupInterval = 5 * 60 // 5 minutes
        
        // Network optimization
        static let enableNetworkCaching = true
        static let enableImageCompression = true
        static let maxConcurrentDownloads = 6
        static let requestTimeout = 30.0
        static let enableRetryLogic = true
        static let maxRetryAttempts = 3
        
        // UI performance
        static let enableViewCaching = true
        static let enableAnimationOptimization = true
        static let enableVirtualization = true
        static let enableAsyncRendering = true
    }
    
    // MARK: - Security Configuration
    struct Security {
        static let enableSSLPinning = true
        static let enableCertificateValidation = true
        static let enableTrustEvaluation = true
        static let enableHSTS = true // HTTP Strict Transport Security
        
        // Authentication security
        static let enableBiometricAuthentication = true
        static let enableTwoFactorAuthentication = true
        static let enableTokenRefresh = true
        static let tokenExpirationTime = 24 * 60 * 60 // 24 hours
        
        // Data protection
        static let enableDataProtection = true
        static let enableKeychainSync = true
        static let enableSecureStorage = true
        static let enableEncryption = true
        
        // API security
        static let enableAPIKeyRotation = true
        static let enableRateLimiting = true
        static let enableRequestSigning = true
        static let enableIPWhitelisting = false
        
        // Privacy protection
        static let enablePrivacyMode = false
        static let enableDataMinimization = true
        static let enableConsentManagement = true
        static let enableCookieControl = true
    }
    
    // MARK: - Development Configuration
    #if DEBUG
    struct Development {
        static let enableLogging = true
        static let enableMockData = false
        static let skipOnboarding = false
        static let autoLogin = false
        static let enableDebugMenu = true
        static let enableNetworkLogging = true
        static let enablePerformanceLogging = true
        static let enableMemoryLogging = true
        static let enableUIDebugging = true
        static let enableSwiftUIPreview = true
        static let enableTestingMode = false
        static let enableBetaFeatures = true
        static let enableExperimentalFeatures = false
        
        // Test configuration
        static let enableUITesting = false
        static let enableUnitTesting = false
        static let enableIntegrationTesting = false
        static let enablePerformanceTesting = false
        
        // Mock data settings
        static let useMockStreams = false
        static let useMockUsers = false
        static let useMockSubscriptions = false
        static let useMockNotifications = false
        
        // Development servers
        static let useLocalServer = false
        static let localServerURL = "http://localhost:3000"
        static let enableHotReload = true
        static let enableLiveReload = true
    }
    #endif
}

// MARK: - Configuration Validation
extension Config {
    static func validateConfiguration() -> Bool {
        guard !Supabase.url.contains("YOUR_"),
              !Supabase.anonKey.contains("YOUR_"),
              !Stripe.publishableKey.contains("YOUR_") else {
            print("⚠️ Warning: Please configure your API keys in Config.swift")
            return false
        }
        return true
    }
    
    static func printConfiguration() {
        #if DEBUG
        print("📱 App Configuration:")
        print("   Name: \(App.name)")
        print("   Version: \(App.version) (\(App.build))")
        print("   Supabase URL: \(Supabase.url.prefix(20))...")
        print("   Stripe Key: \(Stripe.publishableKey.prefix(20))...")
        print("   Max Streams (Free): \(App.maxStreamsForFreeUsers)")
        print("   Max Streams (Pro): \(App.maxStreamsForProUsers)")
        #endif
    }
}

// MARK: - Environment Detection
extension Config {
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    static var isTestFlight: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("sandboxReceipt")
    }
    
    static var isAppStore: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("receipt")
    }
}