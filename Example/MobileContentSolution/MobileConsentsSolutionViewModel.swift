import UIKit
import SwiftUI
import MobileConsentsSDK


final class MobileConsentSolutionViewModel {
    public lazy var mobileConsentsSDK = MobileConsents(clientID: clientId,
                                                       clientSecret: clientSecret,
                                                       solutionId: solutionId,
                                                       localizationOverride: [Locale.init(identifier: "en"): LabelText(
                                                        title: "Data privacy",
                                                        readMoreScreenHeader: "Data privacy explained"
                                                       )],
                                                       enableNetworkLogger: true)
    
    
    
    private var selectedItems: [ConsentItem] = []
    private var language: String?
    private var clientId = "0dd4825b-8f7b-4fbc-8b41-b540ffc6d061"
    private var clientSecret = "8af460da2cddf7080c7d2975ddcbd5178a3f9e0e55a00373daae27c1441c806a40bd0948e97be0f700ed23c4428ca56661f4b68c5c98d03a7e8de8bb26dcdd7d"
    private var solutionId = "dbbb8fd5-d3e2-49df-8336-a1e6d68b683d"
    
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
                                           localizationOverride: [Locale.init(identifier: "en"): LabelText(
                                            title: "Data privacy"
                                           )],
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
    
    /// Presents the standalone (pure SwiftUI) variant, which uses the SDK's low-level
    /// API directly instead of the customViewType hook. In a SwiftUI app you would
    /// drive it with `.fullScreenCover` instead — see StandaloneConsentView docs.
    @available(iOS 15.0, *)
    func showStandaloneConsent(from presenter: UIViewController) {
        let store = ConsentStore(mobileConsents: mobileConsentsSDK)
        let host = UIHostingController(rootView: StandaloneConsentView(store: store))
        host.modalPresentationStyle = .fullScreen
        host.isModalInPresentation = true
        store.onFinished = { [weak host] consents in
            consents.forEach { print("Consent given for:\($0.purpose): \($0.isSelected)") }
            host?.dismiss(animated: true)
        }
        store.onError = { [weak host] error in
            print("Ooops, we've encountered an error: \(error.localizedDescription)")
            host?.dismiss(animated: true)
        }
        presenter.present(host, animated: true)
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

    static let brandCustomUI: PrivacyPopupStyle = {
        PrivacyPopupStyle(accentColor: ConsentColors.brandBlue, fontSet: .standard, customController: CustomConsentViewController.self)
    }()

    @available(iOS 15.0, *)
    static var brandCustomSwiftUI: PrivacyPopupStyle {
        PrivacyPopupStyle(accentColor: ConsentColors.brandBlue, fontSet: .standard, customController: CustomConsentSwiftUIController.self)
    }

}
