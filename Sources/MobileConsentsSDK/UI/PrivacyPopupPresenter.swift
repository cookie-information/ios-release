import UIKit

@MainActor
enum PrivacyPopupPresenter {
    static func present(
        customViewType: PrivacyPopupProtocol.Type?,
        onViewController presentingViewController: UIViewController?,
        animated: Bool,
        mobileConsents: ConsentSolutionClient,
        localizationOverride: [Locale: LabelText],
        accentColor: UIColor,
        fontSet: FontSet,
        completion: (([UserConsent]) -> Void)?,
        errorHandler: ((Error) -> Void)?,
        loadedContext: LoadedConsentContext?
    ) {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = windowScenes.first { $0.activationState == .foregroundActive }?.keyWindow
            ?? windowScenes.compactMap(\.keyWindow).first
        let presentingViewController = presentingViewController ?? keyWindow?.topViewController

        let consentSolutionManager = ConsentSolutionManager(
            mobileConsents: mobileConsents,
            localizationOverride: localizationOverride,
            loadedContext: loadedContext
        )
        let router = Router(
            consentSolutionManager: consentSolutionManager,
            accentColor: accentColor,
            fontSet: fontSet
        )
        router.rootViewController = presentingViewController
        router.showPrivacyPopUp(
            popupController: customViewType,
            animated: animated,
            completion: completion,
            error: errorHandler
        )
    }
}
