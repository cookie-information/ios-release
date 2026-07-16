import UIKit
import MobileConsentsSDK

/// A fully custom consent screen, presented through the SDK's `customViewType` hook:
///
///     mobileConsents.showPrivacyPopUp(customViewType: CustomConsentViewController.self)
///
/// The SDK keeps handling networking, caching and saving; this class provides only the UI:
///  - a title and one row per category (title, toggle, description),
///    separated by 32pt of vertical spacing instead of divider lines,
///  - action buttons pinned to the bottom of the screen,
///  - "Only Necessary": accepts the required categories, rejects every optional one,
///  - "Save choices":   saves exactly what the user toggled (required categories stay on),
///  - brand blue accent, black/white/grey dark mode (palette in ConsentColors.swift).
public final class CustomConsentViewController: UIViewController, PrivacyPopupProtocol {

    private enum Strings {
        // Hardcoded to match the design. Replace with `data.title` etc. in
        // render(_:) to use the texts configured in the dashboard instead.
        static let title = "Cookie settings"
        static let onlyNecessary = "Only Necessary"
        static let saveChoices = "Save choices"
    }

    private enum Layout {
        static let contentPadding: CGFloat = 24
        static let categorySpacing: CGFloat = 32 // vertical gap between categories
        static let buttonBarPadding: CGFloat = 16
        static let buttonSpacing: CGFloat = 12
        static let buttonHeight: CGFloat = 48
        static let cornerRadius: CGFloat = 8
    }

    private let viewModel: PrivacyPopUpViewModel
    private var categoryModels: [SwitchCellViewModel] = []
    private var descriptionRows: [(label: UILabel, html: String)] = []

    public init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Views

    private lazy var scrollView = UIScrollView()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.categorySpacing
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(
            top: Layout.contentPadding,
            left: Layout.contentPadding,
            bottom: Layout.contentPadding,
            right: Layout.contentPadding
        )
        return stack
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = ConsentColors.title
        label.numberOfLines = 0
        return label
    }()

    private lazy var divider: UIView = {
        let view = UIView()
        view.backgroundColor = ConsentColors.divider
        return view
    }()

    private lazy var onlyNecessaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Strings.onlyNecessary, for: .normal)
        button.setTitleColor(ConsentColors.secondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = Layout.cornerRadius
        button.layer.borderWidth = 1
        button.addTarget(self, action: #selector(onlyNecessaryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var saveChoicesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Strings.saveChoices, for: .normal)
        button.setTitleColor(ConsentColors.onAccent, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = ConsentColors.accent
        button.layer.cornerRadius = Layout.cornerRadius
        button.addTarget(self, action: #selector(saveChoicesTapped), for: .touchUpInside)
        return button
    }()

    private lazy var buttonBar: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [onlyNecessaryButton, saveChoicesButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = Layout.buttonSpacing
        return stack
    }()

    private lazy var loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = ConsentColors.background
        view.isHidden = true
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .large)
        }
        return UIActivityIndicatorView(style: .whiteLarge)
    }()

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupViewModel()
    }

    private func setupLayout() {
        view.backgroundColor = ConsentColors.background

        [scrollView, divider, buttonBar, loadingOverlay].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(activityIndicator)
        activityIndicator.color = ConsentColors.accent

        contentStack.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: divider.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: -Layout.buttonBarPadding),

            buttonBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Layout.buttonBarPadding),
            buttonBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Layout.buttonBarPadding),
            buttonBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.buttonBarPadding),
            buttonBar.heightAnchor.constraint(equalToConstant: Layout.buttonHeight),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])

        updateBorderColors()
    }

    private func setupViewModel() {
        viewModel.onDataLoaded = { [weak self] data in
            self?.render(data)
        }
        viewModel.onLoadingChange = { [weak self] isLoading in
            guard let self = self else { return }
            self.loadingOverlay.isHidden = !isLoading
            isLoading ? self.activityIndicator.startAnimating() : self.activityIndicator.stopAnimating()
        }
        viewModel.viewDidLoad()
    }

    // MARK: - Rendering

    private func render(_ data: PrivacyPopUpData) {
        contentStack.arrangedSubviews.filter { $0 !== titleLabel }.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        descriptionRows = []
        // Sections arrive as [required, optional], so required categories come first.
        categoryModels = data.sections.flatMap { $0.viewModels }
        categoryModels.enumerated().forEach { index, model in
            contentStack.addArrangedSubview(makeCategoryView(for: model, index: index))
        }
    }

    private func makeCategoryView(for model: SwitchCellViewModel, index: Int) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = model.title
        nameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = ConsentColors.title
        nameLabel.numberOfLines = 0

        let toggle = UISwitch()
        toggle.thumbTintColor = .white
        // UISwitch has no off-track color API; the background shows through the track.
        toggle.backgroundColor = ConsentColors.trackOff
        toggle.layer.cornerRadius = toggle.bounds.height / 2
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        if model.isRequired {
            // Required categories are locked on: greyed out and not toggleable.
            toggle.isOn = true
            toggle.isEnabled = false
            toggle.onTintColor = ConsentColors.trackOff
        } else {
            toggle.isOn = model.isSelected
            toggle.onTintColor = ConsentColors.accent
            toggle.tag = index
            toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
            // Keeps the toggle in sync when the selection changes elsewhere.
            model.onUpdate = { [weak toggle] model in
                toggle?.setOn(model.isSelected, animated: true)
            }
        }

        let header = UIStackView(arrangedSubviews: [nameLabel, toggle])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        let descriptionLabel = UILabel()
        descriptionLabel.numberOfLines = 0
        descriptionLabel.attributedText = attributedDescription(html: model.description)
        descriptionRows.append((descriptionLabel, model.description))

        let category = UIStackView(arrangedSubviews: [header, descriptionLabel])
        category.axis = .vertical
        category.spacing = 8
        return category
    }

    /// Category descriptions can contain HTML, so they are rendered as attributed text.
    private func attributedDescription(html: String) -> NSAttributedString {
        let styled = "<style>body { font-family: -apple-system; font-size: 15px; color: \(hexString(of: ConsentColors.categoryDescription)); }</style>\(html)"
        guard let data = styled.data(using: .utf8),
              let attributed = try? NSMutableAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              )
        else {
            return NSAttributedString(string: html, attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: ConsentColors.categoryDescription
            ])
        }
        // The HTML importer appends a trailing newline.
        while attributed.string.hasSuffix("\n") {
            attributed.deleteCharacters(in: NSRange(location: attributed.length - 1, length: 1))
        }
        return attributed
    }

    private func hexString(of color: UIColor) -> String {
        var resolved = color
        if #available(iOS 13.0, *) {
            resolved = color.resolvedColor(with: traitCollection)
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    private func updateBorderColors() {
        var secondary = ConsentColors.secondary
        if #available(iOS 13.0, *) {
            secondary = secondary.resolvedColor(with: traitCollection)
        }
        onlyNecessaryButton.layer.borderColor = secondary.cgColor
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard #available(iOS 13.0, *),
              traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        // CGColor and the parsed HTML don't adapt automatically, so re-resolve them.
        updateBorderColors()
        descriptionRows.forEach { row in
            row.label.attributedText = attributedDescription(html: row.html)
        }
    }

    // MARK: - Actions

    @objc private func toggleChanged(_ toggle: UISwitch) {
        guard categoryModels.indices.contains(toggle.tag) else { return }
        categoryModels[toggle.tag].selectionDidChange(toggle.isOn)
    }

    /// Accepts the required categories, rejects every optional one, saves and closes.
    @objc private func onlyNecessaryTapped() {
        viewModel.rejectAll()
    }

    /// Saves exactly what the user toggled (required categories stay on) and closes.
    @objc private func saveChoicesTapped() {
        viewModel.acceptSelected()
    }
}
