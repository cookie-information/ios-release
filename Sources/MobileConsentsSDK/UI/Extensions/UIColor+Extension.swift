import UIKit

extension UIColor {
    static let consentText = UIColor.adaptive(light: .init(hex: 0x616263), dark: .init(hex: 0xA8A8A9))
    static let link = UIColor.adaptive(light: .black, dark: .white)
    static let privacyCenterSeparator = UIColor.adaptive(light: .init(hex: 0xE4E8F0), dark: .init(hex: 0x47474A))
    static let popUpBackground = UIColor.adaptive(light: .white, dark: .init(hex: 0x1D1D1D))
    static let popUpButtonEnabled = UIColor.adaptive(light: .black, dark: .white)
    static let popUpButtonDisabled = UIColor.adaptive(light: .init(hex: 0xC1C1C1), dark: .init(hex: 0x989899))
    static let activityIndicator = UIColor.adaptive(light: .init(hex: 0x2E5BFF), dark: .white)
    static let navigationBarbackground = UIColor.adaptive(light: .init(hex: 0xFCFCFC), dark: .init(hex: 0x2A2A2A))
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0
        
        return String(format: "#%06x", rgb)
    }
    
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }

    static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor(dynamicProvider: { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return dark
            default: return light
            }
        })
    }
}
