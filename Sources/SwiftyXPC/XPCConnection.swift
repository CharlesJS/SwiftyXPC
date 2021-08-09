import System
import XPC

public class XPCConnection {
    static let responseKey = "com.charlessoft.SwiftyXPC.XPCEventHandler.ResponseKey"
    static let errorKey = "com.charlessoft.SwiftyXPC.XPCEventHandler.ErrorKey"

    public enum ConnectionType {
        case anonymousListener
        case remoteService(bundleID: String)
        case remoteMachService(serviceName: String, isPrivilegedHelperTool: Bool)
    }

    public typealias MessageHandler = ([String : Any]) async throws -> [String : Any]
    public typealias ErrorHandler = (Error) -> ()

    private let connection: xpc_connection_t

    internal static func makeAnonymousListenerConnection() -> XPCConnection {
        .init(connection: xpc_connection_create(nil, nil))
    }

    public convenience init(type: ConnectionType) {
        switch type {
        case .anonymousListener:
            self.init(connection: xpc_connection_create(nil, nil))
        case .remoteService(let bundleID):
            self.init(connection: xpc_connection_create(bundleID, nil))
        case .remoteMachService(serviceName: let name, isPrivilegedHelperTool: let isPrivileged):
            let flags: Int32 = isPrivileged ? XPC_CONNECTION_MACH_SERVICE_PRIVILEGED : 0
            self.init(machServiceName: name, flags: flags)
        }
    }

    internal convenience init(machServiceName: String, flags: Int32) {
        let connection = xpc_connection_create_mach_service(machServiceName, nil, UInt64(flags))

        self.init(connection: connection)
    }

    internal init(connection: xpc_connection_t) {
        self.connection = connection

        xpc_connection_set_event_handler(self.connection, self.handleEvent)
    }

    public var messageHandler: MessageHandler? = nil
    public var errorHandler: ErrorHandler? = nil

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

    public func setCodeSigningRequirement(_ requirement: String) throws {
        guard xpc_connection_set_peer_code_signing_requirement(self.connection, requirement) == 0 else {
            throw XPCError.invalidCodeSignatureRequirement
        }
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

    public func sendMessage(_ request: [String : Any]) async throws -> [String : Any] {
        guard let xpcRequest = request.toXPCObject() else { throw Errno.invalidArgument }

        return try await withCheckedThrowingContinuation { continuation in
            xpc_connection_send_message_with_reply(self.connection, xpcRequest, nil) { event in
                if xpc_get_type(event) == XPC_TYPE_DICTIONARY, let reply = [String : Any].fromXPCObject(event) {
                    continuation.resume(returning: reply)
                } else {
                    continuation.resume(throwing: XPCError(error: event))
                }
            }
        }
    }

    public func sendOnewayMessage(_ message: [String : Any]) throws {
        try self.sendOnewayMessage(message, asReplyTo: nil)
    }

    private func sendOnewayMessage(_ message: [String : Any], asReplyTo original: xpc_object_t?) throws {
        guard let xpcMessage = message.toXPCObject(replyTo: original) else { throw Errno.invalidArgument }
        xpc_connection_send_message(self.connection, xpcMessage)
    }

    public func sendBarrier(_ barrier: @escaping () -> ()) {
        xpc_connection_send_barrier(self.connection, barrier)
    }

    private func handleEvent(_ event: xpc_object_t) {
        let type = xpc_get_type(event)

        guard type == XPC_TYPE_DICTIONARY, let message = [String : Any].fromXPCObject(event) else {
            self.errorHandler?(type == XPC_TYPE_ERROR ? XPCError(error: event) : Errno.badFileTypeOrFormat)
            return
        }

        Task {
            do {
                if let response = try await self.messageHandler?(message) {
                    do {
                        try self.sendOnewayMessage([Self.responseKey : response], asReplyTo: event)
                    } catch {
                        self.errorHandler?(error)
                    }
                }
            } catch {
                try self.sendOnewayMessage([Self.errorKey : error], asReplyTo: event)
            }
        }
    }
}
