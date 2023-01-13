import UIKit

final class SubheaderTableViewCell: BaseTableViewCell {
    private let label = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTitle(_ title: String) {
        label.attributedText = NSAttributedString(string: title, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
    }
    
    private func setup() {
        isSeparatorHidden = false
        
        contentView.backgroundColor = .headerBackground
        label.textColor = .privacyCenterText
        label.font = .regular(size: 11)
        
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 27)
        ])
    }
}
