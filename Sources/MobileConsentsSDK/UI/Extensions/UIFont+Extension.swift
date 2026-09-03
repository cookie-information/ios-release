import UIKit

extension UIFont {
    static func regular(size: CGFloat) -> UIFont {
        fontWithFallback(name: "Rubik-Regular", size: size, fallbackWeight: .regular)
    }
    
    private static func fontWithFallback(name: String, size: CGFloat, fallbackWeight: UIFont.Weight) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
    }
}
