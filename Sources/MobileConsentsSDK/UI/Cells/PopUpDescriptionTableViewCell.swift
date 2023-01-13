import UIKit

final class PopUpDescriptionTableViewCell: UITableViewCell {
    private let textView = HTMLTextView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setText(_ text: String) {
        textView.htmlText = text
    }
    
    private func setup() {
        selectionStyle = .none
        
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.style = StyleConstants.textViewStyle
        
        contentView.addSubview(textView)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
        ])
    }
}
