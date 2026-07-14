import UIKit

protocol RouterProtocol {
    func closeAll(error: Error?)
}

final class Router: RouterProtocol {
    weak var rootViewController: UIViewController?

    private let consentSolutionManager: ConsentSolutionManagerProtocol
    private let accentColor: UIColor
    private var completion: (([UserConsent])->())?
    private var errorHandler: ((Error)->())?
    private let fontSet: FontSet
    private var isClosed = false
    
    init(consentSolutionManager: ConsentSolutionManagerProtocol, accentColor: UIColor? = nil, fontSet: FontSet) {
        self.consentSolutionManager = consentSolutionManager
        self.accentColor = accentColor ?? .popUpButtonEnabled
        self.fontSet = fontSet
    }
    
    func showPrivacyPopUp(popupController: PrivacyPopupProtocol.Type? = nil,
                          animated: Bool,
                          completion: (([UserConsent])->())? = nil,
                          error: ((Error)->())? = nil) {
        let viewModel = PrivacyPopUpViewModel(consentSolutionManager: consentSolutionManager,
                                              accentColor: accentColor,
                                              fontSet: fontSet)
        viewModel.router = self
        self.completion = completion
        self.errorHandler = error

        guard let viewController =  (popupController == nil ? PrivacyPopUpViewController(viewModel: viewModel, accentColor: accentColor, fontSet: fontSet) : popupController!.init(viewModel: viewModel) ) as? UIViewController else { return }
       
        viewController.isModalInPresentation = true
        rootViewController?.topViewController.present(viewController, animated: animated)
    }
    
    func closeAll(error: Error? = nil) {
        // A tap can still slip in while the dismiss animation is running; the
        // session is already closing, so the client's completion/errorHandler
        // must not fire a second time. Each presentation gets a fresh Router.
        guard !isClosed else { return }
        isClosed = true

        defer { rootViewController?.dismiss(animated: true) }

        if let error = error {
            self.errorHandler?(error)
            return
        }
        completion?(consentSolutionManager.settings.map {UserConsent(consentItem: $0,
                                                                     isSelected: self.consentSolutionManager.isConsentItemSelected(id: $0.id) || $0.required)})
       
    }
}
