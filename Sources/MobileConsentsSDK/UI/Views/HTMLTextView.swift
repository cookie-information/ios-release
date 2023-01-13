import UIKit

final class HTMLTextView: UITextView {
    // Believe it or not, this resolves issue with UITableView animation glitches
    // when reloading sections with cells containing HTMLTextView
    private static let attributedStringCache = NSCache<NSString, NSAttributedString>()
    
    struct StyleValue: ExpressibleByStringLiteral {
        let expression: () -> String
        
        init(stringLiteral value: String) {
            self.expression = { value }
        }
        
        init(_ expression: @escaping () -> String) {
            self.expression = expression
        }
    }
    
    var style: [String: [String: StyleValue]] = [:] {
        didSet {
            updateHTML()
        }
    }
    
    var htmlText: String? {
        didSet {
            updateHTML()
        }
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        linkTextAttributes = [:]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle ||
                traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
                // Fixes crash caused by trait collection change when link in text view is tapped and external Safari opens
                DispatchQueue.main.async {
                    self.updateHTML()
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    private func updateHTML() {
        guard let htmlText = htmlText else {
            attributedText = nil
            
            return
        }
        
        let htmlTemplate = """
            <!doctype html>
            <html>
              <head>
                <style>
                  \(css(from: style))
                </style>
              </head>
              <body>
                \(htmlText)
              </body>
            </html>
            """
        
        let cacheKey = htmlTemplate as NSString
        
        if let cached = Self.attributedStringCache.object(forKey: cacheKey) {
            attributedText = cached
        } else if let attributedString = NSAttributedString.fromHTML(htmlTemplate) {
            Self.attributedStringCache.setObject(attributedString, forKey: cacheKey)
            
            attributedText = attributedString
        }
    }
    
    private func css(from style: [String: [String: StyleValue]]) -> String {
        var css = ""
        
        for (tag, styles) in style {
            css += tag + "{"
            
            for (key, value) in styles {
                css += key + ":" + value.expression() + ";"
            }
            
            css += "}"
        }
        
        return css
    }
}
