import UIKit

@objc
public protocol PrivacyPopupProtocol {
    init(viewModel: PrivacyPopUpViewModel)
}

final class PrivacyPopUpViewController: UIViewController, PrivacyPopupProtocol {
    private lazy var navigationBar: UINavigationBar = {
        let bar = UINavigationBar()
        bar.isTranslucent = true
        bar.delegate = self.viewModel
        bar.backgroundColor = .navigationBarbackground
        bar.items = [self.barItem]
        return bar
    }()
    
    private lazy var barItem: UINavigationItem = {
        let item = UINavigationItem()
        item.leftBarButtonItem = UIBarButtonItem(title: "Accept selected", style: .plain, target: self, action: #selector(acceptSelected))
        item.rightBarButtonItem = UIBarButtonItem(title: "Accept all", style: .plain, target: self, action: #selector(acceptAll))
        item.leftBarButtonItem?.tintColor = accentColor
        item.rightBarButtonItem?.tintColor = accentColor
        
        return item
    }()
    
    private lazy var titleView: UILabel = {
        let view = UILabel()
        view.text = "Privacy"
        view.adjustsFontForContentSizeCategory = true
        view.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: fontSet.largeTitle)
        return view
    }()
    
    private lazy var readModeButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("Read more", for: .normal)
        btn.tintColor = accentColor
        btn.setTitleColor(accentColor, for: .normal)
        btn.addTarget(self, action: #selector(openPrivacyPolicy), for: .touchUpInside)
        btn.titleLabel?.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: fontSet.bold)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        return btn
    }()
    
    private lazy var privacyDescription: UILabel = {
        let label = UILabel()
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: fontSet.bold)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var poweredByLabel: UILabel = {
        let label = UILabel()
        let powered = NSAttributedString(string: "Powered by ",
                                         attributes: [.font: UIFont.systemFont(ofSize: 10, weight: .regular),
                                                      .foregroundColor: UIColor.lightGray])
        
        let cookie = NSAttributedString(string: "Cookie Information",
                                        attributes: [.font: UIFont.systemFont(ofSize: 10, weight: .bold),
                                                     .foregroundColor: UIColor.lightGray])
        let combined = NSMutableAttributedString(attributedString: powered)
        combined.append(cookie)
        label.attributedText = combined
        
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private var privacyPolicyLongtext = ""
    private let tableView = UITableView()
    private lazy var buttonsView = { PopUpButtonsView(accentColor: accentColor) }()
    private let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    private let accentColor: UIColor
    private let viewModel: PrivacyPopUpViewModelProtocol
    private var sections = [Section]()
    private let fontSet: FontSet
    
    init(viewModel: PrivacyPopUpViewModelProtocol, accentColor: UIColor, fontSet: FontSet) {
        self.viewModel = viewModel
        self.accentColor = accentColor
        self.fontSet = fontSet
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(viewModel: PrivacyPopUpViewModel) {
        self.init(viewModel: viewModel, accentColor: .blue, fontSet: .standard)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.rowHeight = UITableView.automaticDimension
        setupViewModel()
        setupLayout()

    }
        
    private func setupLayout() {
        view.backgroundColor = .popUpBackground
        
        activityIndicator.color = .activityIndicator
        
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()
        
        view.addSubview(navigationBar)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(privacyDescription)
        view.addSubview(readModeButton)
        view.addSubview(titleView)
        view.addSubview(poweredByLabel)
        
        titleView.translatesAutoresizingMaskIntoConstraints = false
        readModeButton.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        privacyDescription.translatesAutoresizingMaskIntoConstraints = false
        poweredByLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            titleView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 15),
            titleView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            privacyDescription.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: 15),
            privacyDescription.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            privacyDescription.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            readModeButton.topAnchor.constraint(equalTo: privacyDescription.bottomAnchor, constant: 15),
            readModeButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            readModeButton.heightAnchor.constraint(equalToConstant: readModeButton.titleLabel?.font.pointSize ?? 14),
            
            tableView.topAnchor.constraint(equalTo: readModeButton.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: poweredByLabel.topAnchor, constant: -2),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            poweredByLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
            poweredByLabel.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -8),
            
        ])
        
        ([
            PopUpConsentsSection.self
        ] as [Section.Type]).forEach { $0.registerCells(in: tableView) }
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupViewModel() {
        viewModel.onDataLoaded = { [weak self] data in
            guard let self = self else { return }
            self.sections = data.sections
            self.tableView.reloadData()
            self.titleView.text = data.title
            
            self.barItem.leftBarButtonItem?.title = data.saveSelectionButtonTitle
            self.barItem.rightBarButtonItem?.title = data.acceptAllButtonTitle
            self.privacyDescription.text = data.privacyDescription
            self.privacyPolicyLongtext = data.privacyPolicyLongtext
            self.readModeButton.setTitle("\(data.readMoreButton) ", for: .normal)
            let chevron = UIImage(named: "chevron", in: .current, compatibleWith: nil)
            self.readModeButton.setImage(chevron, for: .normal)
            self.readModeButton.semanticContentAttribute = .forceRightToLeft
            self.view.accessibilityElements = [self.titleView, self.privacyDescription, self.readModeButton, self.tableView, self.navigationBar]

        }
        
        viewModel.onLoadingChange = { [weak self, activityIndicator] isLoading in
            isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
            self?.setInteractionEnabled(!isLoading)
        }
        
        viewModel.viewDidLoad()
    }
}

extension PrivacyPopUpViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].numberOfCells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        sections[indexPath.section].cell(for: indexPath, in: tableView)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection
                   section: Int) -> String? {
        return section == 0 ? "Required" : "Optional"
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.contentView.backgroundColor = .navigationBarbackground
    }
}

extension PrivacyPopUpViewController {
    @objc func acceptAll() {
        viewModel.acceptAll()
    }
    
    @objc func acceptSelected() {
        viewModel.acceptSelected()
    }
    
    @objc func openPrivacyPolicy() {
        let detailView = PrivacyPolicyDetail(text: privacyPolicyLongtext, accentColor: accentColor)
               
        present(detailView, animated: true)
    }
    
}

extension String {
    init(key: String) {
        self = NSLocalizedString(key, bundle: Bundle(for: PrivacyPopUpViewController.self), comment: "")
    }
}

