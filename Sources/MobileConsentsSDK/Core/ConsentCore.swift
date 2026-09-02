import Foundation

enum ConsentPresentationDecision: Equatable, Sendable {
    case present(
        solution: ConsentSolutionValue,
        savedConsents: [String: UserConsentValue]
    )
    case useStored([String: UserConsentValue])
}

enum ConsentSynchronizationStep: Sendable {
    case processed
    case idle
    case busy
}

actor ConsentCore {
    private let solutionID: String
    private let networkCore: NetworkCore
    private let store: ConsentStore
    private let clientID: String
    private let clientSecret: String
    private let platformInformation: @Sendable () -> [String: String]
    private let now: @Sendable () -> Date
    private var cachedToken: AuthorizationTokenValue?

    init(
        solutionID: String,
        networkCore: NetworkCore,
        store: ConsentStore,
        clientID: String,
        clientSecret: String,
        platformInformation: @escaping @Sendable () -> [String: String],
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.solutionID = solutionID
        self.networkCore = networkCore
        self.store = store
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.platformInformation = platformInformation
        self.now = now
    }

    func fetchConsentSolution() async throws -> ConsentSolutionValue {
        let solution = try await networkCore.fetchConsentSolution(solutionID: solutionID)
        try Task<Never, Never>.checkCancellation()
        try store.cacheConsentSolution(solution)
        return solution
    }

    func userID() async throws -> String {
        try store.userID()
    }

    func loadSavedConsents() async throws -> [UserConsentValue] {
        Array(try store.readSnapshot().values.values)
    }

    func presentationDecision(
        ignoreVersionChanges: Bool
    ) async throws -> ConsentPresentationDecision {
        let fetched = try await fetchConsentSolution()
        try Task<Never, Never>.checkCancellation()
        let snapshot = try store.readSnapshot()
        try Task<Never, Never>.checkCancellation()

        if !snapshot.values.isEmpty,
           snapshot.versionId == fetched.versionId || ignoreVersionChanges {
            return .useStored(snapshot.values)
        }

        return .present(
            solution: fetched,
            savedConsents: snapshot.values
        )
    }

    func saveConsent(_ submission: ConsentSubmissionValue) async throws {
        try Task<Never, Never>.checkCancellation()
        try store.savePending(submission: submission)
    }

    func removeStoredConsents() async throws {
        try Task<Never, Never>.checkCancellation()
        try store.clearAll()
    }

    func synchronizeNext() async throws -> ConsentSynchronizationStep {
        try Task<Never, Never>.checkCancellation()
        guard let claim = try store.claimPendingSynchronization() else {
            return try store.hasPendingSynchronization() ? .busy : .idle
        }

        do {
            guard try await deliver(claim) else {
                return try synchronizationStep(
                    didTransitionClaim: store.releaseSynchronizationClaim(claim)
                )
            }
            try Task<Never, Never>.checkCancellation()
            return try synchronizationStep(
                didTransitionClaim: store.completeSynchronizationClaim(claim)
            )
        } catch {
            _ = try? store.releaseSynchronizationClaim(claim)
            throw error
        }
    }

    private func synchronizationStep(
        didTransitionClaim: Bool
    ) throws -> ConsentSynchronizationStep {
        guard didTransitionClaim else {
            return try store.hasPendingSynchronization() ? .busy : .idle
        }
        return .processed
    }

    private func deliver(
        _ claim: ConsentSynchronizationClaim
    ) async throws -> Bool {
        let platformInformation = platformInformation()
        let token = try await authorizationToken()
        try Task<Never, Never>.checkCancellation()
        guard try store.isSynchronizationClaimCurrent(claim) else {
            return false
        }

        do {
            try await postConsent(
                claim,
                platformInformation: platformInformation,
                token: token
            )
            return true
        } catch let error as NetworkCoreError {
            guard case .consentPostFailed(statusCode: 401, serverError: _) = error else {
                throw error
            }

            cachedToken = nil
            guard try store.isSynchronizationClaimCurrent(claim) else {
                return false
            }
            try Task<Never, Never>.checkCancellation()
            let retryToken = try await authorizationToken()
            try Task<Never, Never>.checkCancellation()
            guard try store.isSynchronizationClaimCurrent(claim) else {
                return false
            }
            do {
                try await postConsent(
                    claim,
                    platformInformation: platformInformation,
                    token: retryToken
                )
                return true
            } catch let retryError as NetworkCoreError {
                if case .consentPostFailed(statusCode: 401, serverError: _) = retryError {
                    cachedToken = nil
                }
                throw retryError
            }
        }
    }

    private func postConsent(
        _ claim: ConsentSynchronizationClaim,
        platformInformation: [String: String],
        token: AuthorizationTokenValue
    ) async throws {
        try await networkCore.postConsent(
            claim.submission,
            userID: claim.userID,
            platformInformation: platformInformation,
            token: token
        )
    }

    private func authorizationToken() async throws -> AuthorizationTokenValue {
        if let cachedToken, cachedToken.isValid(at: now()) {
            return cachedToken
        }

        cachedToken = nil
        do {
            let token = try await networkCore.authorize(
                clientID: clientID,
                clientSecret: clientSecret
            )
            cachedToken = token
            return token
        } catch {
            cachedToken = nil
            throw error
        }
    }
}
