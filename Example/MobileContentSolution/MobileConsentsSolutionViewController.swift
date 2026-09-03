import UIKit
import MobileConsentsSDK

final class MobileConsentsSolutionViewController: BaseViewController {
   
    @IBOutlet weak var showPrivacyCenterButton: UIBarButtonItem!
    
    private var viewModel = MobileConsentSolutionViewModel()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.showPrivacyPopUpIfNeeded()
    }
    @IBAction private func showPopUpAction() {        showSelection()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController, let savedDataViewController = navigationController.viewControllers.first as? SavedDataViewController else { return }
        
        savedDataViewController.savedItems = viewModel.savedConsents
        savedDataViewController.clearConsents = viewModel.mobileConsentsSDK.removeStoredConsents
    }
    
    private func showSelection() {
        let alert = UIAlertController(title: "Privacy popup style", message: "Please select a style", preferredStyle: .actionSheet)
        
        let popoverPresenter = alert.popoverPresentationController
        popoverPresenter?.barButtonItem = showPrivacyCenterButton
        
        alert.addAction(UIAlertAction(title: "Default", style: .default, handler: { (_) in
            self.viewModel.showPrivacyPopUp(style: .standard)
        }))
        
        alert.addAction(UIAlertAction(title: "Green terminal", style: .default, handler: { (_) in
            self.viewModel.showPrivacyPopUp(style: .greenTerminal)
        }))
        
        alert.addAction(UIAlertAction(title: "Pink", style: .default, handler: { (_) in
            self.viewModel.showPrivacyPopUp(style: .pink)
        }))
        
        alert.addAction(UIAlertAction(title: "Custom view controller", style: .default, handler: { (_) in
            self.viewModel.showPrivacyPopUp(style: .customController)
        }))
        
        self.present(alert, animated: true)
    }
}
