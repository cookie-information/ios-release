import UIKit

struct PrivacyPopupCoordinator {
    private let core: ConsentCore
    private let localizationOverride: [Locale: LabelText]
    private let accentColor: UIColor
    private let fontSet: FontSet

    init(
        core: ConsentCore,
        localizationOverride: [Locale: LabelText],
        accentColor: UIColor,
        fontSet: FontSet
    ) {
        self.core = core
        self.localizationOverride = localizationOverride
        self.accentColor = accentColor
        self.fontSet = fontSet
    }

    @MainActor
    func present(
        mobileConsents: ConsentSolutionClient,
        customViewType: PrivacyPopupProtocol.Type?,
        onViewController presentingViewController: UIViewController?,
        animated: Bool,
        completion: (([UserConsent]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil,
        loadedContext: LoadedConsentContext? = nil
    ) {
        PrivacyPopupPresenter.present(
            customViewType: customViewType,
            onViewController: presentingViewController,
            animated: animated,
            mobileConsents: mobileConsents,
            localizationOverride: localizationOverride,
            accentColor: accentColor,
            fontSet: fontSet,
            completion: completion,
            errorHandler: errorHandler,
            loadedContext: loadedContext
        )
    }

    @MainActor
    func presentAndWait(
        mobileConsents: ConsentSolutionClient,
        customViewType: PrivacyPopupProtocol.Type?,
        onViewController presentingViewController: UIViewController?,
        animated: Bool,
        loadedContext: LoadedConsentContext? = nil
    ) async throws -> sending [UserConsent] {
        try await withCheckedThrowingContinuation(
            isolation: MainActor.shared
        ) { continuation in
            present(
                mobileConsents: mobileConsents,
                customViewType: customViewType,
                onViewController: presentingViewController,
                animated: animated,
                completion: { @MainActor consents in
                    continuation.resume(returning: consents.map(UserConsentValue.init))
                },
                errorHandler: { @MainActor error in continuation.resume(throwing: error) },
                loadedContext: loadedContext
            )
        }.map(UserConsent.init)
    }

    @MainActor
    func resolveIfNeeded(
        mobileConsents: ConsentSolutionClient,
        customViewType: PrivacyPopupProtocol.Type?,
        onViewController presentingViewController: UIViewController?,
        animated: Bool,
        ignoreVersionChanges: Bool
    ) async throws -> sending [UserConsent] {
        let decision = try await core.presentationDecision(
            ignoreVersionChanges: ignoreVersionChanges
        )
        switch decision {
        case let .useStored(values):
            return values.values.map(UserConsent.init)
        case let .present(solution, savedConsents):
            return try await presentAndWait(
                mobileConsents: mobileConsents,
                customViewType: customViewType,
                onViewController: presentingViewController,
                animated: animated,
                loadedContext: LoadedConsentContext(
                    solution: ConsentSolution(solution),
                    savedConsents: savedConsents.values.map(UserConsent.init)
                )
            )
        }
    }
}
