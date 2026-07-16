import UIKit

/// Every color the custom consent screen uses. Dark mode sticks to
/// black/white/grey tones and the accent stays brand blue.
enum ConsentColors {
    /// Brand color: #093A5C
    static let brandBlue = rgb(0x093A5C)

    static let background = dynamic(light: .white, dark: rgb(0x303336))
    static let title = dynamic(light: brandBlue, dark: .white)
    static let categoryDescription = dynamic(light: rgb(0x444444), dark: rgb(0xC7C7C7))
    /// Toggle-on track + primary "Save choices" button
    static let accent = brandBlue
    /// Text on the accent
    static let onAccent = UIColor.white
    /// Outlined "Only Necessary" button
    static let secondary = dynamic(light: brandBlue, dark: .white)
    /// Toggle-off track, also used for locked "required" toggles
    static let trackOff = dynamic(light: rgb(0xDCE1E6), dark: rgb(0x5C6166))
    /// Line separating the scrolling content from the bottom action buttons
    static let divider = dynamic(light: rgb(0xEDEDED), dark: rgb(0x4A4E52))

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        }
        return light
    }
}
