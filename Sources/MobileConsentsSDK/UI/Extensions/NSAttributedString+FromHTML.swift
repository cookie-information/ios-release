import Foundation

extension NSAttributedString {
     static func fromHTML(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else {
            return nil
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSMutableAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else { return nil }
        
        if attributedString.string.last == "\n" {
            attributedString.deleteCharacters(in: NSRange(location: attributedString.length - 1, length: 1))
        }
        
        return attributedString
    }
}
