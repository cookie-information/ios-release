import UIKit

class BaseViewController: UIViewController {
    private var progressAlertViewController: UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.barTintColor = .white
        title = "Mobile Consents"
    }
    
    func showError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            let controller = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            controller.addAction(okAction)
        
            self?.present(controller, animated: true, completion: nil)
        }
    }
    
    func showMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            let controller = UIAlertController(title: "Message", message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            controller.addAction(okAction)
        
            self?.present(controller, animated: true, completion: nil)
        }
    }
    
    func showProgressView() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "Loading ...", message: nil, preferredStyle: .alert)
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.isUserInteractionEnabled = false
            activityIndicator.startAnimating()

            alert.view.addSubview(activityIndicator)
            alert.view.heightAnchor.constraint(equalToConstant: 95).isActive = true

            activityIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor, constant: 0).isActive = true
            activityIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20).isActive = true

            self?.progressAlertViewController = alert
            
            self?.present(alert, animated: true)
        }
    }
    
    func dismissProgressView(_ completion: (() -> Void)?) {
        DispatchQueue.main.async { [weak self] in
            self?.progressAlertViewController?.dismiss(animated: true, completion: completion)
        }
    }
}
