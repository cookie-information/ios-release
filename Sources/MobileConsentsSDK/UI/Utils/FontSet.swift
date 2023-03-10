import UIKit

@objc
public class FontSet: NSObject {
    @objc public init(largeTitle: UIFont, body: UIFont, bold: UIFont) {
        self.largeTitle = largeTitle
        self.body = body
        self.bold = bold
    }
    
    public let largeTitle: UIFont
    public let body: UIFont
    public let bold: UIFont
}

@objc public extension FontSet {
    static var standard: FontSet {
        FontSet(largeTitle: .systemFont(ofSize: 34, weight: .bold),
                body: .systemFont(ofSize: 14),
                bold: .systemFont(ofSize: 14, weight: .bold))
    }
}
