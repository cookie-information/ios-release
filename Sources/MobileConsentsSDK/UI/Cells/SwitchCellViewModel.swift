import UIKit

public protocol SwitchCellViewModel: AnyObject {
    var title: String { get }
    var description: String { get }
    var isRequired: Bool { get }
    var isSelected: Bool { get }
    var onUpdate: ((SwitchCellViewModel) -> Void)? { get set }
    var accentColor: UIColor { get set }
    var fontSet: FontSet { get set }
    func selectionDidChange(_ isSelected: Bool)
}
