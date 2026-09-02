import UIKit

final class ShowPrivacyPopupRequest: MainActorRequest {
    private let coordinator: PrivacyPopupCoordinator
    private let mobileConsents: ConsentSolutionClient
    private let customViewType: PrivacyPopupProtocol.Type?
    private let presentingViewController: UIViewController?
    private let animated: Bool
    private let completion: (([UserConsent]) -> Void)?
    private let errorHandler: ((Error) -> Void)?

    init(
        coordinator: PrivacyPopupCoordinator,
        mobileConsents: ConsentSolutionClient,
        customViewType: PrivacyPopupProtocol.Type?,
        presentingViewController: UIViewController?,
        animated: Bool,
        completion: (([UserConsent]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        self.coordinator = coordinator
        self.mobileConsents = mobileConsents
        self.customViewType = customViewType
        self.presentingViewController = presentingViewController
        self.animated = animated
        self.completion = completion
        self.errorHandler = errorHandler
    }

    @MainActor
    override func perform() {
        coordinator.present(
            mobileConsents: mobileConsents,
            customViewType: customViewType,
            onViewController: presentingViewController,
            animated: animated,
            completion: completion,
            errorHandler: errorHandler
        )
    }
}
