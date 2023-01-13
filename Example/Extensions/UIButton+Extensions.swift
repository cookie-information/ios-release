//
//  UIButton+Extensions.swift
//  Example
//
//  Created by Jan Lipmann on 07/10/2020.
//  Copyright © 2020 ClearCode. All rights reserved.
//

import UIKit

extension UIButton {
    func setCornerRadius(_ radius: CGFloat) {
        layer.cornerRadius = radius
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        backgroundColor = enabled ? .black : .gray
    }
}
