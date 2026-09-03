import Foundation

final class FetchConsentSolutionRequest: MainActorRequest {
    private let core: ConsentCore
    private let completion: MobileConsents.ConsentSolutionCompletion

    init(
        core: ConsentCore,
        completion: @escaping MobileConsents.ConsentSolutionCompletion
    ) {
        self.core = core
        self.completion = completion
    }

    @MainActor
    override func perform() {
        Task<Void, Never>(
            name: "MobileConsentsSDK.MobileConsents.fetchConsentSolution"
        ) { @MainActor in
            do {
                completion(.success(ConsentSolution(try await core.fetchConsentSolution())))
            } catch {
                completion(.failure(LegacyNetworkErrorAdapter.adapt(error)))
            }
        }
    }
}