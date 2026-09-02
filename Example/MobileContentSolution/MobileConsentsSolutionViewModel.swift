import UIKit
import MobileConsentsSDK


final class MobileConsentSolutionViewModel {
    public lazy var mobileConsentsSDK = MobileConsents(clientID: clientId,
                                                       clientSecret: clientSecret,
                                                       solutionId: solutionId,
                                                       localizationOverride: [Locale.init(identifier: "en"): LabelText(
                                                        title: "Data privacy",
                                                        readMoreScreenHeader: "Data privacy explained"
                                                       )],
                                                       networkLoggingMode: .redactedRequestsAndResponses)
    
    
    
    private var clientId = "40dbe5a7-1c01-463a-bb08-a76970c0efa0"
    private var clientSecret = "68cbf024407a20b8df4aecc3d9937f43c6e83169dafcb38b8d18296b515cc0d5f8bca8165d615caa4d12e236192851e9c5852a07319428562af8f920293bc1db"
    private var solutionId = "4113ab88-4980-4429-b2d1-3454cc81197b"
    
    var savedConsents: [UserConsent] {
        return mobileConsentsSDK.getSavedConsents()
    }
    
    @MainActor
    func showPrivacyPopUp(style: PrivacyPopupStyle) {
        // Display the popup and provide a closure for handling the user constent.
        // This completion closure is the place to display
        mobileConsentsSDK = MobileConsents(clientID: clientId,
                                           clientSecret: clientSecret,
                                           solutionId: solutionId,
                                           accentColor: style.accentColor,
                                           fontSet: style.fontSet,
                                           localizationOverride: [Locale.init(identifier: "en"): LabelText(
                                            title: "Data privacy"
                                           )],
                                           networkLoggingMode: .redactedRequestsAndResponses
        )
        
        mobileConsentsSDK.showPrivacyPopUp(customViewType: style.customController) { settings in
            settings.forEach { consent in
                switch consent.purpose {
                case .statistical: break
                case .functional: break
                case .marketing: break
                case .necessary: break
                case .custom:
                    if consent.purposeDescription.lowercased() == "age consent" {
                        // handle user defined consent items such as age consent
                    }
                    if consent.consentItem.id == "<UUID of consent item>" {
                        // handle user defined consent items such as age consent based on it's UUID
                    }
                    
                }
                print("Consent given for:\(consent.purpose): \(consent.isSelected)")
            }
        } errorHandler: { err in
            print("Ooops, we've encountered an error: \(err.localizedDescription)")
        }        
    }
    
    func showPrivacyPopUpIfNeeded() {
        // Display the popup and provide a closure for handling the user constent.
        // This completion closure is the place to display
        
        mobileConsentsSDK.showPrivacyPopUpIfNeeded() { settings in
            settings.forEach { consent in
                switch consent.purpose {
                case .statistical: break
                case .functional: break
                case .marketing: break
                case .necessary: break
                case .custom:
                    if consent.purposeDescription.lowercased() == "age consent" {
                        // handle user defined consent items such as age consent
                    }
                }
                print("Consent given for:\(consent.purpose): \(consent.isSelected)")
            }
        } errorHandler: { err in
            print("Ooops, we've encountered an error: \(err.localizedDescription)")
        }
    }
    
}

@MainActor
struct PrivacyPopupStyle {
    var accentColor: UIColor
    var fontSet: FontSet
    var customController: PrivacyPopupProtocol.Type? = nil
    
    static let standard: PrivacyPopupStyle = {
        PrivacyPopupStyle(accentColor: .systemBlue, fontSet: .standard)
    }()
    
    static let greenTerminal: PrivacyPopupStyle = {
        PrivacyPopupStyle(accentColor:.systemGreen , fontSet: FontSet(largeTitle:.monospacedSystemFont(ofSize: 26, weight: .bold),
                                                                      body: .monospacedSystemFont(ofSize: 14, weight: .regular),
                                                                      bold: .monospacedSystemFont(ofSize: 14, weight: .bold)))
    }()
    
    static let pink: PrivacyPopupStyle = {
        PrivacyPopupStyle(accentColor: .systemPink, fontSet: .standard)
    }()
    
    static let customController: PrivacyPopupStyle = {
        PrivacyPopupStyle(accentColor: .systemPink, fontSet: .standard, customController: CustomPopup.self)
    }()
    
}
