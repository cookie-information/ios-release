import UIKit

final class SwitchTableViewCell: BaseTableViewCell {
    var valueChanged: ((Bool) -> Void)?
    private var viewModel: SwitchCellViewModel?

    private let uiSwitch = UISwitch()
    
    private lazy var titleView: UILabel =  {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .systemFont(ofSize: 17, weight: .regular)
        return label
    }()
    
    private lazy var descriptionView: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.isEnabled = false
        
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        titleView.text = nil
        descriptionView.text = nil
        uiSwitch.isOn = false
        valueChanged = nil
        isSeparatorHidden = true
    }
    
    func setViewModel(_ viewModel: SwitchCellViewModel) {
        self.viewModel = viewModel
        
        titleView.text = viewModel.title
        titleView.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: viewModel.fontSet.body.withSize(17))
        titleView.accessibilityLabel = "\(viewModel.title) \n \(viewModel.description)"

        
        descriptionView.text = viewModel.description
        descriptionView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: viewModel.fontSet.body)
        setIsSelected(viewModel.isRequired || viewModel.isSelected) //required settings will be selected by default
        uiSwitch.onTintColor = viewModel.accentColor
        uiSwitch.isEnabled = !viewModel.isRequired
        valueChanged = { [weak viewModel] isSelected in
            viewModel?.selectionDidChange(isSelected)
        }
        
        viewModel.onUpdate = { [weak self] viewModel in
            self?.setIsSelected(viewModel.isSelected)
        }
        
        
    }
    
    func setIsSelected(_ isSelected: Bool) {
        uiSwitch.isOn = isSelected
        
    }
    
    func setText(_ text: String, isRequired: Bool) {
        
    }
    
    
    func setValue(_ value: Bool) {
        uiSwitch.isOn = value
    }
    
    private func setup() {
        accessibilityElements = [titleView, uiSwitch]
        selectionStyle = .none
        self.isSeparatorHidden = false
        uiSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        
        contentView.addSubview(titleView)
        contentView.addSubview(uiSwitch)
        contentView.addSubview(descriptionView)
        
        titleView.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        titleView.translatesAutoresizingMaskIntoConstraints = false
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        
        
        NSLayoutConstraint.activate([
            titleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            // Setting constraint to `uiSwitch.leadingAnchor` causes layout to
            // break when cell is reused
            titleView.trailingAnchor.constraint(equalTo: uiSwitch.leadingAnchor, constant: -16),
            uiSwitch.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            uiSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -29),
            
            descriptionView.topAnchor.constraint(equalTo: uiSwitch.bottomAnchor, constant: 8),
            descriptionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            descriptionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            descriptionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
    }

    
    @objc private func switchValueChanged() {
        valueChanged?(uiSwitch.isOn)
    }
}
