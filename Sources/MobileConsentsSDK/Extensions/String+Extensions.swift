import Foundation

extension String {
    var isValidURL:Bool {
        let urlPattern = #"^(https?|ftp)://[^\s/$.?#].[^\s]*$"#
        let regex = try! NSRegularExpression(pattern: urlPattern)
        
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

