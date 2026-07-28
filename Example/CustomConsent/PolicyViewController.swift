import UIKit
import WebKit

/// In-app web view for a policy, shown as a second screen within the consent flow — the same
/// approach the SDK's built-in UI uses (works without a browser app installed).
///
/// `content` may be a URL or raw HTML/plain text: the Privacy Policy comes from the dashboard
/// and can be either, the Cookie Policy is the URL set in `ConsentConfiguration`.
///
/// The SDK's own `PrivacyPolicyDetail` is public and can be used instead of this file:
///
///     present(PrivacyPolicyDetail(text: content, accentColor: ConsentColors.accent,
///                                 title: "Privacy Policy"), animated: true)
///
/// It is kept separate here because `PrivacyPolicyDetail` renders the SDK's own chrome: a
/// "Device identifier" footer, the SDK palette rather than `ConsentColors`, and a navigation
/// bar pinned to the top of the view, so it must be presented as a sheet rather than
/// full screen. Use it if you would rather carry one file less.
final class PolicyViewController: UIViewController {

    private let content: String

    init(content: String) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var navigationBar: UINavigationBar = {
        let bar = UINavigationBar()
        let item = UINavigationItem()
        item.leftBarButtonItem = UIBarButtonItem(
            title: ConsentConfiguration.policyScreenClose,
            style: .plain,
            target: self,
            action: #selector(close)
        )
        item.leftBarButtonItem?.tintColor = ConsentColors.accent
        bar.items = [item]
        bar.backgroundColor = ConsentColors.background
        return bar
    }()

    private lazy var webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ConsentColors.background

        [navigationBar, webView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        if content.isPolicyURL, let url = URL(string: content) {
            webView.load(URLRequest(url: url))
        } else {
            webView.loadHTMLString(content, baseURL: nil)
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
