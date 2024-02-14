import Foundation
@objc
public class LabelText: NSObject {
    @objc
    public init(title: String?=nil, acceptAllButtonTitle: String?=nil, saveSelectionButtonTitle: String?=nil, privacyDescription: String?=nil, privacyPolicyLongtext: String?=nil, readMoreButton: String?=nil, requiredSectionHeader: String?=nil, optionalSectionHeader: String?=nil, readMoreScreenHeader: String?=nil) {
        self.title = title
        self.acceptAllButtonTitle = acceptAllButtonTitle
        self.saveSelectionButtonTitle = saveSelectionButtonTitle
        self.privacyDescription = privacyDescription
        self.privacyPolicyLongtext = privacyPolicyLongtext
        self.readMoreButton = readMoreButton
        self.requiredSectionHeader = requiredSectionHeader
        self.optionalSectionHeader = optionalSectionHeader
        self.readMoreScreenHeader = readMoreScreenHeader
    }
    
    public let title: String?
    public let acceptAllButtonTitle: String?
    public let saveSelectionButtonTitle: String?
    public let privacyDescription: String?
    public let privacyPolicyLongtext: String?
    public let readMoreButton: String?
    public let requiredSectionHeader: String?
    public let optionalSectionHeader: String?
    public let readMoreScreenHeader: String?
    
    
}
