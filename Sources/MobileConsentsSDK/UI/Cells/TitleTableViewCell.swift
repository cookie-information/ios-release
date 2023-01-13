import UIKit

final class TitleTableViewCell: UITableViewCell {
    private let label = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTitle(_ title: String) {
        label.attributedText = NSAttributedString(string: title.uppercased(), attributes: [.kern: 1.2])
    }
    
    private func setup() {
        contentView.backgroundColor = .privacyCenterBackground
        label.textColor = .privacyCenterText
        label.font = .medium(size: 13)
        
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 27)
        ])
    }
}
