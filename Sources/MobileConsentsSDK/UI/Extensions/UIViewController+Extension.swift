import UIKit

extension UIViewController {
    var topViewController: UIViewController {
        presentedViewController?.topViewController ?? self
    }
    
    func setInteractionEnabled(_ enabled: Bool) {
        (tabBarController ?? navigationController ?? self).view.isUserInteractionEnabled = enabled
    }
}

struct ErrorAlertModel {
    let retryHandler: () -> Void
    let cancelHandler: (() -> Void)?
}

extension UIViewController {
    func showErrorAlert(_ model: ErrorAlertModel) {
        let alert = UIAlertController(
            title: "errorAlert.title".localized,
            message: "errorAlert.message".localized,
            preferredStyle: .alert
        )
        
        let retryAction = UIAlertAction(
            title: "errorAlert.retryButtonTitle".localized,
            style: .default,
            handler: { _ in model.retryHandler() }
        )
        
        let cancelAction = UIAlertAction(
            title: "errorAlert.cancelButtonTitle".localized,
            style: .cancel,
            handler: { _ in model.cancelHandler?() }
        )
        
        alert.addAction(retryAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
}
