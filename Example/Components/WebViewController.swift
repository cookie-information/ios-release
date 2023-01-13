import UIKit
import WebKit
import MobileConsentsSDK

final class WebViewController: UIViewController {
    internal init(consents: MobileConsents) {
        self.consents = consents
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private var consents: MobileConsents
    
    lazy var scriptContent: String = {
        
        let consentSet = self.consents.getSavedConsents()
        var script = ""

        consentSet.forEach { userConsent in
            let consentGiven = userConsent.isSelected

            switch userConsent.purpose {
            case .functional:
                script.append("CookieInformation.changeCategoryConsentDecision('cookie_cat_functional',\(consentGiven));")
            case .marketing:
                script.append("CookieInformation.changeCategoryConsentDecision('cookie_cat_marketing',\(consentGiven));")
            case .statistical:
                script.append("CookieInformation.changeCategoryConsentDecision('cookie_cat_statistic',\(consentGiven));")
            default: break
            }
        }
        script.append("CookieInformation.submitConsent();")
        return script
    }()

    
    lazy var webView: WKWebView = {
        let view = WKWebView()
        view.navigationDelegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let link = URL(string:"https://www.cookieinformation.com")!
        let request = URLRequest(url: link)
        setup()
        webView.load(request) // Bug in XCode 14 shows threading warning, can be safely ignored
        
    }
    
    private func setup() {
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(self.scriptContent)
    }

}
