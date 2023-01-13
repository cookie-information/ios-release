import UIKit

final class HeaderTableViewCell: BaseTableViewCell {
    private let label = UILabel()
    private let chevronIconView = UIImageView()
    
    private var title: String?
    private var isExpanded = false
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTitle(_ title: String) {
        self.title = title.uppercased()
        
        updateLabel()
    }
    
    func setIsExpanded(_ isExpanded: Bool, animated: Bool) {
        self.isExpanded = isExpanded
        
        UIView.animate(withDuration: animated ? 0.3 : 0.0) { [chevronIconView] in
            chevronIconView.transform = isExpanded ? .init(rotationAngle: -.pi / 2) : .identity
        }
        
        updateLabel()
    }
    
    private func updateLabel() {
        var attributes: [NSAttributedString.Key: Any] = [
            .kern: 1.2
        ]
        
        if isExpanded {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        label.attributedText = title.map { NSAttributedString(string: $0, attributes: attributes) }
    }
    
    private func setup() {
        isSeparatorHidden = false
        chevronIconView.image = UIImage(named: "headerChevron", in: Bundle(for: Self.self), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        chevronIconView.tintColor = .headerText
        
        contentView.backgroundColor = .headerBackground
        label.textColor = .headerText
        label.font = .regular(size: 13)
        
        contentView.addSubview(label)
        contentView.addSubview(chevronIconView)
        label.translatesAutoresizingMaskIntoConstraints = false
        chevronIconView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 29),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            chevronIconView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 9),
            chevronIconView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -27),
            chevronIconView.centerYAnchor.constraint(equalTo: label.centerYAnchor)
        ])
    }
}
