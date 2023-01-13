import UIKit

final class PopUpButtonsView: UIView {
    private let stackView = UIStackView()
    private var accentColor: UIColor
    private var viewModels = [PopUpButtonViewModelProtocol]()
    
    init(accentColor: UIColor) {
        self.accentColor = accentColor
        super.init(frame: .zero)
        setup()
    }
   
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setButtonViewModels(_ viewModels: [PopUpButtonViewModelProtocol]) {
        self.viewModels = viewModels
        
        stackView.arrangedSubviews.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        viewModels
            .enumerated()
            .map(button)
            .forEach(stackView.addArrangedSubview)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 12.0, *) {
            guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else {
                return
            }
        } else {
            // Fallback on earlier versions
        }
        
        stackView
            .subviews
            .compactMap { $0 as? UIButton }
            .forEach { button in
                button.setBackgroundImage(.resizableRoundedRect(color: .popUpButtonEnabled, cornerRadius: 4), for: .normal)
                button.setBackgroundImage(.resizableRoundedRect(color: .popUpButtonDisabled, cornerRadius: 4), for: .disabled)
            }
    }
    
    private func setup() {
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15)
        ])
    }
    
    private func button(index: Int, viewModel: PopUpButtonViewModelProtocol) -> UIButton {
        let button = UIButton(type: .custom)
        
        button.tag = index
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        button.setTitle(viewModel.title, for: .normal)
        button.setTitleColor(.popUpButtonTitle, for: .normal)
        button.setBackgroundImage(.resizableRoundedRect(color: accentColor, cornerRadius: 4), for: .normal)
        button.setBackgroundImage(.resizableRoundedRect(color: .popUpButtonDisabled, cornerRadius: 4), for: .disabled)
        button.titleLabel?.font = .medium(size: 15)
        button.isEnabled = viewModel.isEnabled
        
        viewModel.onIsEnabledChange = { [weak button] isEnabled in
            button?.isEnabled = isEnabled
        }
        
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        return button
    }
    
    @objc private func buttonTapped(_ button: UIButton) {
        let index = button.tag
        let viewModel = viewModels[index]
        
        viewModel.onTap()
    }
}
