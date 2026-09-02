import UIKit

@MainActor
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
    private var notificationObserver: MainThreadNotificationObserver?
    
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
        self.accentColor = accentColor
        self.fontSet = fontSet
        notificationObserver = MainThreadNotificationObserver(
            center: notificationCenter,
            name: ConsentSolutionManager.consentItemSelectionDidChange
        ) { [weak self] in
            guard let self else { return }
            self.onUpdate?(self)
        }
    }
    
    public func selectionDidChange(_ isSelected: Bool) {
        consentItemProvider.markConsentItem(id: id, asSelected: isSelected)
    }
}

public final class PopUpConsentsSection: @MainActor Section {
    @MainActor
    public static func registerCells(in tableView: UITableView) {
        tableView.register(SwitchTableViewCell.self)
    }
    
    public let viewModels: [SwitchCellViewModel]
    
    public init(viewModels: [SwitchCellViewModel]) {
        self.viewModels = viewModels
    }
    
    public var numberOfCells: Int { viewModels.count }
    
    @MainActor
    public func cell(for indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        let cell: SwitchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let viewModel = viewModels[indexPath.row]
        
        cell.setViewModel(viewModel)
        
        return cell
    }
}
