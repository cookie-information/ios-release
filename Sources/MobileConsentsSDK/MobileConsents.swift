import UIKit

protocol MobileConsentsProtocol {
    func fetchConsentSolution(completion: @escaping (Result<ConsentSolution, Error>) -> Void)
    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void)
    func getSavedConsents() -> [UserConsent]
}

@objc
public final class MobileConsents: NSObject, MobileConsentsProtocol {
    private let networkManager: NetworkManager
    private var localStorageManager: LocalStorageManager
    
    private let accentColor: UIColor
    private let fontSet: FontSet
    private let solutionId: String
    public typealias ConsentSolutionCompletion = (Result<ConsentSolution, Error>) -> ()
    
    /// Unique identifier of the user in Cookie Information records. This ID is assigned upon first run of the SDK
    public var userId: String {
        localStorageManager.userId
    }
    /// MobileConsents class initializer.
    ///
    /// - Parameters:
    ///   - uiLanguageCode: Language code used for translations in built-in privacy screens. If not provided, current app language is used. If translations are not available in given language, English is used.
    ///   - clientID: the client identifier, can be obtained from Cookie Information dashboard
    ///   - clientSecret: the client secret, can be obtained from Cookie Information dashboard
    ///   - accentColor: determines the tint of the colored elements, such as buttons in the default UI
    ///   - fontSet: overrides the system font. Make sure to test thoroughly when chosing your own font to prevent visual issues in your app
    @objc public convenience init(uiLanguageCode: String? = Bundle.main.preferredLocalizations.first,
                                  clientID: String,
                                  clientSecret: String,
                                  solutionId: String,
                                  accentColor: UIColor? = nil,
                                  fontSet: FontSet = .standard,
                                  enableNetworkLogger: Bool = false) {
        
        self.init(localStorageManager: LocalStorageManager(),
                  uiLanguageCode: uiLanguageCode,
                  clientID: clientID,
                  clientSecret: clientSecret,
                  solutionID: solutionId,
                  accentColor: accentColor,
                  fontSet: fontSet,
                  enableNetworkLogger: enableNetworkLogger)
    }
    
    init(localStorageManager: LocalStorageManager, uiLanguageCode: String?, clientID: String, clientSecret: String, solutionID: String, accentColor: UIColor?, fontSet: FontSet, enableNetworkLogger: Bool) {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.userInfo[primaryLanguageCodingUserInfoKey] = uiLanguageCode
        
        self.accentColor = accentColor ?? .systemBlue
        self.fontSet = fontSet
        self.networkManager = NetworkManager(
            jsonDecoder: jsonDecoder,
            localStorageManager: localStorageManager,
            clientID: clientID,
            clientSecret: clientSecret,
            solutionID: solutionID,
            enableNetworkLogger: enableNetworkLogger
        )
        self.localStorageManager = localStorageManager
        self.solutionId = solutionID
    }
    
    /// Method responsible for fetching Consent Solutions.
    ///
    /// - Parameters:
    ///   - completion: callback - (Result<ConsentSolution, Error>) -> Void
    public func fetchConsentSolution(completion:@escaping ConsentSolutionCompletion) {
        networkManager.getConsentSolution(completion: completion)
    }
    
    /// Method responsible for posting Consent to server.
    ///
    /// - Parameters:
    ///   - consent: Consent object which will be send to server
    ///   - completion: callback - (Error?) -> Void)
    public func postConsent(_ consent: Consent, completion:@escaping (Error?) -> Void) {
        networkManager.postConsent(consent) {[weak self] error in
            self?.saveConsentResult(consent)
            if let error = error {
                self?.localStorageManager.consentsInSync = false
                completion(error)
            } else {
                self?.localStorageManager.consentsInSync = true
                completion(nil)
            }
            
        }
    }
    
    /// Method responsible for getting saved locally consents.
    ///
    /// Returns array of SavedConsent object
    public func getSavedConsents() -> [UserConsent] {
        localStorageManager.consents.map {$0.value}
    }
    
    /// Method responsible for canceling last post consent request.
    ///
    public func cancel() {
        networkManager.cancel()
    }
    
    
    /// Method responsible for showing Privacy Pop Up screen
    /// - Parameters:
    ///   - customViewType: the type of the custom view controller that is to be presented instead of the built in one. E.g. `MyCustomVC.self`
    ///   - onViewController: UIViewController to present pop up on. If not provided, top-most presented view controller of key window of the application is used.
    ///   - animated: If presentation should be animated. Defaults to `true`.
    ///   - completion: called after the user closes the privacy popup.
    ///   - errorHandler: called upon ecountering an error
    @objc public func showPrivacyPopUp(
        customViewType: PrivacyPopupProtocol.Type? = nil,
        onViewController presentingViewController: UIViewController? = nil,
        animated: Bool = true,
        completion: (([UserConsent])->())? = nil,
        errorHandler: ((Error)->())? = nil
    ) {
        DispatchQueue.main.async {
            let presentingViewController = presentingViewController ?? UIApplication.shared.windows.first { $0.isKeyWindow }?.topViewController
            
            let consentSolutionManager = ConsentSolutionManager(
                consentSolutionId: self.solutionId,
                mobileConsents: self
            )
            
            let router = Router(consentSolutionManager: consentSolutionManager, accentColor: self.accentColor, fontSet: self.fontSet)
            router.rootViewController = presentingViewController
           
            router.showPrivacyPopUp(popupController: customViewType, animated: animated, completion: completion, error: errorHandler)
        }
       
    }
    
    
    /// Method responsible for showing Privacy Pop Up screen if there has not been a consent recorded or if the consent
    /// - Parameters:
    ///   - customViewType: the type of the custom view controller that is to be presented instead of the built in one. E.g. `MyCustomVC.self`
    ///   - onViewController: UIViewController to present pop up on. If not provided, top-most presented view controller of key window of the application is used.
    ///   - animated: If presentation should be animated. Defaults to `true`.
    ///   - ignoreVersionChanges: if set to `true` the SDK will ignore changes made to the consent solution in the Cookie Information web interface
    ///   - completion: called after the user closes the privacy popup.
    ///   - errorHandler: called upon ecountering an error
    @objc public func showPrivacyPopUpIfNeeded(
        customViewType: PrivacyPopupProtocol.Type? = nil,
        onViewController presentingViewController: UIViewController? = nil,
        animated: Bool = true,
        ignoreVersionChanges: Bool = false,
        completion: (([UserConsent])->())? = nil,
        errorHandler: ((Error)->())? = nil
    ) {
        synchronizeIfNeeded()
        self.fetchConsentSolution { result in
            guard case let .success(value) = result else {
                return
            }
            
            let storedConsents = self.localStorageManager.consents
            let versionId = value.versionId
            let storedVersionId = self.localStorageManager.versionId
            
            guard !storedConsents.isEmpty && (storedVersionId == versionId || ignoreVersionChanges) else {
                self.removeStoredConsents()
                self.showPrivacyPopUp(customViewType: customViewType, completion: completion, errorHandler: errorHandler)
                return
            }
            
            let userConsents = storedConsents.map(\.value)
            completion?(userConsents)
        }
        
    }
    
    
    /// Synchronizes previously failed uploads with the Cookie Information server if they exist
    public func synchronizeIfNeeded() {
        if !localStorageManager.consentsInSync, let versionId = localStorageManager.versionId  {
            let consent = Consent(consentSolutionId: self.solutionId, consentSolutionVersionId: versionId, userConsents: localStorageManager.consents.map {$0.value})
            postConsent(consent, completion: {_ in })
        }
    }
    
    /// Removes all stored consents from the device. Consents stored in the Cookie Information database persist.
    public func removeStoredConsents() {
        localStorageManager.clearAll()
    }
}

extension MobileConsents {
    func saveConsentResult(_ consent: Consent) {
        let consents = consent.userConsents
        localStorageManager.addConsentsArray(consents, versionId: consent.consentSolutionVersionId)
    }
}
