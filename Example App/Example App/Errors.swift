//
//  Errors.swift
//  Example App
//
//  Created by Charles Srstka on 5/5/22.
//

import Foundation
import SwiftUI
import SwiftyXPC

// just to make error reporting a little nicer
extension XPCError: LocalizedError {
    /// Implementation of `LocalizedError`.
    public var errorDescription: String? {
        switch self {
        case .connectionInvalid:
            return NSLocalizedString("Invalid XPC Connection", comment: "Invalid XPC Connection")
        case .connectionInterrupted:
            return NSLocalizedString("XPC Connection Interrupted", comment: "XPC Connection Interrupted")
        case .invalidCodeSignatureRequirement:
            return NSLocalizedString("Bad Code Signature Requirement", comment: "Bad Code Signature Requirement")
        case .terminationImminent:
            return NSLocalizedString("XPC Service Termination Imminent", comment: "XPC Service Termination Imminent")
        case .unknown(let code):
            return "Error \(code)"
        }
    }
}
