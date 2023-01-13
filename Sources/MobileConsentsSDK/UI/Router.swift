import UIKit

protocol RouterProtocol {
    func closeAll()
}

final class Router: RouterProtocol {
    weak var rootViewController: UIViewController?
    
    private let consentSolutionManager: ConsentSolutionManagerProtocol
    private let accentColor: UIColor
    private var completion: (([UserConsent])->())?
    private let fontSet: FontSet
    
    init(consentSolutionManager: ConsentSolutionManagerProtocol, accentColor: UIColor? = nil, fontSet: FontSet) {
        self.consentSolutionManager = consentSolutionManager
        self.accentColor = accentColor ?? .popUpButtonEnabled
        self.fontSet = fontSet
    }
    
    func showPrivacyPopUp(animated: Bool, completion: (([UserConsent])->())? = nil) {
        let viewModel = PrivacyPopUpViewModel(consentSolutionManager: consentSolutionManager, accentColor: accentColor, fontSet: fontSet)
        viewModel.router = self
        self.completion = completion
        let viewController = PrivacyPopUpViewController(viewModel: viewModel, accentColor: accentColor, fontSet: fontSet)
        if #available(iOS 13.0, *) {
            viewController.isModalInPresentation = true
        }
        rootViewController?.topViewController.present(viewController, animated: animated)
    }
    
    func closeAll() {
        completion?(consentSolutionManager.settings.map {UserConsent(consentItem: $0,
                                                                     isSelected: self.consentSolutionManager.isConsentItemSelected(id: $0.id) || $0.required)})
        rootViewController?.dismiss(animated: true)
    }
}
