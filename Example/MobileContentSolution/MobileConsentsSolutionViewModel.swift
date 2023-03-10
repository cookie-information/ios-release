import UIKit
import MobileConsentsSDK


final class MobileConsentSolutionViewModel {
    public var mobileConsentsSDK = MobileConsents(clientID: "40dbe5a7-1c01-463a-bb08-a76970c0efa0",
                                                   clientSecret: "bfa6f31561827fbc59c5d9dc0b04bdfd9752305ce814e87533e61ea90f9f8da8743c376074e372d3386c2a608c267fe1583472fe6369e3fa9cf0082f7fe2d56d",
                                                  solutionId: "4113ab88-4980-4429-b2d1-3454cc81197b",
                                                  accentColor: .systemGreen,
                                                   fontSet: FontSet(largeTitle: .boldSystemFont(ofSize: 34),
                                                                    body: .monospacedSystemFont(ofSize: 14, weight: .regular),
                                                                    bold: .monospacedSystemFont(ofSize: 14, weight: .bold))
                                                                )
    
    
    
    private var selectedItems: [ConsentItem] = []
    private var language: String?
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
        mobileConsentsSDK = MobileConsents(clientID: "40dbe5a7-1c01-463a-bb08-a76970c0efa0",
                                           clientSecret: "bfa6f31561827fbc59c5d9dc0b04bdfd9752305ce814e87533e61ea90f9f8da8743c376074e372d3386c2a608c267fe1583472fe6369e3fa9cf0082f7fe2d56d",
                                          solutionId: "4113ab88-4980-4429-b2d1-3454cc81197b",
                                           accentColor: style.accentColor,
                                           fontSet: style.fontSet
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
