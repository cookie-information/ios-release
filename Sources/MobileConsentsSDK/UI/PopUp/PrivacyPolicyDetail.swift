import UIKit

internal class PrivacyPolicyDetail: UIViewController {
    
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
        item.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "xmark", in: .module, compatibleWith: nil), style: .plain, target: self, action: #selector(close))
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
    
    private var accentColor: UIColor
    
    init(text: String, accentColor: UIColor) {
        self.accentColor = accentColor
        super.init(nibName: nil, bundle: nil)
        webView.htmlText = text
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .popUpBackground
        setup()
    }
    
    private func setup() {
        view.addSubview(webView)
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 18),
            webView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
            navigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
                               
    @objc func close() {
        dismiss(animated: true)
    }
}
