import UIKit
import MobileConsentsSDK

enum MobileConsentsSolutionSectionType {
    case info
    case items
}

enum MobileConsentsSolutionCellType {
    case solutionDetails
    case consentItem
}

final class MobileConsentsSolutionViewController: BaseViewController {
   
    @IBOutlet weak var showPrivacyCenterButton: UIBarButtonItem!
    
    private enum Constants {
        static let defaultLanguage = "EN"
        static let buttonCornerRadius: CGFloat = 5.0
    }
    
    private var viewModel = MobileConsentSolutionViewModel()
    
    private var language: String {
        Constants.defaultLanguage
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.showPrivacyPopUpIfNeeded()
    }
    
    
    @IBAction private func getAction() {
        view.endEditing(true)
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

extension MobileConsentsSolutionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
