Pod::Spec.new do |spec|
  spec.name         = 'MobileConsentsSDK'
  spec.version      = '1.5.7'
  spec.platform = :ios, '11.0'
  spec.summary      = 'Cookie information iOS SDK'
  spec.homepage     = 'https://github.com/cookie-information/ios-release'
  spec.author       = 'Cookie Information'
  spec.source       = { :git => 'https://github.com/cookie-information/ios-release.git', :tag => spec.version.to_s }
  
  spec.source_files = 'Sources/MobileConsentsSDK/**/*.swift'
  spec.resource_bundle = {'MobileConsentsSDK' => 'Sources/MobileConsentsSDK/Resources/*'}
  spec.swift_version = '5.0'

end
