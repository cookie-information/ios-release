import Foundation

protocol ConsentItemProvider {
    func isConsentItemSelected(id: String) -> Bool
    func isConsentItemRequired(id: String) -> Bool
    func markConsentItem(id: String, asSelected selected: Bool)
}

protocol ConsentSolutionManagerProtocol: ConsentItemProvider {
    var areAllRequiredConsentItemsSelected: Bool { get }
    var hasRequiredConsentItems: Bool { get }
    var settings: [ConsentItem] { get }
    func loadConsentSolutionIfNeeded(completion: @escaping (Result<ConsentSolution, Error>) -> Void)
    
    func rejectAllConsentItems(completion: @escaping (Error?) -> Void)
    func acceptAllConsentItems(completion: @escaping (Error?) -> Void)
    func acceptSelectedConsentItems(completion: @escaping (Error?) -> Void)
}

final class ConsentSolutionManager: ConsentSolutionManagerProtocol {
    static let consentItemSelectionDidChange = Notification.Name(rawValue: "com.cookieinformation.consentItemSelectionDidChange")
    
    var areAllRequiredConsentItemsSelected: Bool {
        consentSolution?
            .consentItems
            .filter { $0.required && ($0.type != .privacyPolicy || $0.type != .privacyPolicy )}
            .map(\.id)
            .allSatisfy(selectedConsentItemIds.contains)
            ??
            false
    }
    
    var hasRequiredConsentItems: Bool {
        !(consentSolution?
            .consentItems
            .filter { $0.required && ($0.type != .privacyPolicy || $0.type != .privacyPolicy ) }
            .isEmpty
            ??
            true)
    }
    
    public var settings: [ConsentItem] {
        consentSolution?.consentItems.filter { ($0.type != .privacyPolicy || $0.type != .privacyPolicy )} ?? []
    }
    
    private var allSettingsItemIds: [String] {
        consentSolution?.consentItems
            .filter {($0.type != .privacyPolicy || $0.type != .privacyPolicy ) }
            .map(\.id) ?? []
    }
    
    
    private let consentSolutionId: String
    private let mobileConsents: MobileConsentsProtocol
    private let notificationCenter: NotificationCenter
    private let asyncDispatcher: AsyncDispatcher
    
    private var consentSolution: ConsentSolution?
    private var selectedConsentItemIds = Set<String>()
    
    init(
        consentSolutionId: String,
        mobileConsents: MobileConsentsProtocol,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        asyncDispatcher: AsyncDispatcher = DispatchQueue.main
    ) {
        self.consentSolutionId = consentSolutionId
        self.mobileConsents = mobileConsents
        self.notificationCenter = notificationCenter
        self.asyncDispatcher = asyncDispatcher
    }
    
    func loadConsentSolutionIfNeeded(completion: @escaping (Result<ConsentSolution, Error>) -> Void) {
        if let consentSolution = consentSolution {
            completion(.success(consentSolution))
            
            return
        }
        
        mobileConsents.fetchConsentSolution { [weak self, asyncDispatcher] result in
            asyncDispatcher.async {
                if case .success(let solution) = result {
                    self?.consentSolution = solution
                    let givenConsentIds = self?.mobileConsents.getSavedConsents().filter(\.isSelected).map(\.consentItem.id) ?? []
                    self?.selectedConsentItemIds = Set(givenConsentIds)
                }
                
                completion(result)
            }
        }
    }
    
    func isConsentItemSelected(id: String) -> Bool {
        selectedConsentItemIds.contains(id)
    }
    
    func isConsentItemRequired(id: String) -> Bool {
        consentSolution?.consentItems.first { $0.id == id}?.required ?? false
    }
    
    func markConsentItem(id: String, asSelected selected: Bool) {
        if selected {
            selectedConsentItemIds.insert(id)
        } else {
            selectedConsentItemIds.remove(id)
        }
        
        postConsentItemSelectionDidChangeNotification()
    }
    
    func rejectAllConsentItems(completion: @escaping (Error?) -> Void) {
        selectedConsentItemIds.removeAll()
        
        postConsentItemSelectionDidChangeNotification()
        
        postConsent(selectedConsentItemIds: [], completion: completion)
    }
    
    func acceptAllConsentItems(completion: @escaping (Error?) -> Void) {
        
        selectedConsentItemIds.formUnion(allSettingsItemIds)
        
        postConsentItemSelectionDidChangeNotification()
        
        postConsent(selectedConsentItemIds: selectedConsentItemIds, completion: completion)
    }
    
    func acceptSelectedConsentItems(completion: @escaping (Error?) -> Void) {
        postConsent(selectedConsentItemIds: selectedConsentItemIds, completion: completion)
    }
    
    private func postConsent(selectedConsentItemIds: Set<String>, completion: @escaping (Error?) -> Void) {
        guard let consentSolution = consentSolution else { return }
        
        let infoConsentItemIds = consentSolution.consentItems.filter { $0.type == .privacyPolicy }.map(\.id)
        let givenConsentItemIds = selectedConsentItemIds.union(infoConsentItemIds)
        let userConsents = consentSolution.consentItems.filter {($0.type != .privacyPolicy || $0.type != .privacyPolicy )}.map {UserConsent(consentItem: $0, isSelected: selectedConsentItemIds.contains($0.id) || $0.required)}
        
        let consent = Consent(consentSolutionId: consentSolution.id, consentSolutionVersionId: consentSolution.versionId, userConsents: userConsents)

        
        mobileConsents.postConsent(consent) { [asyncDispatcher] error in
            asyncDispatcher.async {
                completion(error)
            }
        }
    }
    
    private func postConsentItemSelectionDidChangeNotification() {
        notificationCenter.post(Notification(name: Self.consentItemSelectionDidChange))
    }
}
