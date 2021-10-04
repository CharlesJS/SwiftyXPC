import System
import XPC
import os

public class XPCConnection {
    static let responseKey = "com.charlessoft.SwiftyXPC.XPCEventHandler.ResponseKey"
    static let errorKey = "com.charlessoft.SwiftyXPC.XPCEventHandler.ErrorKey"

    public enum ConnectionType {
        case anonymousListener
        case remoteService(bundleID: String)
        case remoteServiceFromEndpoint(XPCEndpoint)
        case remoteMachService(serviceName: String, isPrivilegedHelperTool: Bool)
    }

    public typealias MessageHandler = (XPCConnection, [String : Any]) async throws -> [String : Any]?
    public typealias ErrorHandler = (XPCConnection, Error) -> ()

    private let connection: xpc_connection_t

    internal static func makeAnonymousListenerConnection(codeSigningRequirement: String?) throws -> XPCConnection {
        try .init(connection: xpc_connection_create(nil, nil), codeSigningRequirement: codeSigningRequirement)
    }

    public convenience init(type: ConnectionType, codeSigningRequirement requirement: String? = nil) throws {
        switch type {
        case .anonymousListener:
            try self.init(connection: xpc_connection_create(nil, nil), codeSigningRequirement: requirement)
        case .remoteService(let bundleID):
            try self.init(connection: xpc_connection_create(bundleID, nil), codeSigningRequirement: requirement)
        case .remoteServiceFromEndpoint(let endpoint):
            try self.init(connection: endpoint.makeConnection(), codeSigningRequirement: requirement)
        case .remoteMachService(serviceName: let name, isPrivilegedHelperTool: let isPrivileged):
            let flags: Int32 = isPrivileged ? XPC_CONNECTION_MACH_SERVICE_PRIVILEGED : 0
            try self.init(machServiceName: name, flags: flags, codeSigningRequirement: requirement)
        }
    }

    internal convenience init(machServiceName: String, flags: Int32, codeSigningRequirement: String? = nil) throws {
        let connection = xpc_connection_create_mach_service(machServiceName, nil, UInt64(flags))

        try self.init(connection: connection, codeSigningRequirement: codeSigningRequirement)
    }

    internal init(connection: xpc_connection_t, codeSigningRequirement: String?) throws {
        self.connection = connection

        if let requirement = codeSigningRequirement {
            guard xpc_connection_set_peer_code_signing_requirement(self.connection, requirement) == 0 else {
                throw XPCError.invalidCodeSignatureRequirement
            }
        }

        xpc_connection_set_event_handler(self.connection, self.handleEvent)
    }

    public var messageHandler: MessageHandler? = nil
    public var errorHandler: ErrorHandler? = nil
    internal var customEventHandler: xpc_handler_t? = nil

    public var auditSessionIdentifier: au_asid_t {
        xpc_connection_get_asid(self.connection)
    }

    public var effectiveGroupIdentifier: gid_t {
        xpc_connection_get_egid(self.connection)
    }

    public var effectiveUserIdentifier: uid_t {
        xpc_connection_get_euid(self.connection)
    }

    public var processIdentifier: pid_t {
        xpc_connection_get_pid(self.connection)
    }

    public func activate() {
        xpc_connection_activate(self.connection)
    }

    public func suspend() {
        xpc_connection_suspend(self.connection)
    }

    public func resume() {
        xpc_connection_resume(self.connection)
    }

    public func cancel() {
        xpc_connection_cancel(self.connection)
    }

    internal func makeEndpoint() -> XPCEndpoint {
        XPCEndpoint(connection: self.connection)
    }

    public func sendMessage(_ request: [String : Any]) async throws -> [String : Any] {
        guard let xpcRequest = request.toXPCObject() else { throw Errno.invalidArgument }

        return try await withCheckedThrowingContinuation { continuation in
            let l = Logger(subsystem: String(CommandLine.arguments[0].split(separator: "/").last!), category: "XPCListener")
            l.warning("Sending message with reply: \(request)")

            xpc_connection_send_message_with_reply(self.connection, xpcRequest, nil) { event in
                do {
                    l.warning("Got reply")
                    guard xpc_get_type(event) == XPC_TYPE_DICTIONARY,
                          let reply = [String : Any].fromXPCObject(event) else {
                              l.warning("reply of wrong type")
                              throw XPCError(error: event)
                    }
                    l.warning("reply is \(reply)")

                    guard let response = reply[Self.responseKey] as? [String : Any] else {
                        l.warning("error: no response")
                        throw reply[Self.errorKey] as? Error ?? Errno.invalidArgument
                    }
                    l.warning("response was \(response)")

                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func sendOnewayMessage(_ message: [String : Any]) throws {
        try self.sendOnewayMessage(message, asReplyTo: nil)
    }

    private func sendOnewayMessage(_ message: [String : Any], asReplyTo original: xpc_object_t?) throws {
        guard let xpcMessage = message.toXPCObject(replyTo: original) else { throw Errno.invalidArgument }
        let l = Logger(subsystem: String(CommandLine.arguments[0].split(separator: "/").last!), category: "XPCListener")
        l.warning("sending oneway message: \(message)")
        xpc_connection_send_message(self.connection, xpcMessage)
    }

    public func sendBarrier(_ barrier: @escaping () -> ()) {
        xpc_connection_send_barrier(self.connection, barrier)
    }

    private func handleEvent(_ event: xpc_object_t) {
        if let customEventHandler = self.customEventHandler {
            customEventHandler(event)
            return
        }

        let type = xpc_get_type(event)

        guard type == XPC_TYPE_DICTIONARY, let message = [String : Any].fromXPCObject(event) else {
            self.errorHandler?(self, type == XPC_TYPE_ERROR ? XPCError(error: event) : Errno.badFileTypeOrFormat)
            return
        }

        Task {
            do {
                if let response = try await self.messageHandler?(self, message) {
                    do {
                        try self.sendOnewayMessage([Self.responseKey : response], asReplyTo: event)
                    } catch {
                        self.errorHandler?(self, error)
                    }
                }
            } catch {
                try self.sendOnewayMessage([Self.errorKey : error], asReplyTo: event)
            }
        }
    }
}
