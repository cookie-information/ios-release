import UIKit
import MobileConsentsSDK

protocol ConsentItemDetailsTableViewCellDelegate: AnyObject {
    func consentItemDetailsTableViewCellDidSelectCheckBox(_ cell: ConsentItemDetailsTableViewCell)
}

final class ConsentItemDetailsTableViewCell: UITableViewCell {
    @IBOutlet private weak var checkboxButton: UIButton!
    @IBOutlet private weak var consentItemIdLabel: UILabel!
    @IBOutlet private weak var shortTextLabel: UILabel!
    @IBOutlet private weak var longTextLabel: UILabel!
    
    weak var delegate: ConsentItemDetailsTableViewCellDelegate?

    func setup(withConsentItem item: ConsentItem, language: String) {
        consentItemIdLabel.text = item.id
        let translation = item.translations.translations.first(where: { $0.language == language })
        shortTextLabel.text = translation?.shortText
        longTextLabel.text = translation?.longText
    }

    func setCheckboxSelected(_ selected: Bool) {
        checkboxButton.isSelected = selected
    }
    
    @IBAction private func checkBoxAction() {
        delegate?.consentItemDetailsTableViewCellDidSelectCheckBox(self)
    }
}
