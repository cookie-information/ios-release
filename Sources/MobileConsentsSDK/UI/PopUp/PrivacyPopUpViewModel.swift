import Foundation
import UIKit

public struct PrivacyPopUpData {
    public let sections: [PopUpConsentsSection]
    
    public let title: String
    public let acceptAllButtonTitle: String
    public let saveSelectionButtonTitle: String
    public let privacyDescription: String
    public let privacyPolicyLongtext: String
    public let readMoreButton: String
    public let requiredSectionHeader: String
    public let optionalSectionHeader: String
    public let readMoreScreenHeader: String
}

protocol PrivacyPopUpViewModelProtocol: UINavigationBarDelegate {
    var onLoadingChange: ((Bool) -> Void)? { get set }
    var onDataLoaded: ((PrivacyPopUpData) -> Void)? { get set }
    
    func viewDidLoad()
    func acceptAll()
    func acceptSelected()
}

public final class PrivacyPopUpViewModel: NSObject, PrivacyPopUpViewModelProtocol {
    public var onLoadingChange: ((Bool) -> Void)?
    public var onDataLoaded: ((PrivacyPopUpData) -> Void)?
    public var accentColor: UIColor
    public var fontSet: FontSet
    var router: RouterProtocol?
    
    private let consentSolutionManager: ConsentSolutionManagerProtocol
    init(consentSolutionManager: ConsentSolutionManagerProtocol, accentColor: UIColor, fontSet: FontSet) {
        self.consentSolutionManager = consentSolutionManager
        self.accentColor = accentColor
        self.fontSet = fontSet
    }
    
    public func viewDidLoad() {
        loadConsentSolution()
    }
    
    private func loadConsentSolution() {
        onLoadingChange?(true)
        
        consentSolutionManager.loadConsentSolutionIfNeeded { [weak self] result in
            guard let self = self else { return }
            
            self.onLoadingChange?(false)
            
            guard case .success(let solution) = result else {
                if case let .failure(error) = result {
                    self.router?.closeAll(error: error)
                }
                return
            }
            
            let title = solution.templateTexts.privacyCenterTitle.primaryTranslation().text
            
            
            let optionalSection = PopUpConsentsSection(viewModels: self.consentViewModels(from: solution))
            let requiredSection = PopUpConsentsSection(viewModels: self.consentViewModels(from: solution, required: true))
            
            let overrides = consentSolutionManager.localizationOverride[Locale(identifier: solution.primaryLanguage)]
      
            let data = PrivacyPopUpData(
                sections: [
                    requiredSection,
                    optionalSection
                ],
                title: overrides?.title ?? title,
                acceptAllButtonTitle: 
                    overrides?.acceptAllButtonTitle ?? solution.templateTexts.acceptAllButton.primaryTranslation().text,
                saveSelectionButtonTitle: 
                    overrides?.saveSelectionButtonTitle ?? solution.templateTexts.acceptSelectedButton.primaryTranslation().text,
                privacyDescription: 
                    solution.consentItems.first { $0.type == .privacyPolicy}?.translations.primaryTranslation().shortText ?? "",
                privacyPolicyLongtext: 
                    solution.consentItems.first { $0.type == .privacyPolicy}?.translations.primaryTranslation().longText ?? "",
                readMoreButton: 
                    overrides?.readMoreButton ?? solution.templateTexts.readMoreButton.primaryTranslation().text,
                requiredSectionHeader:
                    overrides?.requiredSectionHeader ?? solution.templateTexts.requiredTableSectionHeader?.primaryTranslation().text ?? "Required",
                optionalSectionHeader:
                    overrides?.optionalSectionHeader ?? solution.templateTexts.optionalTableSectionHeader?.primaryTranslation().text ?? "Optional",
                readMoreScreenHeader:
                    overrides?.readMoreScreenHeader ?? solution.templateTexts.readMoreScreenHeader?.primaryTranslation().text ?? "Privacy Policy"
            )
        
            self.onDataLoaded?(data)
        }
    }
    
    private func consentViewModels(from solution: ConsentSolution, required: Bool = false) -> [PopUpConsentViewModel] {
        solution
            .consentItems
            .filter { ($0.type != .privacyPolicy && $0.type != .privacyPolicy ) && $0.required == required }
            .map { item in
                PopUpConsentViewModel(
                    id: item.id,
                    title: item.translations.primaryTranslation().shortText,
                    description: item.translations.primaryTranslation().longText,
                    isRequired: item.required,
                    consentItemProvider: consentSolutionManager,
                    accentColor: accentColor,
                    fontSet: fontSet
                )
            }
    }
    
    private func handlePostingConsent(buttonType: PopUpButtonViewModel.ButtonType, error: Error?) {
        onLoadingChange?(false)
        router?.closeAll(error: error)
    }
}

extension PrivacyPopUpViewModel: PopUpButtonViewModelDelegate {
    func buttonTapped(type: PopUpButtonViewModel.ButtonType) {
        switch type {
        case .privacyCenter:
            break
        case .rejectAll:
            onLoadingChange?(true)
            consentSolutionManager.rejectAllConsentItems { [weak self] error in
                self?.handlePostingConsent(buttonType: type, error: error)
            }
        case .acceptAll:
            onLoadingChange?(true)
            consentSolutionManager.acceptAllConsentItems { [weak self] error in
                self?.handlePostingConsent(buttonType: type, error: error)
            }
        case .acceptSelected:
            onLoadingChange?(true)
            consentSolutionManager.acceptSelectedConsentItems { [weak self] error in
                self?.handlePostingConsent(buttonType: type, error: error)
            }
        }
    }
    
    @objc
    public func acceptAll() {
        onLoadingChange?(true)
        consentSolutionManager.acceptAllConsentItems { [weak self] error in
            self?.handlePostingConsent(buttonType: .acceptAll, error: error)
        }
    }
    
    @objc
    public func rejectAll() {
        onLoadingChange?(true)
        consentSolutionManager.rejectAllConsentItems { [weak self] error in
            self?.handlePostingConsent(buttonType: .rejectAll, error: error)
        }
    }
    
    @objc
    public func acceptSelected() {
        onLoadingChange?(true)
        consentSolutionManager.acceptSelectedConsentItems { [weak self] error in
            self?.handlePostingConsent(buttonType: .acceptSelected, error: error)
        }
    }
}

extension PrivacyPopUpViewModel: UINavigationBarDelegate {
    
}
