import UIKit

class BaseTableViewCell: UITableViewCell {
    var isSeparatorHidden: Bool {
        get { separator.isHidden }
        set { separator.isHidden = newValue }
    }
    
    private let separator = UIView.separator()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
}
