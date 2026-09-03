import Foundation

final class SaveConsentRequest: MainActorRequest {
    private let core: ConsentCore
    private let submission: ConsentSubmissionValue
    private let synchronizationCoordinator: ConsentSynchronizationCoordinator
    private let completion: (Error?) -> Void

    init(
        core: ConsentCore,
        submission: ConsentSubmissionValue,
        synchronizationCoordinator: ConsentSynchronizationCoordinator,
        completion: @escaping (Error?) -> Void
    ) {
        self.core = core
        self.submission = submission
        self.synchronizationCoordinator = synchronizationCoordinator
        self.completion = completion
    }

    @MainActor
    override func perform() {
        Task<Void, Never>(
            name: "MobileConsentsSDK.MobileConsents.consentSave"
        ) { @MainActor in
            do {
                try await core.saveConsent(submission)
                completion(nil)
                let synchronizationCoordinator = synchronizationCoordinator
                 Task<Void, Never>(
                    name: "MobileConsentsSDK.MobileConsents.consentSave.synchronize"
                ) {
                    _ = await synchronizationCoordinator.synchronizeIfNeeded()
                }
            } catch {
                completion(LegacyNetworkErrorAdapter.adapt(error))
            }
        }
    }
}