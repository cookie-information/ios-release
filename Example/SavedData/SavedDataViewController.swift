import UIKit
import MobileConsentsSDK

class SavedDataViewController: BaseViewController {
    @IBOutlet private weak var tableView: UITableView!
    
    var savedItems: [UserConsent] = []
    var clearConsents: () -> () = { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Saved Data"
        setupTableView()
    }
    
    func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
    }

    @IBAction private func closeAction() {
        dismiss(animated: true)
    }
    
    @IBAction private func clearAllAction() {
        clearConsents()
        dismiss(animated: true)
    }
}

extension SavedDataViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SavedItemTableViewCell.identifier(), for: indexPath) as! SavedItemTableViewCell
        if let item = savedItems[safe: indexPath.row] {
            cell.setup(with: item)
        }
        return cell
    }
}
