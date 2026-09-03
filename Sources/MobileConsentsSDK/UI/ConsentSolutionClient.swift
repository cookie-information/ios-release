/// Operations required by the SDK's consent-solution UI flow.
protocol ConsentSolutionClient: AnyObject {
    func fetchConsentSolution(
        completion: @escaping (Result<ConsentSolution, Error>) -> Void
    )
    func loadSavedConsents() async throws -> [UserConsent]
    func postConsent(_ consent: Consent, completion: @escaping (Error?) -> Void)
}
