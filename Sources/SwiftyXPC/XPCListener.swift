//
//  XPCListener.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 8/8/21.
//

import XPC

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

    // because xpc_main takes a C function that can't capture any context, we need to store these globally
    private static var globalMessageHandler: XPCConnection.MessageHandler? = nil
    private static var globalErrorHandler: XPCConnection.ErrorHandler? = nil

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

    public init(type: ListenerType) {
        self.type = type

        switch type {
        case .anonymous:
            self.backing = .connection(XPCConnection.makeAnonymousListenerConnection())
        case .service:
            self.backing = .xpcMain
        case .machService(name: let name):
            let connection = XPCConnection(machServiceName: name, flags: XPC_CONNECTION_MACH_SERVICE_LISTENER)
            self.backing = .connection(connection)
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
                let connection = XPCConnection(connection: $0)

                connection.messageHandler = XPCListener.globalMessageHandler
                connection.errorHandler = XPCListener.globalErrorHandler

                connection.activate()
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
