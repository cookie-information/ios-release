import Foundation
// defining the `module` bundle for cocoapods, but not for SPM
#if !SWIFT_PACKAGE
internal extension Bundle {
    static var module:Bundle {
        
        let podBundle = Bundle(for: MobileConsents.self)
        if let bundleUrl = podBundle.url(forResource: "MobileConsentsSDK", withExtension: "bundle") {
            return Bundle(url: bundleUrl )
        } else {
            return podBundle
        }
    }
}
#endif
