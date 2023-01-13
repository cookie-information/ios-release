import UIKit

extension UIWindow {
    var topViewController: UIViewController? {
        rootViewController?.topViewController
    }
}
