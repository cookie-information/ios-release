import Foundation

public struct Consent {
    public let consentSolutionId: String
    public let consentSolutionVersionId: String
    public var processingPurposes: [ProcessingPurpose]
    public let customData: [String: String]?
    public let userConsents: [UserConsent]
    
    public init(consentSolutionId: String, consentSolutionVersionId: String, customData: [String: String]? = [:], userConsents: [UserConsent]) {
        self.consentSolutionId = consentSolutionId
        self.consentSolutionVersionId = consentSolutionVersionId
        self.customData = customData
        self.userConsents = userConsents.filter { $0.consentItem.type != .privacyPolicy }
        self.processingPurposes = self.userConsents
                                                .map {
            ProcessingPurpose(consentItemId: $0.consentItem.id,
                              consentGiven: $0.isSelected,
                              language: $0.consentItem.translations.primaryLanguage)
        }
        
        print(self.processingPurposes)
        
    }
    
    public mutating func addProcessingPurpose(_ purpose: ProcessingPurpose) {
        processingPurposes.append(purpose)
    }
    
    public func JSONRepresentation() -> [String: Any] {
        var json: [String: Any] = [
            "universalConsentSolutionId": consentSolutionId,
            "universalConsentSolutionVersionId": consentSolutionVersionId,
            "customData": parsedCustomData()
        ]
        
        if let purposesData = try? JSONEncoder().encode(processingPurposes), let purposesJSON = try? JSONSerialization.jsonObject(with: purposesData) as? [[String: Any]] {
            json["processingPurposes"] = purposesJSON
        }
        
        return json
    }
    
    func parsedCustomData() -> [[String: String]] {
        guard let customData = customData else { return [] }
        let parsed = customData.map { dictItem in
            return ["fieldName": dictItem.key, "fieldValue": dictItem.value]
        }
        return parsed
    }
}
