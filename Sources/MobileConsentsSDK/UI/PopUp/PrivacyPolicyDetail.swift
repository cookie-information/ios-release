import UIKit

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
        item.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "xmark", in: .current, compatibleWith: nil), style: .plain, target: self, action: #selector(close))
        item.leftBarButtonItem?.tintColor = accentColor
        
        item.title = "Privacy policy"
        return item
    }()
    
    private lazy var webView: HTMLTextView = {
        let view = HTMLTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .systemFont(ofSize: 14)
        view.isEditable = false
        view.style = StyleConstants.textViewStyle
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
    
    public init(text: String, accentColor: UIColor) {
        self.accentColor = accentColor
        super.init(nibName: nil, bundle: nil)
        webView.htmlText = text.wrappedInHtml
        
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
        view.addSubview(webView)
        view.addSubview(navigationBar)
        view.addSubview(deviceInfoLabel)
    
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 18),
            webView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: deviceInfoLabel.topAnchor),
            navigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            deviceInfoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            deviceInfoLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15),
            deviceInfoLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
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
