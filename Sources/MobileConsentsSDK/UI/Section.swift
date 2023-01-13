import UIKit

protocol Section {
    static func registerCells(in tableView: UITableView)
    
    var numberOfCells: Int { get }
    
    func cell(for indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell
    func didSelectCell(at indexPath: IndexPath, in tableView: UITableView)
}

extension Section {
    var numberOfCells: Int { 1 }
    
    func didSelectCell(at indexPath: IndexPath, in tableView: UITableView) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
}
