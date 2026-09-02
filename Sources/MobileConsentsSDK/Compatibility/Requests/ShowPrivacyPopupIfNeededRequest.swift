import UIKit

final class ShowPrivacyPopupIfNeededRequest: MainActorRequest {
    private let coordinator: PrivacyPopupCoordinator
    private let mobileConsents: ConsentSolutionClient
    private let customViewType: PrivacyPopupProtocol.Type?
    private let presentingViewController: UIViewController?
    private let animated: Bool
    private let ignoreVersionChanges: Bool
    private let completion: (([UserConsent]) -> Void)?
    private let errorHandler: ((Error) -> Void)?

    init(
        coordinator: PrivacyPopupCoordinator,
        mobileConsents: ConsentSolutionClient,
        customViewType: PrivacyPopupProtocol.Type?,
        presentingViewController: UIViewController?,
        animated: Bool,
        ignoreVersionChanges: Bool,
        completion: (([UserConsent]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        self.coordinator = coordinator
        self.mobileConsents = mobileConsents
        self.customViewType = customViewType
        self.presentingViewController = presentingViewController
        self.animated = animated
        self.ignoreVersionChanges = ignoreVersionChanges
        self.completion = completion
        self.errorHandler = errorHandler
    }

    @MainActor
    override func perform() {
        Task<Void, Never>(
            name: "MobileConsentsSDK.MobileConsents.presentationDecision"
        ) { @MainActor in
            do {
                let consents = try await coordinator.resolveIfNeeded(
                    mobileConsents: mobileConsents,
                    customViewType: customViewType,
                    onViewController: presentingViewController,
                    animated: animated,
                    ignoreVersionChanges: ignoreVersionChanges
                )
                completion?(consents)
            } catch {
                errorHandler?(LegacyNetworkErrorAdapter.adapt(error))
            }
        }
    }
}
