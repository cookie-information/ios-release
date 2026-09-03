Pod::Spec.new do |spec|
  spec.name         = 'MobileConsentsSDK'
  spec.version      = '2.0.0'
  spec.platform = :ios, '15.0'
  spec.summary      = 'Cookie information iOS SDK'
  spec.homepage     = 'https://github.com/cookie-information/ios-release'
  spec.author       = 'Cookie Information'
  spec.source       = { :git => 'https://github.com/cookie-information/ios-release.git', :tag => spec.version.to_s }
  
  spec.source_files = 'Sources/MobileConsentsSDK/**/*.swift'
  spec.resource_bundle = {'MobileConsentsSDK' => 'Sources/MobileConsentsSDK/Resources/*'}
  spec.libraries = 'sqlite3'
  spec.swift_version = '6.0'
  spec.pod_target_xcconfig = {
    'SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT' => 'YES',
    'SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES' => 'YES'
  }

end
