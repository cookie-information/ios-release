import UIKit
import WebKit

public class PrivacyPolicyDetail: UIViewController {
    
    private lazy var navigationBar: UINavigationBar = {
        let bar = UINavigationBar()
        bar.isTranslucent = true
        bar.backgroundColor = .navigationBarbackground
        bar.items = [self.barItem]
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    private lazy var barItem: UINavigationItem = {
        let item = UINavigationItem()
        item.leftBarButtonItem = UIBarButtonItem(image: UIImage(
                                                            named: "xmark",
                                                            in: Bundle.module,
                                                            compatibleWith: nil),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(close))
        
        item.leftBarButtonItem?.tintColor = accentColor
        item.title = self.title
        return item
    }()
    
    private lazy var richTextView: HTMLTextView = {
        let view = HTMLTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .systemFont(ofSize: 14)
        view.isEditable = false
        view.style = StyleConstants.textViewStyle
        return view
    }()
    
    private lazy var webView: WKWebView = {
        let view = WKWebView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var deviceInfoLabel: UILabel = {
        let label = UILabel()
        label.text = "Device identifier:\n\(LocalStorageManager().userId)"
        label.numberOfLines = 2
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .regular(size: 12))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
        label.textColor = .popUpButtonDisabled
        
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(displayDeviceId))
        label.addGestureRecognizer(recognizer)
        
        return label
    }()
    private var accentColor: UIColor
    private var text: String
    
    public init(text: String, accentColor: UIColor,
                title: String) {
        self.accentColor = accentColor
        self.text = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .popUpBackground
        setup()
    }
    
    private func setup() {
        view.addSubview(navigationBar)
        view.addSubview(deviceInfoLabel)
        
        
        var contentConstraints: [NSLayoutConstraint] = [NSLayoutConstraint]()

        if text.isValidURL, let url = URL(string: self.text) {
            view.addSubview(webView)
            contentConstraints = [
                webView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 18),
                webView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: deviceInfoLabel.topAnchor),
            ]
            webView.load(URLRequest(url: url))
        } else {
            view.addSubview(richTextView)
            contentConstraints = [
                richTextView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 18),
                richTextView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                richTextView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                richTextView.bottomAnchor.constraint(equalTo: deviceInfoLabel.topAnchor),
            ]
            if self.text.containsHtml {
                richTextView.htmlText = self.text.wrappedInHtml
            } else {
                richTextView.text = self.text
            }
        }
        NSLayoutConstraint.activate([
            
            navigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            deviceInfoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            deviceInfoLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15),
            deviceInfoLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        NSLayoutConstraint.activate(contentConstraints)
    }
    
    @objc func displayDeviceId() {
        let id = LocalStorageManager().userId
        let alert = UIAlertController(title: "Device Identifier",
                                      message: id,
                                      preferredStyle: .actionSheet)
        
        let closeAction = UIAlertAction(title: "Close", style: .default) { _ in }
        let copyAction = UIAlertAction(title: "Copy to clipboard", style: .default) {_ in
            UIPasteboard.general.setValue(id,
                                          forPasteboardType: "public.plain-text")
        }
        alert.addAction(copyAction)
        alert.addAction(closeAction)
        
        present(alert, animated: true)
        
    }
    
    @objc func close() {
        dismiss(animated: true)
    }
}
