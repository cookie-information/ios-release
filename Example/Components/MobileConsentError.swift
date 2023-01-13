//
//  MobileConsentError.swift
//  Example
//
//  Created by Jan Lipmann on 07/10/2020.
//  Copyright © 2020 ClearCode. All rights reserved.
//

import Foundation

enum MobileConsentError: LocalizedError {
    case noConsentToSend
    
    var errorDescription: String? {
        switch self {
        case .noConsentToSend: return "No consent to send"
        }
    }
}
