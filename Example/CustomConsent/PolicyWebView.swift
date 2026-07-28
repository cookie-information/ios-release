import SwiftUI

/// Policy UI shared by both SwiftUI variants: the intro paragraph with the policy links and
/// the screen the links open.
///
/// There is no SwiftUI-native web view on iOS 15, so the policy content is rendered by
/// `PolicyViewController` (`WKWebView`) — the same as the SDK's built-in UI does.
@available(iOS 15.0, *)
struct PolicyWebView: UIViewControllerRepresentable {
    let content: String

    func makeUIViewController(context: Context) -> PolicyViewController {
        PolicyViewController(content: content)
    }

    func updateUIViewController(_ controller: PolicyViewController, context: Context) {}
}

/// A policy to present, identified so it can drive a `.fullScreenCover`.
@available(iOS 15.0, *)
struct PolicyContent: Identifiable {
    let content: String
    var id: String { content }
}

/// Intro paragraph with tappable Privacy Policy and Cookie Policy links. A label whose content
/// is missing is shown as plain (non-tappable) text.
@available(iOS 15.0, *)
struct PolicyIntroText: View {
    /// Privacy policy content from the dashboard: a URL or raw HTML.
    let privacyPolicy: String
    let onOpenPolicy: (String) -> Void

    var body: some View {
        Text(attributedIntro)
            .font(.system(size: 14))
            .foregroundColor(Color(uiColor: ConsentColors.categoryDescription))
            .environment(\.openURL, OpenURLAction { url in
                switch url {
                case ConsentConfiguration.privacyPolicyLink:
                    onOpenPolicy(privacyPolicy)
                case ConsentConfiguration.cookiePolicyLink:
                    ConsentConfiguration.cookiePolicyURL.map { onOpenPolicy($0.absoluteString) }
                default:
                    return .systemAction
                }
                return .handled
            })
    }

    private var attributedIntro: AttributedString {
        var text = AttributedString(ConsentConfiguration.intro + " ")
        text.append(link(
            ConsentConfiguration.privacyPolicyLabel,
            url: privacyPolicy.isEmpty ? nil : ConsentConfiguration.privacyPolicyLink
        ))
        text.append(AttributedString(" \(ConsentConfiguration.and) "))
        text.append(link(
            ConsentConfiguration.cookiePolicyLabel,
            url: ConsentConfiguration.cookiePolicyURL == nil ? nil : ConsentConfiguration.cookiePolicyLink
        ))
        text.append(AttributedString("."))
        return text
    }

    private func link(_ label: String, url: URL?) -> AttributedString {
        var part = AttributedString(label)
        part.font = .system(size: 14, weight: .bold)
        part.foregroundColor = Color(uiColor: ConsentColors.secondary)
        part.underlineStyle = .single
        part.link = url
        return part
    }
}
