import Foundation
import MobileConsentsSDK

/// All the text and configuration the custom consent screen uses, in one place
/// (shared by every variant). Edit here rather than in the individual views.
enum ConsentConfiguration {

    // MARK: - Text

    static let title = "Cookie settings"
    static let intro = "To give you the best possible experience, we'd like to collect the following data. You can change your preferences at any time in profile settings. To learn more about how we process your personal data and use cookies, please read our"
    static let and = "and"
    static let privacyPolicyLabel = "Privacy Policy"
    static let cookiePolicyLabel = "Cookie Policy"

    static let acceptAllButton = "Accept All"
    static let saveChoicesButton = "Save Choices"
    static let onlyNecessaryButton = "Only Necessary"

    static let policyScreenClose = "Close"

    // MARK: - Policies

    /// The Privacy Policy content comes from the dashboard (the privacy policy entry), so
    /// only the Cookie Policy URL is set here. A `nil` URL renders its label as plain,
    /// non-tappable text.
    static var cookiePolicyURL: URL? = URL(string: "https://example.com/cookie-policy")

    /// Custom scheme used to tell the two policy links apart when one is tapped. The privacy
    /// policy content may be raw HTML rather than a URL, so it cannot be linked to directly.
    private static let policyScheme = "customconsent-policy"
    static let privacyPolicyLink = URL(string: "\(policyScheme)://privacy")!
    static let cookiePolicyLink = URL(string: "\(policyScheme)://cookie")!

    // MARK: - Category order

    /// Categories are shown in this order: Necessary, Functional, Statistical, Marketing,
    /// then anything else in the order the dashboard returns it.
    ///
    /// The variants presented through the SDK's `customViewType` hook only receive the
    /// category *titles*, so they match these keywords case-insensitively against the title —
    /// adjust them to your own dashboard category names (for example "advertising" instead
    /// of "marketing"). The standalone variant has the category type available and orders by
    /// it directly, ignoring this list.
    static let categoryOrderKeywords = ["necessary", "functional", "statistic", "marketing"]

    /// Sort index for a category title, for the variants that only know the title.
    static func sortIndex(forTitle title: String) -> Int {
        let title = title.lowercased()
        return categoryOrderKeywords.firstIndex { title.contains($0) } ?? categoryOrderKeywords.count
    }

    /// Sort index for a category type, for the variants that know it.
    static func sortIndex(for type: ConsentItemType) -> Int {
        switch type {
        case .necessary: return 0
        case .functional: return 1
        case .statistical: return 2
        case .marketing: return 3
        case .custom, .privacyPolicy: return 4
        }
    }
}

extension String {
    /// `true` when the string is a URL to load, rather than HTML or plain text to render.
    var isPolicyURL: Bool {
        guard let url = URL(string: self), let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased()) && url.host != nil
    }
}
