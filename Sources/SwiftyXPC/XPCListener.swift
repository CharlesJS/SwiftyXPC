//
//  XPCListener.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 8/8/21.
//

import Foundation
import System
import XPC
import os

public final class XPCListener {
    public enum ListenerType {
        case anonymous
        case service
        case machService(name: String)
    }

    private enum Backing {
        case xpcMain
        case connection(connection: XPCConnection, isMulti: Bool)
    }

    public let type: ListenerType
    private let backing: Backing

    public var endpoint: XPCEndpoint {
        switch self.backing {
        case .xpcMain:
            fatalError("Can't get endpoint for main service listener")
        case .connection(let connection, _):
            return connection.makeEndpoint()
        }
    }

    // because xpc_main takes a C function that can't capture any context, we need to store these globally
    private static var globalMessageHandlers: [String: XPCConnection.MessageHandler] = [:]
    private static var globalErrorHandler: XPCConnection.ErrorHandler? = nil
    private static var globalCodeSigningRequirement: String? = nil

    private var _messageHandlers: [String: XPCConnection.MessageHandler] = [:]
    private var messageHandlers: [String: XPCConnection.MessageHandler] {
        switch self.backing {
        case .xpcMain:
            return Self.globalMessageHandlers
        case .connection(let connection, let isMulti):
            return isMulti ? self._messageHandlers : connection.messageHandlers
        }
    }

    private func getMessageHandler(forName name: String) -> XPCConnection.MessageHandler.RawHandler? {
        switch self.backing {
        case .xpcMain:
            return Self.globalMessageHandlers[name]?.closure
        case .connection(let connection, let isMulti):
            return isMulti ? self._messageHandlers[name]?.closure : connection.getMessageHandler(forName: name)
        }
    }

    public func setMessageHandler(name: String, handler: @escaping (XPCConnection) async throws -> Void) {
        self.setMessageHandler(name: name) { (connection: XPCConnection, _: XPCNull) async throws -> XPCNull in
            try await handler(connection)
            return XPCNull.shared
        }
    }

    public func setMessageHandler<Request: Codable>(
        name: String,
        handler: @escaping (XPCConnection, Request) async throws -> Void
    ) {
        self.setMessageHandler(name: name) { (connection: XPCConnection, request: Request) async throws -> XPCNull in
            try await handler(connection, request)
            return XPCNull.shared
        }
    }

    public func setMessageHandler<Response: Codable>(
        name: String,
        handler: @escaping (XPCConnection) async throws -> Response
    ) {
        self.setMessageHandler(name: name) { (connection: XPCConnection, _: XPCNull) async throws -> Response in
            try await handler(connection)
        }
    }

    public func setMessageHandler<Request: Codable, Response: Codable>(
        name: String,
        handler: @escaping (XPCConnection, Request) async throws -> Response
    ) {
        switch self.backing {
        case .xpcMain:
            Self.globalMessageHandlers[name] = XPCConnection.MessageHandler(closure: handler)
        case .connection(let connection, let isMulti):
            if isMulti {
                self._messageHandlers[name] = XPCConnection.MessageHandler(closure: handler)
            } else {
                connection.setMessageHandler(name: name, handler: handler)
            }
        }
    }

    private var _errorHandler: XPCConnection.ErrorHandler? = nil
    public var errorHandler: XPCConnection.ErrorHandler? {
        get {
            switch self.backing {
            case .xpcMain:
                return Self.globalErrorHandler
            case .connection(let connection, let isMulti):
                return isMulti ? self._errorHandler : connection.errorHandler
            }
        }
        set {
            switch self.backing {
            case .xpcMain:
                Self.globalErrorHandler = newValue
            case .connection(let connection, let isMulti):
                if isMulti {
                    self._errorHandler = newValue
                } else {
                    connection.errorHandler = newValue
                }
            }
        }
    }

    public init(type: ListenerType, codeSigningRequirement requirement: String?) throws {
        self.type = type

        switch type {
        case .anonymous:
            self.backing = .connection(
                connection: try XPCConnection.makeAnonymousListenerConnection(codeSigningRequirement: requirement),
                isMulti: false
            )
        case .service:
            self.backing = .xpcMain
            Self.globalCodeSigningRequirement = requirement
        case .machService(let name):
            let connection = try XPCConnection(
                machServiceName: name,
                flags: XPC_CONNECTION_MACH_SERVICE_LISTENER,
                codeSigningRequirement: requirement
            )

            self.backing = .connection(connection: connection, isMulti: true)

            connection.customEventHandler = { [weak self] in
                do {
                    guard case .connection = $0.type else {
                        preconditionFailure("XPCListener is required to have connection backing when run as a Mach service")
                    }

                    let newConnection = try XPCConnection(connection: $0, codeSigningRequirement: requirement)

                    newConnection.messageHandlers = self?.messageHandlers ?? [:]
                    newConnection.errorHandler = self?.errorHandler

                    newConnection.activate()
                } catch {
                    self?.errorHandler?(connection, error)
                }
            }
        }
    }

    public func cancel() {
        switch self.backing {
        case .xpcMain:
            fatalError("XPC service listener cannot be cancelled")
        case .connection(let connection, _):
            connection.cancel()
        }
    }

    public func activate() {
        switch self.backing {
        case .xpcMain:
            xpc_main {
                do {
                    let connection = try XPCConnection(
                        connection: $0,
                        codeSigningRequirement: XPCListener.globalCodeSigningRequirement
                    )

                    connection.messageHandlers = XPCListener.globalMessageHandlers
                    connection.errorHandler = XPCListener.globalErrorHandler

                    connection.activate()
                } catch {
                    os_log(.fault, "Can’t initialize incoming XPC connection!")
                }
            }
        case .connection(let connection, _):
            connection.activate()
        }
    }

    public func suspend() {
        switch self.backing {
        case .xpcMain:
            fatalError("XPC service listener cannot be suspended")
        case .connection(let connection, _):
            connection.suspend()
        }
    }

    public func resume() {
        switch self.backing {
        case .xpcMain:
            fatalError("XPC service listener cannot be resumed")
        case .connection(let connection, _):
            connection.resume()
        }
    }
}
