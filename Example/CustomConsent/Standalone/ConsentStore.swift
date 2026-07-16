import SwiftUI
import MobileConsentsSDK

/// State and logic for the standalone (pure SwiftUI) consent screen.
///
/// Unlike the other two variants, this one does not go through the SDK's
/// `customViewType` hook — it talks to the SDK's low-level API directly
/// (`fetchConsentSolution` / `postConsent`), so no `UIViewController` is involved
/// and the app controls the presentation (e.g. with `.fullScreenCover`).
///
/// Trade-off: the SDK does not expose the stored solution version, so there is no
/// full equivalent of `showPrivacyPopUpIfNeeded` here. `hasSavedConsents` only
/// tells whether *any* consents are stored locally — if the solution is later
/// changed in the dashboard, this variant will not re-prompt the user.
@available(iOS 15.0, *)
final class ConsentStore: ObservableObject {

    struct Category: Identifiable {
        let item: ConsentItem
        let title: String
        let description: AttributedString
        var isOn: Bool

        var id: String { item.id }
        var isRequired: Bool { item.required }
    }

    @Published private(set) var isLoading = false
    @Published var categories: [Category] = []

    /// Called with the saved consents after a successful save. Close the screen here.
    var onFinished: ([UserConsent]) -> Void = { _ in }
    /// Called when loading or saving fails. Close the screen here.
    var onError: (Error) -> Void = { _ in }

    private let mobileConsents: MobileConsents
    private var solution: ConsentSolution?

    init(mobileConsents: MobileConsents) {
        self.mobileConsents = mobileConsents
    }

    /// `true` when any consents are stored locally. See the note in the class
    /// documentation — this is weaker than `showPrivacyPopUpIfNeeded`.
    var hasSavedConsents: Bool {
        !mobileConsents.getSavedConsents().isEmpty
    }

    func load() {
        isLoading = true
        mobileConsents.synchronizeIfNeeded() // re-send a previously failed save, if any
        mobileConsents.fetchConsentSolution { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let solution):
                    self.solution = solution
                    self.buildCategories(from: solution)
                case .failure(let error):
                    self.onError(error)
                }
            }
        }
    }

    /// Saves exactly what the user toggled (required categories stay on).
    func saveChoices() {
        save()
    }

    /// Accepts the required categories, rejects every optional one, then saves.
    func onlyNecessary() {
        categories.indices.forEach { categories[$0].isOn = categories[$0].isRequired }
        save()
    }

    private func buildCategories(from solution: ConsentSolution) {
        let saved = Dictionary(
            mobileConsents.getSavedConsents().map { ($0.consentItem.id, $0.isSelected) },
            uniquingKeysWith: { first, _ in first }
        )
        // The privacy policy is a separate entry, not a toggleable category.
        let items = solution.consentItems.filter { $0.type != .privacyPolicy }
        // Required categories first.
        let ordered = items.filter(\.required) + items.filter { !$0.required }
        categories = ordered.map { item in
            Category(
                item: item,
                title: item.translations.primaryTranslation().shortText,
                description: Self.attributedDescription(fromHTML: item.translations.primaryTranslation().longText),
                isOn: item.required || (saved[item.id] ?? false)
            )
        }
    }

    private func save() {
        guard let solution = solution else { return }
        isLoading = true
        let userConsents = categories.map {
            UserConsent(consentItem: $0.item, isSelected: $0.isOn || $0.isRequired)
        }
        let consent = Consent(
            consentSolutionId: solution.id,
            consentSolutionVersionId: solution.versionId,
            userConsents: userConsents
        )
        mobileConsents.postConsent(consent) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    // The SDK stored the consents locally anyway and will re-send
                    // them on the next synchronizeIfNeeded().
                    self.onError(error)
                } else {
                    self.onFinished(self.mobileConsents.getSavedConsents())
                }
            }
        }
    }

    /// Category descriptions can contain HTML, so they are parsed into attributed text.
    /// The importer's fixed colors are dropped so the palette (and dark mode) applies.
    private static func attributedDescription(fromHTML html: String) -> AttributedString {
        let styled = "<style>body { font-family: -apple-system; font-size: 15px; }</style>\(html)"
        guard let data = styled.data(using: .utf8),
              let parsed = try? NSMutableAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              )
        else {
            return AttributedString(html)
        }
        // The HTML importer appends a trailing newline.
        while parsed.string.hasSuffix("\n") {
            parsed.deleteCharacters(in: NSRange(location: parsed.length - 1, length: 1))
        }
        var attributed = AttributedString(parsed)
        attributed.foregroundColor = nil
        attributed.uiKit.foregroundColor = nil
        return attributed
    }
}
