import Foundation

/// UserConsent
public class UserConsent: NSObject, Codable {
    public init(consentItem: ConsentItem, isSelected: Bool) {
        self.consentItem = consentItem
        self.isSelected = isSelected
    }
    
    public let consentItem: ConsentItem
    public var purpose: ConsentPurpose {
        .init(from: consentItem)
    }
    
    public var purposeDescription: String {
        consentItem.translations.primaryTranslation().shortText
    }
    public let isSelected: Bool
}

public enum ConsentPurpose: Codable {
    case necessary
    case marketing
    case functional
    case statistical
    case custom(title: String)
    
    public init(from consentItem: ConsentItem) {
        switch consentItem.type {
        case .necessary: self = .necessary
        case .marketing: self = .marketing
        case .functional: self = .functional
        case .statistical: self = .statistical
        case .custom: self = .custom(title: consentItem.translations.primaryTranslation().shortText)
        case .privacyPolicy: fatalError("Invalid processing purpose") // this won't happen 
        
        }
    }
    
    public var description: String {
        String(describing: self)
    }
}
