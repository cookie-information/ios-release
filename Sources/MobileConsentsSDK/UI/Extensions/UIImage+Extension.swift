import UIKit

extension UIImage {
    /// Creates image of rectangle with rounded corners. Image is prepared to be resized in a way which keeps rounded corners untouched.
    /// - Parameter color: Fill color of returned rectangle
    /// - Parameter cornerRadius: Corner radius of returned rectangle
    static func resizableRoundedRect(color: UIColor, cornerRadius: CGFloat) -> UIImage {
        let size = CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0)
        let capInsets = UIEdgeInsets(
            top: cornerRadius,
            left: cornerRadius,
            bottom: cornerRadius,
            right: cornerRadius
        )

        let rect = CGRect(origin: .zero, size: size)

        return UIGraphicsImageRenderer(size: size)
            .image { _ in
                color.setFill()

                let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                path.fill()
            }
            .resizableImage(withCapInsets: capInsets)
    }
}
