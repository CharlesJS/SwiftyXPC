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
        case connection(XPCConnection)
    }

    public let type: ListenerType
    private let backing: Backing

    public var endpoint: XPCEndpoint {
        switch self.backing {
        case .xpcMain:
            fatalError("Can't get endpoint for main service listener")
        case .connection(let connection):
            return connection.makeEndpoint()
        }
    }

    // because xpc_main takes a C function that can't capture any context, we need to store these globally
    private static var globalMessageHandler: XPCConnection.MessageHandler? = nil
    private static var globalErrorHandler: XPCConnection.ErrorHandler? = nil
    private static var globalCodeSigningRequirement: String? = nil

    public var messageHandler: XPCConnection.MessageHandler? {
        get {
            switch self.backing {
            case .xpcMain:
                return Self.globalMessageHandler
            case .connection(let connection):
                return connection.messageHandler
            }
        }
        set {
            switch self.backing {
            case .xpcMain:
                Self.globalMessageHandler = newValue
            case .connection(let connection):
                connection.messageHandler = newValue
            }
        }
    }

    public var errorHandler: XPCConnection.ErrorHandler? {
        get {
            switch self.backing {
            case .xpcMain:
                return Self.globalErrorHandler
            case .connection(let connection):
                return connection.errorHandler
            }
        }
        set {
            switch self.backing {
            case .xpcMain:
                Self.globalErrorHandler = newValue
            case .connection(let connection):
                connection.errorHandler = newValue
            }
        }
    }

    public init(type: ListenerType, codeSigningRequirement requirement: String?) throws {
        self.type = type

        switch type {
        case .anonymous:
            self.backing = .connection(
                try XPCConnection.makeAnonymousListenerConnection(codeSigningRequirement: requirement)
            )
        case .service:
            self.backing = .xpcMain
            Self.globalCodeSigningRequirement = requirement
        case .machService(name: let name):
            self.backing = .connection(
                try XPCConnection(
                    machServiceName: name,
                    flags: XPC_CONNECTION_MACH_SERVICE_LISTENER,
                    codeSigningRequirement: requirement
                )
            )
        }
    }

    public func cancel() {
        switch self.backing {
        case .xpcMain:
            fatalError("XPC service listener cannot be cancelled")
        case .connection(let connection):
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
        case .connection(let connection):
            connection.activate()
        }
    }

    public func suspend() {
        switch self.backing {
        case .xpcMain:
            fatalError("XPC service listener cannot be suspended")
        case .connection(let connection):
            connection.suspend()
        }
    }

    public func resume() {
        switch self.backing {
        case .xpcMain:
            fatalError("XPC service listener cannot be resumed")
        case .connection(let connection):
            connection.resume()
        }
    }
}
