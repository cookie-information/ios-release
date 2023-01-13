import UIKit

extension UIView {
    static func separator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .privacyCenterSeparator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        return separator
    }
}
