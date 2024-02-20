import Foundation
// defining the `module` bundle for cocoapods, but not for SPM
#if !SWIFT_PACKAGE
internal extension Bundle {
    static var module:Bundle {
        
        let podBundle = Bundle(for: MobileConsents.self)
        guard let bundleUrl = podBundle.url(forResource: "MobileConsentsSDK", withExtension: "bundle")
        else { return podBundle }
        
        return Bundle(url: bundleUrl) ?? podBundle
    }
}
#endif
