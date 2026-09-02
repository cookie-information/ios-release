import Foundation

@MainActor
protocol ConsentItemProvider {
    func isConsentItemSelected(id: String) -> Bool
    func isConsentItemRequired(id: String) -> Bool
    func markConsentItem(id: String, asSelected selected: Bool)
}

@MainActor
protocol ConsentSolutionManagerProtocol: ConsentItemProvider {
    var settings: [ConsentItem] { get }
    var localizationOverride: [Locale: LabelText] { get }
    func loadConsentSolutionIfNeeded(completion: @escaping (Result<ConsentSolution, Error>) -> Void)
    
    func rejectAllConsentItems(completion: @escaping (Error?) -> Void)
    func acceptAllConsentItems(completion: @escaping (Error?) -> Void)
    func acceptSelectedConsentItems(completion: @escaping (Error?) -> Void)
}

struct LoadedConsentContext {
    let solution: ConsentSolution
    var selectedConsentItemIDs: Set<String>

    init(
        solution: ConsentSolution,
        savedConsents: [UserConsent]
    ) {
        self.solution = solution
        self.selectedConsentItemIDs = Set(
            savedConsents.filter(\.isSelected).map(\.consentItem.id)
        )
    }
}

@MainActor
final class ConsentSolutionManager: ConsentSolutionManagerProtocol {
    var localizationOverride: [Locale: LabelText]
    
    static let consentItemSelectionDidChange = Notification.Name(rawValue: "com.cookieinformation.consentItemSelectionDidChange")

    public var settings: [ConsentItem] {
        loadedContext?.solution.consentItems.filter { $0.type != .privacyPolicy } ?? []
    }

    private var allSettingsItemIds: [String] {
        settings.map(\.id)
    }


    private let mobileConsents: ConsentSolutionClient
    private let notificationCenter: NotificationCenter
    private let asyncDispatcher: AsyncDispatcher
    
    private var loadedContext: LoadedConsentContext?
    
    init(
        mobileConsents: ConsentSolutionClient,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        asyncDispatcher: AsyncDispatcher = MainThreadAsyncDispatcher(),
        localizationOverride: [Locale: LabelText] = [:],
        loadedContext: LoadedConsentContext? = nil
    ) {
        self.mobileConsents = mobileConsents
        self.notificationCenter = notificationCenter
        self.asyncDispatcher = asyncDispatcher
        self.localizationOverride = localizationOverride
        self.loadedContext = loadedContext
    }
    
    func loadConsentSolutionIfNeeded(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        if let loadedContext {
            completion(.success(loadedContext.solution))
            return
        }
        
        mobileConsents.fetchConsentSolution { [weak self, asyncDispatcher] result in
            switch result {
            case let .success(solution):
                self?.loadSavedConsents(for: solution) { result in
                    asyncDispatcher.async {
                        completion(result)
                    }
                }
            case let .failure(error):
                asyncDispatcher.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func loadSavedConsents(
        for solution: ConsentSolution,
        completion: @escaping (Result<ConsentSolution, Error>) -> Void
    ) {
        Task<Void, Never>(
            name: "MobileConsentsSDK.ConsentSolutionManager.loadSavedConsents"
        ) { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let consents = try await mobileConsents.loadSavedConsents()
                self.loadedContext = LoadedConsentContext(
                    solution: solution,
                    savedConsents: consents
                )
                completion(.success(solution))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func isConsentItemSelected(id: String) -> Bool {
        loadedContext?.selectedConsentItemIDs.contains(id) ?? false
    }
    
    func isConsentItemRequired(id: String) -> Bool {
        loadedContext?.solution.consentItems.first { $0.id == id}?.required ?? false
    }
    
    func markConsentItem(id: String, asSelected selected: Bool) {
        if selected {
            loadedContext?.selectedConsentItemIDs.insert(id)
        } else {
            loadedContext?.selectedConsentItemIDs.remove(id)
        }
        
        postConsentItemSelectionDidChangeNotification()
    }
    
    func rejectAllConsentItems(completion: @escaping (Error?) -> Void) {
        guard loadedContext != nil else {
            completeWithConsentSolutionNotLoaded(completion: completion)
            return
        }

        loadedContext?.selectedConsentItemIDs.removeAll()
        
        postConsentItemSelectionDidChangeNotification()
        
        postConsent(selectedConsentItemIds: [], completion: completion)
    }
    
    func acceptAllConsentItems(completion: @escaping (Error?) -> Void) {
        guard loadedContext != nil else {
            completeWithConsentSolutionNotLoaded(completion: completion)
            return
        }

        let consentItemIDs = allSettingsItemIds
        loadedContext?.selectedConsentItemIDs.formUnion(consentItemIDs)
        
        postConsentItemSelectionDidChangeNotification()
        
        postConsent(
            selectedConsentItemIds: loadedContext?.selectedConsentItemIDs ?? [],
            completion: completion
        )
    }
    
    func acceptSelectedConsentItems(completion: @escaping (Error?) -> Void) {
        guard let loadedContext else {
            completeWithConsentSolutionNotLoaded(completion: completion)
            return
        }

        postConsent(
            selectedConsentItemIds: loadedContext.selectedConsentItemIDs,
            completion: completion
        )
    }
    
    private func postConsent(selectedConsentItemIds: Set<String>, completion: @escaping (Error?) -> Void) {
        guard let consentSolution = loadedContext?.solution else {
            completeWithConsentSolutionNotLoaded(completion: completion)
            return
        }
        
        let userConsents = settings.map { UserConsent(consentItem: $0, isSelected: selectedConsentItemIds.contains($0.id) || $0.required) }

        let consent = Consent(consentSolutionId: consentSolution.id, consentSolutionVersionId: consentSolution.versionId, userConsents: userConsents)

        
        mobileConsents.postConsent(consent) { [asyncDispatcher] error in
            asyncDispatcher.async {
                completion(error)
            }
        }

    }

    private func completeWithConsentSolutionNotLoaded(completion: @escaping (Error?) -> Void) {
        asyncDispatcher.async {
            completion(ConsentSolutionManagerError.consentSolutionNotLoaded)
        }
    }
    
    private func postConsentItemSelectionDidChangeNotification() {
        notificationCenter.post(Notification(name: Self.consentItemSelectionDidChange))
    }
}

enum ConsentSolutionManagerError: LocalizedError {
    case consentSolutionNotLoaded

    var errorDescription: String? {
        switch self {
        case .consentSolutionNotLoaded:
            return "Cannot post consent because the consent solution has not been loaded yet."
        }
    }
}
