import UIKit

public extension UIViewController {
    var topViewController: UIViewController {
        presentedViewController?.topViewController ?? self
    }
    
    func setInteractionEnabled(_ enabled: Bool) {
        (tabBarController ?? navigationController ?? self).view.isUserInteractionEnabled = enabled
    }
}

public struct ErrorAlertModel {
    let retryHandler: () -> Void
    let cancelHandler: (() -> Void)?
}
