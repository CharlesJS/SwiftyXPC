//
//  XPCListener.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 8/8/21.
//

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
    private static var globalMessageHandler: XPCConnection.MessageHandler? = nil
    private static var globalErrorHandler: XPCConnection.ErrorHandler? = nil
    private static var globalCodeSigningRequirement: String? = nil

    private var _messageHandler: XPCConnection.MessageHandler? = nil
    public var messageHandler: XPCConnection.MessageHandler? {
        get {
            switch self.backing {
            case .xpcMain:
                return Self.globalMessageHandler
            case .connection(let connection, let isMulti):
                return isMulti ? self._messageHandler : connection.messageHandler
            }
        }
        set {
            switch self.backing {
            case .xpcMain:
                Self.globalMessageHandler = newValue
            case .connection(let connection, let isMulti):
                if isMulti {
                    self._messageHandler = newValue
                } else {
                    connection.messageHandler = newValue
                }
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
        case .machService(name: let name):
            let connection = try XPCConnection(
                machServiceName: name,
                flags: XPC_CONNECTION_MACH_SERVICE_LISTENER,
                codeSigningRequirement: requirement
            )

            self.backing = .connection(connection: connection, isMulti: true)

            connection.customEventHandler = { [weak self] in
                do {
                    let newConnection = try XPCConnection(connection: $0, codeSigningRequirement: requirement)

                    newConnection.messageHandler = self?.messageHandler
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

                    connection.messageHandler = XPCListener.globalMessageHandler
                    connection.errorHandler = XPCListener.globalErrorHandler

                    connection.activate()
                } catch {
                    os.Logger().critical("Can’t initialize incoming XPC connection!")
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
