Pod::Spec.new do |spec|
  spec.name         = 'MobileConsentsSDK'
  spec.version      = '1.4.1'
  spec.platform = :ios, '11.0'
  spec.summary      = 'Cookie information iOS SDK'
  spec.homepage     = 'https://github.com/cookie-information/ios-release'
  spec.author       = 'Cookie Information'
  spec.source       = { :git => 'https://github.com/cookie-information/ios-release.git', :tag => spec.version.to_s }
  
  spec.source_files = 'Sources/MobileConsentsSDK/**/*.swift'
  spec.swift_version = '5.0'

end