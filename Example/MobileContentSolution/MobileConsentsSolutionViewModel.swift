import UIKit
import MobileConsentsSDK


final class MobileConsentSolutionViewModel {
    public lazy var mobileConsentsSDK = MobileConsents(clientID: clientId,
                                                   clientSecret: clientSecret,
                                                  solutionId: solutionId,
                                                  accentColor: .systemGreen,
                                                   fontSet: FontSet(largeTitle: .boldSystemFont(ofSize: 34),
                                                                    body: .monospacedSystemFont(ofSize: 14, weight: .regular),
                                                                    bold: .monospacedSystemFont(ofSize: 14, weight: .bold)),
                                                    enableNetworkLogger: true)
    
    
    
    private var selectedItems: [ConsentItem] = []
    private var language: String?
    private var clientId = "40dbe5a7-1c01-463a-bb08-a76970c0efa0"
    private var clientSecret = "68cbf024407a20b8df4aecc3d9937f43c6e83169dafcb38b8d18296b515cc0d5f8bca8165d615caa4d12e236192851e9c5852a07319428562af8f920293bc1db"
    private var solutionId = "4113ab88-4980-4429-b2d1-3454cc81197b"
    
    private var items: [ConsentItem] {
        return consentSolution?.consentItems ?? []
    }
    
    private var sectionTypes: [MobileConsentsSolutionSectionType] {
        guard consentSolution != nil else { return [] }
    
        var sectionTypes: [MobileConsentsSolutionSectionType] = [.info]
        if !items.isEmpty {
            sectionTypes.append(.items)
        }
        return sectionTypes
    }

    var consentSolution: ConsentSolution?

    var savedConsents: [UserConsent] {
        return mobileConsentsSDK.getSavedConsents()
    }
    
    private var consent: Consent? {
        guard let consentSolution = consentSolution, let language = language else { return nil }
        
        let customData = ["email": "mobile@cookieinformation.com", "device_id": "824c259c-7bf5-4d2a-81bf-22c09af31261"]
        var consent = Consent(consentSolutionId: consentSolution.id, consentSolutionVersionId: consentSolution.versionId, customData: customData, userConsents: [UserConsent]())
        
        items.forEach { item in
            let selected = selectedItems.contains(where: { $0.id == item.id })
            let purpose = ProcessingPurpose(consentItemId: item.id, consentGiven: selected, language: language)
            consent.addProcessingPurpose(purpose)
        }
        
        return consent
    }
    
    
   
    
    func isItemSelected(_ item: ConsentItem) -> Bool {
        return selectedItems.contains(where: { $0.id == item.id })
    }
    
    func showPrivacyPopUp(style: PrivacyPopupStyle = .standard) {
        // Display the popup and provide a closure for handling the user constent.
        // This completion closure is the place to display
        mobileConsentsSDK = MobileConsents(clientID: clientId,
                                           clientSecret: clientSecret,
                                           solutionId: solutionId,
                                           accentColor: style.accentColor,
                                           fontSet: style.fontSet,
                                           enableNetworkLogger: true
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
