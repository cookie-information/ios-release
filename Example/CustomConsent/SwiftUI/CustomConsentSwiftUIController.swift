import SwiftUI
import UIKit
import MobileConsentsSDK

/// Observable state that bridges the SDK's `PrivacyPopUpViewModel` to `CustomConsentView`.
@available(iOS 15.0, *)
final class ConsentScreenState: ObservableObject {

    struct Category: Identifiable {
        let id: Int
        let title: String
        let description: AttributedString
        let isRequired: Bool
        var isOn: Bool
    }

    @Published var isLoading = true
    @Published var categories: [Category] = []

    var onOnlyNecessary: () -> Void = {}
    var onSaveChoices: () -> Void = {}

    private var models: [SwitchCellViewModel] = []

    /// Sections arrive as [required, optional], so required categories come first.
    func load(sections: [PopUpConsentsSection]) {
        models = sections.flatMap { $0.viewModels }
        categories = models.enumerated().map { index, model in
            Category(
                id: index,
                title: model.title,
                description: Self.attributedDescription(fromHTML: model.description),
                isRequired: model.isRequired,
                isOn: model.isRequired || model.isSelected
            )
        }
        // Keeps the toggles in sync when the selection changes elsewhere.
        models.enumerated().forEach { index, model in
            model.onUpdate = { [weak self] model in
                self?.categories[index].isOn = model.isSelected
            }
        }
    }

    func setSelected(_ isOn: Bool, for id: Int) {
        guard models.indices.contains(id) else { return }
        categories[id].isOn = isOn
        models[id].selectionDidChange(isOn)
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

/// SwiftUI variant of the custom consent screen, presented through the SDK's
/// `customViewType` hook — exactly like the UIKit `CustomConsentViewController`:
///
///     mobileConsents.showPrivacyPopUp(customViewType: CustomConsentSwiftUIController.self)
///
/// The SDK keeps handling networking, caching and saving; this class only hosts
/// `CustomConsentView` and forwards its actions to the SDK's view model.
@available(iOS 15.0, *)
public final class CustomConsentSwiftUIController: UIViewController, PrivacyPopupProtocol {

    private let viewModel: PrivacyPopUpViewModel
    private let state = ConsentScreenState()

    public init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ConsentColors.background

        let host = UIHostingController(rootView: CustomConsentView(state: state))
        host.view.backgroundColor = ConsentColors.background
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        state.onOnlyNecessary = { [weak self] in
            // Accepts the required categories, rejects every optional one, saves and closes.
            self?.viewModel.rejectAll()
        }
        state.onSaveChoices = { [weak self] in
            // Saves exactly what the user toggled (required categories stay on) and closes.
            self?.viewModel.acceptSelected()
        }
        viewModel.onDataLoaded = { [weak self] data in
            self?.state.load(sections: data.sections)
        }
        viewModel.onLoadingChange = { [weak self] isLoading in
            self?.state.isLoading = isLoading
        }
        viewModel.viewDidLoad()
    }
}
