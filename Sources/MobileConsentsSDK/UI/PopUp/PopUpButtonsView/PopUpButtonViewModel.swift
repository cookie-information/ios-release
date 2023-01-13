protocol PopUpButtonViewModelProtocol: AnyObject {
    var title: String { get }
    var isEnabled: Bool { get }
    var onIsEnabledChange: ((Bool) -> Void)? { get set }
    
    func onTap()
}

protocol PopUpButtonViewModelDelegate: AnyObject {
    func buttonTapped(type: PopUpButtonViewModel.ButtonType)
}

final class PopUpButtonViewModel: PopUpButtonViewModelProtocol {
    enum ButtonType {
        case privacyCenter
        case rejectAll
        case acceptAll
        case acceptSelected
    }
    
    weak var delegate: PopUpButtonViewModelDelegate?
    
    var isEnabled: Bool { stateProvider.isEnabled }
    
    let title: String
    let type: ButtonType
    var onIsEnabledChange: ((Bool) -> Void)?
    
    private let stateProvider: ButtonStateProvider
    
    init(
        title: String,
        type: ButtonType,
        stateProvider: ButtonStateProvider
    ) {
        self.title = title
        self.type = type
        self.stateProvider = stateProvider
        
        stateProvider.onChange = { [weak self] in
            guard let self = self else { return }
            
            self.onIsEnabledChange?(self.stateProvider.isEnabled)
        }
    }
    
    func onTap() {
        delegate?.buttonTapped(type: type)
    }
}
