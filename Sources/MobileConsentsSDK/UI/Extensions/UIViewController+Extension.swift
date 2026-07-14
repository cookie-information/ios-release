import UIKit

extension UIViewController {
    var topViewController: UIViewController {
        presentedViewController?.topViewController ?? self
    }

    func setInteractionEnabled(_ enabled: Bool) {
        (tabBarController ?? navigationController ?? self).view.isUserInteractionEnabled = enabled
    }

    /// Extra top spacing that keeps the pop-up navigation bar clear of the sheet
    /// grabber on iOS 26. Sheets on older systems report a zero top safe-area
    /// inset there, and the bar must stay flush with the sheet's top edge as it
    /// always did, so no spacing is added below iOS 26.
    var popUpNavigationBarTopInset: CGFloat {
        if #available(iOS 26.0, *) {
            return 12
        }
        return 0
    }
}
