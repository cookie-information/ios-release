//
//  UITableViewCell+Extensions.swift
//  Example
//
//  Created by Jan Lipmann on 04/10/2020.
//  Copyright © 2020 ClearCode. All rights reserved.
//

import UIKit

extension UITableViewCell {
    class func identifier() -> String {
        return String(describing: self) + "Identifier"
    }
}
