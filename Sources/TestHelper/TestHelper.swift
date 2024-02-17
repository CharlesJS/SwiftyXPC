//
//  TestHelper.swift
//
//
//  Created by Charles Srstka on 10/12/23.
//

import Foundation
import Dispatch
import SwiftyXPC
import TestShared

@main
@available(macOS 13.0, *)
class XPCService {
    static func main() {
        do {
            let xpcService = XPCService()

            let listener = try XPCListener(type: .machService(name: helperID), codeSigningRequirement: nil)

            listener.setMessageHandler(name: CommandSet.reportIDs, handler: xpcService.reportIDs)
            listener.setMessageHandler(name: CommandSet.capitalizeString, handler: xpcService.capitalizeString)
            listener.setMessageHandler(name: CommandSet.multiplyBy5, handler: xpcService.multiplyBy5)
            listener.setMessageHandler(name: CommandSet.transportData, handler: xpcService.transportData)
            listener.setMessageHandler(name: CommandSet.tellAJoke, handler: xpcService.tellAJoke)
            listener.setMessageHandler(name: CommandSet.pauseOneSecond, handler: xpcService.pauseOneSecond)

            listener.activate()
            dispatchMain()
        } catch {
            fatalError("Error while setting up XPC service: \(error)")
        }
    }

    private func reportIDs(connection: XPCConnection) async throws -> ProcessIDs {
        try ProcessIDs(connection: connection)
    }

    private func capitalizeString(_: XPCConnection, string: String) async throws -> String {
        string.uppercased()
    }

    private func multiplyBy5(_: XPCConnection, number: Double) async throws -> Double {
        number * 5.0
    }

    private func transportData(_: XPCConnection, data: Data) async throws -> DataInfo {
        guard String(data: data, encoding: .utf8) == "One to beam up" else {
            throw DataInfo.DataError(failureReason: "fluctuation in the positronic matrix")
        }

        return DataInfo(
            characterName: "Lt. Cmdr. Data".data(using: .utf8)!,
            playedBy: "Brent Spiner".data(using: .utf8)!,
            otherCharacters: [
                "Lore".data(using: .utf8)!,
                "B4".data(using: .utf8)!,
                "Noonien Soong".data(using: .utf8)!,
                "Arik Soong".data(using: .utf8)!,
                "Altan Soong".data(using: .utf8)!,
                "Adam Soong".data(using: .utf8)!
            ]
        )
    }

    private func tellAJoke(_: XPCConnection, endpoint: XPCEndpoint) async throws {
        let remoteConnection = try XPCConnection(
            type: .remoteServiceFromEndpoint(endpoint),
            codeSigningRequirement: nil
        )

        remoteConnection.activate()

        let opening: String = try await remoteConnection.sendMessage(name: JokeMessage.askForJoke, request: "Tell me a joke")

        guard opening == "Knock knock" else {
            throw JokeMessage.NotAKnockKnockJoke(complaint: "That was not a knock knock joke!")
        }

        let whosThere: String = try await remoteConnection.sendMessage(name: JokeMessage.whosThere, request: "Who's there?")

        try await remoteConnection.sendMessage(name: JokeMessage.who, request: "\(whosThere) who?")

        try remoteConnection.sendOnewayMessage(name: JokeMessage.groan, message: "That was awful!")
    }

    private func pauseOneSecond(_: XPCConnection) async throws {
        try await Task.sleep(for: .seconds(1))
    }
}
