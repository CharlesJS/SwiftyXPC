//
//  MessageSender.swift
//  Example App
//
//  Created by Charles Srstka on 5/5/22.
//

import Foundation
import SwiftyXPC
import os

actor MessageSender {
    static let shared = try! MessageSender()

    private let connection: XPCConnection
    @Published var messageSendInProgress = false

    private init() throws {
        let connection = try XPCConnection(type: .remoteService(bundleID: "com.charlessoft.SwiftyXPC.Example-App.xpc"))

        let logger = Logger()

        connection.errorHandler = { _, error in
            logger.error("The connection to the XPC service received an error: \(error.localizedDescription)")
        }

        connection.resume()
        self.connection = connection
    }

    func capitalize(string: String) async throws -> String {
        self.messageSendInProgress = true
        defer { self.messageSendInProgress = false }

        return try await self.connection.sendMessage(name: CommandSet.capitalizeString, request: string)
    }

    func startLongRunningTask(callback: @escaping (Double?) -> Void) async throws {
        self.messageSendInProgress = true
        defer { self.messageSendInProgress = false }

        let listener = try XPCListener(type: .anonymous, codeSigningRequirement: nil) // don't actually use nil

        listener.setMessageHandler(name: LongRunningTaskMessage.progressNotification) { (_, progress: Double) in
            callback(progress)
        }

        listener.activate()
        listener.errorHandler = {
            callback(nil)
            print("something went wrong: \($1)")
        }

        try await self.connection.sendMessage(name: CommandSet.longRunningTask, request: listener.endpoint)
    }
}
