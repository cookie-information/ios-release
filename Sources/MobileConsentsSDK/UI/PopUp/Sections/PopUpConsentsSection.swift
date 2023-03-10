import UIKit

public final class PopUpConsentViewModel: SwitchCellViewModel {
    public var fontSet: FontSet
    public var accentColor: UIColor
    public let title: String
    public let description: String
    public let isRequired: Bool
    
    public var isSelected: Bool { consentItemProvider.isConsentItemSelected(id: id)  || consentItemProvider.isConsentItemRequired(id: id)}
    public var onUpdate: ((SwitchCellViewModel) -> Void)?
    
    public let id: String
    private let consentItemProvider: ConsentItemProvider
    private let notificationCenter: NotificationCenter
    
    private var observationToken: Any?
    
    init(
        id: String,
        title: String,
        description: String,
        isRequired: Bool,
        consentItemProvider: ConsentItemProvider,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        accentColor: UIColor,
        fontSet: FontSet
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isRequired = isRequired
        self.consentItemProvider = consentItemProvider
        self.notificationCenter = notificationCenter
        self.accentColor = accentColor
        self.fontSet = fontSet
        observationToken = notificationCenter.addObserver(
            forName: ConsentSolutionManager.consentItemSelectionDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.onUpdate?(self)
        }
    }
    
    deinit {
        if let observationToken = observationToken {
            notificationCenter.removeObserver(observationToken)
        }
    }
    
    public func selectionDidChange(_ isSelected: Bool) {
        consentItemProvider.markConsentItem(id: id, asSelected: isSelected)
    }
}

public final class PopUpConsentsSection: Section {
    public static func registerCells(in tableView: UITableView) {
        tableView.register(SwitchTableViewCell.self)
    }
    
    public let viewModels: [SwitchCellViewModel]
    
    public init(viewModels: [SwitchCellViewModel]) {
        self.viewModels = viewModels
    }
    
    public var numberOfCells: Int { viewModels.count }
    
    public func cell(for indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        let cell: SwitchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let viewModel = viewModels[indexPath.row]
        
        cell.setViewModel(viewModel)
        
        return cell
    }
}
