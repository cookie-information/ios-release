import UIKit

@objc
public final class MobileConsents: NSObject, ConsentSolutionClient {
    public typealias ConsentSolutionCompletion = (Result<ConsentSolution, Error>) -> ()

    // MARK: - Properties

    private let store: ConsentStore
    private let consentCore: ConsentCore
    private let synchronizationCoordinator: ConsentSynchronizationCoordinator
    private let privacyPopupCoordinator: PrivacyPopupCoordinator
    private let requestDispatcher = MainActorRequestDispatcher()
    
    /// Unique identifier assigned to the user on first access.
    /// Returns an empty string if local persistence cannot be read.
    @objc public var userId: String {
        store.userId
    }

    // MARK: - Initialization

    /// MobileConsents class initializer.
    ///
    /// - Parameters:
    ///   - uiLanguageCode: Language code used for translations in built-in privacy screens. If not provided, current app language is used. If translations are not available in given language, English is used.
    ///   - clientID: the client identifier, can be obtained from Cookie Information dashboard
    ///   - clientSecret: the client secret, can be obtained from Cookie Information dashboard
    ///   - solutionId:  the solution id, can be obtained from Cookie Information dashboard
    ///   - accentColor: determines the tint of the colored elements, such as buttons in the default UI
    ///   - fontSet: overrides the system font. Make sure to test thoroughly when chosing your own font to prevent visual issues in your app
    ///   - localizationOverride: a dictionary of Locale (key) and LabelText (value) used to override static UI translations
    ///   - enableNetworkLogger: A compatibility flag that records redacted requests and responses when enabled.
    @available(
        *,
        deprecated,
        renamed: "init(uiLanguageCode:clientID:clientSecret:solutionId:accentColor:fontSet:localizationOverride:networkLoggingMode:)"
    )
    @objc public convenience init(uiLanguageCode: String? = Bundle.main.preferredLocalizations.first,
                                  clientID: String,
                                  clientSecret: String,
                                  solutionId: String,
                                  accentColor: UIColor? = nil,
                                  fontSet: FontSet = .standard,
                                  localizationOverride: [Locale: LabelText] = [:],
                                  enableNetworkLogger: Bool) {
        self.init(
            uiLanguageCode: uiLanguageCode,
            clientID: clientID,
            clientSecret: clientSecret,
            solutionId: solutionId,
            accentColor: accentColor,
            fontSet: fontSet,
            localizationOverride: localizationOverride,
            networkLoggingMode: enableNetworkLogger
                ? .redactedRequestsAndResponses
                : .disabled
        )
    }

    /// Creates a Mobile Consents client.
    ///
    /// - Parameters:
    ///   - uiLanguageCode: Language code used for translations in built-in privacy screens.
    ///   - clientID: The client identifier obtained from the Cookie Information dashboard.
    ///   - clientSecret: The client secret obtained from the Cookie Information dashboard.
    ///   - solutionId: The solution identifier obtained from the Cookie Information dashboard.
    ///   - accentColor: The tint color used by the default UI.
    ///   - fontSet: Fonts used by the default UI.
    ///   - localizationOverride: Static UI translation overrides.
    ///   - networkLoggingMode: The network diagnostics recorded in the system log.
    @objc public convenience init(
        uiLanguageCode: String? = Bundle.main.preferredLocalizations.first,
        clientID: String,
        clientSecret: String,
        solutionId: String,
        accentColor: UIColor? = nil,
        fontSet: FontSet = .standard,
        localizationOverride: [Locale: LabelText] = [:],
        networkLoggingMode: NetworkLoggingMode = .disabled,
    ) {
        let store = ConsentStore(
            solutionID: solutionId,
            clientID: clientID,
            clientSecret: clientSecret
        )
        self.init(
            store: store,
            transport: URLSessionHTTPTransport(networkLoggingMode: networkLoggingMode),
            uiLanguageCode: uiLanguageCode,
            clientID: clientID,
            clientSecret: clientSecret,
            solutionID: solutionId,
            accentColor: accentColor,
            fontSet: fontSet,
            localizationOverride: localizationOverride
        )
    }

    init(
        store: ConsentStore,
        transport: any HTTPTransport,
        uiLanguageCode: String?,
        clientID: String,
        clientSecret: String,
        solutionID: String,
        accentColor: UIColor?,
        fontSet: FontSet,
        localizationOverride: [Locale: LabelText] = [:],
        networkEnvironment: NetworkEnvironment = .production,
    ) {
        self.store = store
        let effectiveLanguage = uiLanguageCode ?? "EN"
        let consentCore = ConsentCore(
            solutionID: solutionID,
            networkCore: NetworkCore(
                transport: transport,
                primaryLanguage: effectiveLanguage,
                environment: networkEnvironment,
            ),
            store: store,
            clientID: clientID,
            clientSecret: clientSecret,
            platformInformation: { PlatformInformationGenerator().generatePlatformInformation() }
        )
        self.consentCore = consentCore
        self.synchronizationCoordinator = ConsentSynchronizationCoordinator(core: consentCore)
        self.privacyPopupCoordinator = PrivacyPopupCoordinator(
            core: consentCore,
            localizationOverride: localizationOverride,
            accentColor: accentColor ?? .systemBlue,
            fontSet: fontSet
        )
        super.init()
        scheduleSynchronization()
    }

    // MARK: - Consent solution

    /// Method responsible for fetching Consent Solutions.
    ///
    /// - Parameters:
    ///   - completion: callback - (Result<ConsentSolution, Error>) -> Void
    public func fetchConsentSolution(completion:@escaping ConsentSolutionCompletion) {
        requestDispatcher.dispatch(
            FetchConsentSolutionRequest(
                core: consentCore,
                completion: completion
            )
        )
    }

    /// Fetches the configured consent solution.
    @_disfavoredOverload @nonobjc public func fetchConsentSolution() async throws -> ConsentSolution {
        do {
            return ConsentSolution(try await consentCore.fetchConsentSolution())
        } catch {
            throw LegacyNetworkErrorAdapter.adapt(error)
        }
    }

    // MARK: - Consent submission

    /// Stores consent locally and schedules independent server synchronization.
    ///
    /// - Parameters:
    ///   - consent: The complete consent decision to store.
    ///   - completion: Called on the main actor after local persistence succeeds or fails.
    ///     A `nil` error does not mean that server synchronization has finished.
    public func postConsent(_ consent: Consent, completion:@escaping (Error?) -> Void) {
        requestDispatcher.dispatch(
            SaveConsentRequest(
                core: consentCore,
                submission: ConsentSubmissionValue(consent),
                synchronizationCoordinator: synchronizationCoordinator,
                completion: completion
            )
        )
    }

    /// Stores consent locally and schedules independent server synchronization.
    ///
    /// This method returns after verified local persistence. It does not wait for the server.
    @_disfavoredOverload @nonobjc public func postConsent(_ consent: Consent) async throws {
        do {
            try await consentCore.saveConsent(ConsentSubmissionValue(consent))
        } catch {
            throw LegacyNetworkErrorAdapter.adapt(error)
        }
        let synchronizationCoordinator = synchronizationCoordinator
        Task<Void, Never>(
            name: "MobileConsentsSDK.MobileConsents.asyncConsentSave.synchronize"
        ) {
            _ = await synchronizationCoordinator.synchronizeIfNeeded()
        }
    }

    // MARK: - Stored consents
    
    /// Returns the unique identifier assigned to the user on first access.
    @objc public func getUserId() async throws -> String {
        try await consentCore.userID()
    }

    /// Returns locally saved consents.
    /// Returns an empty array if local persistence cannot be read.
    @objc public func getSavedConsents() -> [UserConsent] {
        store.consents.values.map(UserConsent.init)
    }

    /// Returns locally saved consents.
    @objc public func loadSavedConsents() async throws -> sending [UserConsent] {
        try await consentCore.loadSavedConsents().map(UserConsent.init)
    }

    /// Removes all stored consents from the device. Consents stored in the Cookie Information database persist.
    @objc public func removeStoredConsents() {
        do {
            try store.clearAll()
        } catch {
            return
        }
    }

    /// Removes all stored consents from the device after confirming local persistence.
    @objc(removeStoredConsentsWithCompletionHandler:)
    public func clearStoredConsents() async throws {
        try await consentCore.removeStoredConsents()
    }

    // MARK: - Privacy popup

    /// Method responsible for showing Privacy Pop Up screen
    /// - Parameters:
    ///   - customViewType: the type of the custom view controller that is to be presented instead of the built in one. E.g. `MyCustomVC.self`
    ///   - presentingViewController: UIViewController to present pop up on. If not provided, top-most presented view controller of key window of the application is used.
    ///   - animated: If presentation should be animated. Defaults to `true`.
    ///   - completion: Required callback called after the user closes the privacy popup successfully.
    ///   - errorHandler: Required callback called when fetching, presentation, submission creation, or local persistence fails.
    @objc public func showPrivacyPopUp(
        customViewType: PrivacyPopupProtocol.Type? = nil,
        onViewController presentingViewController: UIViewController? = nil,
        animated: Bool = true,
        completion: @escaping ([UserConsent]) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        scheduleSynchronization()
        requestDispatcher.dispatch(
            ShowPrivacyPopupRequest(
                coordinator: privacyPopupCoordinator,
                mobileConsents: self,
                customViewType: customViewType,
                presentingViewController: presentingViewController,
                animated: animated,
                completion: completion,
                errorHandler: errorHandler
            )
        )
    }
    
    /// Method responsible for showing Privacy Pop Up screen if there has not been a consent recorded or if the consent
    /// - Parameters:
    ///   - customViewType: the type of the custom view controller that is to be presented instead of the built in one. E.g. `MyCustomVC.self`
    ///   - presentingViewController: UIViewController to present pop up on. If not provided, top-most presented view controller of key window of the application is used.
    ///   - animated: If presentation should be animated. Defaults to `true`.
    ///   - ignoreVersionChanges: if set to `true` the SDK will ignore changes made to the consent solution in the Cookie Information web interface
    ///   - completion: Required callback called when the workflow completes successfully.
    ///   - errorHandler: Required callback called when fetching, presentation, submission creation, or local persistence fails.
    @objc public func showPrivacyPopUpIfNeeded(
        customViewType: PrivacyPopupProtocol.Type? = nil,
        onViewController presentingViewController: UIViewController? = nil,
        animated: Bool = true,
        ignoreVersionChanges: Bool = false,
        completion: @escaping ([UserConsent]) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        scheduleSynchronization()
        requestDispatcher.dispatch(
            ShowPrivacyPopupIfNeededRequest(
                coordinator: privacyPopupCoordinator,
                mobileConsents: self,
                customViewType: customViewType,
                presentingViewController: presentingViewController,
                animated: animated,
                ignoreVersionChanges: ignoreVersionChanges,
                completion: completion,
                errorHandler: errorHandler
            )
        )

    }
    
    /// Presents the privacy popup and returns the locally stored decision.
    ///
    /// - Parameters:
    ///   - customViewType: The custom view controller type to present instead of the built-in popup.
    ///   - presentingViewController: The view controller used for presentation. The SDK uses the top-most view controller when omitted.
    ///   - animated: Whether the presentation is animated.
    @_disfavoredOverload @MainActor @nonobjc public func showPrivacyPopUp(
        customViewType: PrivacyPopupProtocol.Type? = nil,
        onViewController presentingViewController: UIViewController? = nil,
        animated: Bool = true
    ) async throws -> sending [UserConsent] {
        scheduleSynchronization()
        return try await privacyPopupCoordinator.presentAndWait(
            mobileConsents: self,
            customViewType: customViewType,
            onViewController: presentingViewController,
            animated: animated,
            loadedContext: nil
        )
    }

    /// Presents the privacy popup when required and returns the locally stored decision.
    ///
    /// - Parameters:
    ///   - customViewType: The custom view controller type to present instead of the built-in popup.
    ///   - presentingViewController: The view controller used for presentation. The SDK uses the top-most view controller when omitted.
    ///   - animated: Whether the presentation is animated.
    ///   - ignoreVersionChanges: Whether changes to the consent-solution version should be ignored.
    @_disfavoredOverload @MainActor @nonobjc public func showPrivacyPopUpIfNeeded(
        customViewType: PrivacyPopupProtocol.Type? = nil,
        onViewController presentingViewController: UIViewController? = nil,
        animated: Bool = true,
        ignoreVersionChanges: Bool = false
    ) async throws -> sending [UserConsent] {
        scheduleSynchronization()
        do {
            return try await privacyPopupCoordinator.resolveIfNeeded(
                mobileConsents: self,
                customViewType: customViewType,
                onViewController: presentingViewController,
                animated: animated,
                ignoreVersionChanges: ignoreVersionChanges
            )
        } catch {
            throw LegacyNetworkErrorAdapter.adapt(error)
        }
    }

    // MARK: - Synchronization

    /// Requests synchronization of pending consents, if any exist.
    public func synchronizeIfNeeded() {
        scheduleSynchronization()
    }

    private func scheduleSynchronization() {
        let synchronizationCoordinator = synchronizationCoordinator
        Task<Void, Never>(
            name: "MobileConsentsSDK.MobileConsents.synchronize"
        ) {
            _ = await synchronizationCoordinator.synchronizeIfNeeded()
        }
    }

    /// Attempts to synchronize pending consents.
    ///
    /// - Returns: `true` when a pending consent remains after the attempt.
    @_disfavoredOverload @nonobjc public func synchronizeIfNeeded() async -> Bool {
        await synchronizationCoordinator.synchronizeIfNeeded()
    }
}
