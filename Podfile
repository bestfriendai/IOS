# Podfile for StreamyyyApp
# Alternative dependency management using CocoaPods

platform :ios, '15.0'
use_frameworks!
inhibit_all_warnings!

target 'StreamyyyApp' do
  # Supabase SDK
  pod 'Supabase', '~> 2.0'
  
  # Stripe SDK
  pod 'Stripe', '~> 23.0'
  pod 'StripePaymentSheet', '~> 23.0'
  
  # Image Loading and Caching
  pod 'Kingfisher', '~> 7.0'
  pod 'Nuke', '~> 12.0'
  
  # Networking
  pod 'Alamofire', '~> 5.8'
  
  # UI Enhancements
  pod 'lottie-ios', '~> 4.3'
  pod 'SwiftUIIntrospect', '~> 4.0'
  
  # Security
  pod 'KeychainAccess', '~> 4.2'
  
  # Firebase (Optional)
  pod 'Firebase/Analytics', '~> 10.0'
  pod 'Firebase/Crashlytics', '~> 10.0'
  pod 'Firebase/Performance', '~> 10.0'
  pod 'Firebase/RemoteConfig', '~> 10.0'
  
  # Development and Testing
  pod 'SwiftLint', '~> 0.52', :configurations => ['Debug']
  
  target 'StreamyyyAppTests' do
    inherit! :search_paths
    # Testing frameworks
    pod 'Quick', '~> 7.0'
    pod 'Nimble', '~> 12.0'
  end
  
  target 'StreamyyyAppUITests' do
    inherit! :search_paths
    # UI Testing frameworks
  end
end

# Post-install configuration
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Set minimum deployment target
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      
      # Enable bitcode
      config.build_settings['ENABLE_BITCODE'] = 'YES'
      
      # Optimize for size in release builds
      if config.name == 'Release'
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Osize'
      end
      
      # Fix warnings
      config.build_settings['WARNING_CFLAGS'] = '-Wno-everything'
      config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
      
      # Code signing
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end