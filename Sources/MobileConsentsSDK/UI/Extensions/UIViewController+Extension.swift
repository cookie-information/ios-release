import UIKit

extension UIViewController {
    var topViewController: UIViewController {
        presentedViewController?.topViewController ?? self
    }

    func setInteractionEnabled(_ enabled: Bool) {
        (tabBarController ?? navigationController ?? self).view.isUserInteractionEnabled = enabled
    }

    var popUpNavigationBarTopInset: CGFloat {
        if #available(iOS 26.0, *) {
            return 12
        }
        return 0
    }
}
