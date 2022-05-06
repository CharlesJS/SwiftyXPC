//
//  ServiceDelegate.swift
//  Example XPC Service
//
//  Created by Charles Srstka on 5/5/22.
//

import SwiftyXPC

@main
class XPCService {
    static func main() {
        do {
            let xpcService = XPCService()

            // In an actual product, you should always set a real code signing requirement here, for security
            let requirement: String? = nil

            let serviceListener = try XPCListener(type: .service, codeSigningRequirement: requirement)

            serviceListener.setMessageHandler(name: CommandSet.capitalizeString, handler: xpcService.capitalizeString)

            serviceListener.activate()
            fatalError("Should never get here")
        } catch {
            fatalError("Error while setting up XPC service: \(error)")
        }
    }

    private func capitalizeString(_: XPCConnection, string: String) async throws -> String {
        return string.uppercased()
    }
}
