import UIKit
import MobileConsentsSDK

final class CustomPopup: UIViewController, PrivacyPopupProtocol {
    
    let viewModel: PrivacyPopUpViewModel
    var data: PrivacyPopUpData?
    
    private lazy var table: UITableView = {
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        return table
    }()
    
    lazy var buttonGroup: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [rejectAllBtn, saveBtn, acceptAllBtn])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        return stack
    }()
    
    lazy var acceptAllBtn: UIButton = {
        let btn = UIButton(type: .roundedRect)
        btn.backgroundColor = .systemGreen
        btn.setTitle("Accept All", for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 7
        btn.addTarget(self.viewModel, action: #selector(viewModel.acceptAll), for: .touchUpInside)
        return btn
    }()
    
    lazy var saveBtn: UIButton = {
        let btn = UIButton(type: .roundedRect)
        btn.backgroundColor = .systemOrange
        btn.setTitle("Save selection", for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 7
        btn.addTarget(self.viewModel, action: #selector(viewModel.acceptSelected), for: .touchUpInside)
        return btn
    }()
    
    lazy var rejectAllBtn: UIButton = {
        let btn = UIButton(type: .roundedRect)
        btn.backgroundColor = .systemRed
        btn.layer.cornerRadius = 7
        btn.setTitle("Reject All", for: .normal)
        btn.tintColor = .white
        btn.addTarget(self.viewModel, action: #selector(viewModel.rejectAll), for: .touchUpInside)
        return btn
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        return label
    }()
    
    private lazy var acceptAllButton: UIButton = {
       let btn = UIButton()
        btn.titleLabel?.text = ""
        
        return btn
    }()
    
    
    init(viewModel: PrivacyPopUpViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: nil, bundle: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupViewModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func setup() {
        view.backgroundColor = .systemBackground
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            table.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            table.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: buttonGroup.topAnchor),
            
            buttonGroup.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            buttonGroup.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -15),
            buttonGroup.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 15),
            buttonGroup.heightAnchor.constraint(equalToConstant: 35)
        ])
        
        table.dataSource = self
        table.delegate = self
    }
    
    private func setupViewModel() {
        viewModel.onDataLoaded = { [weak self] data in
            guard let self = self else { return }
            self.titleLabel.text = data.title
            self.data = data
            self.table.reloadData()
        }
        viewModel.viewDidLoad()
    }
}

extension CustomPopup: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.data?.sections[section].numberOfCells ?? 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        self.data?.sections.count ?? 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = ToggleCell(style: .default, reuseIdentifier: "something")
        guard let data = data else { return cell }
        
        cell.configure(with: data.sections[indexPath.section].viewModels[indexPath.row])
        
        return cell
    }
}

final class ToggleCell: UITableViewCell {
    
    lazy var toggle: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toggle)
        return toggle
    }()
    
    lazy var titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lbl)
        return lbl
    }()
    
    var viewModel: SwitchCellViewModel?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        NSLayoutConstraint.activate([
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant:  -20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -15)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with viewModel: SwitchCellViewModel) {
        self.toggle.isOn = viewModel.isSelected
        self.toggle.isEnabled = !viewModel.isRequired
        self.titleLabel.text = viewModel.title
        self.viewModel = viewModel
        self.toggle.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
    }
    
    @objc func selectionChanged() {
        self.viewModel?.selectionDidChange(toggle.isOn)
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        self.largeContentTitle = nil
        self.toggle.isOn = false
    }
    
    
}
