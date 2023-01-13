//
//  Collection+Extensions.swift
//  Example
//
//  Created by Jan Lipmann on 29/09/2020.
//  Copyright © 2020 ClearCode. All rights reserved.
//

import Foundation

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
