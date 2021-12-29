import Foundation
import Security
import System
import XPC

public class XPCConnection {
    public enum Error: Swift.Error, Codable {
        case missingMessageName
        case missingMessageBody
        case unexpectedMessage
        case typeMismatch(expected: XPCType, actual: XPCType)
        case callerFailedCredentialCheck(OSStatus)  // only used on macOS <= 11.x
    }

    private struct MessageKeys {
        static let name = "com.charlessoft.SwiftyXPC.XPCEventHandler.Name"
        static let body = "com.charlessoft.SwiftyXPC.XPCEventHandler.Body"
        static let error = "com.charlessoft.SwiftyXPC.XPCEventHandler.Error"
    }

    public enum ConnectionType {
        case anonymousListener
        case remoteService(bundleID: String)
        case remoteServiceFromEndpoint(XPCEndpoint)
        case remoteMachService(serviceName: String, isPrivilegedHelperTool: Bool)
    }

    public typealias ErrorHandler = (XPCConnection, Swift.Error) -> Void

    internal class MessageHandler {
        typealias RawHandler = ((XPCConnection, xpc_object_t) async throws -> xpc_object_t)
        let closure: RawHandler
        let requestType: Codable.Type
        let responseType: Codable.Type

        init<Request: Codable, Response: Codable>(closure: @escaping (XPCConnection, Request) async throws -> Response) {
            self.requestType = Request.self
            self.responseType = Response.self

            self.closure = { connection, event in
                guard let body = xpc_dictionary_get_value(event, MessageKeys.body) else {
                    throw Error.missingMessageBody
                }

                let request = try XPCDecoder().decode(type: Request.self, from: body)
                let response = try await closure(connection, request)

                return try XPCEncoder().encode(response)
            }
        }
    }

    private let connection: xpc_connection_t

    @available(macOS, obsoleted: 12.0)
    private let codeSigningRequirement: String?

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
        self.codeSigningRequirement = codeSigningRequirement

        if #available(macOS 12.0, *), let requirement = codeSigningRequirement {
            guard xpc_connection_set_peer_code_signing_requirement(self.connection, requirement) == 0 else {
                throw XPCError.invalidCodeSignatureRequirement
            }
        }

        xpc_connection_set_event_handler(self.connection, self.handleEvent)
    }

    internal var messageHandlers: [String: MessageHandler] = [:]
    public var errorHandler: ErrorHandler? = nil
    internal var customEventHandler: xpc_handler_t? = nil

    internal func getMessageHandler(forName name: String) -> MessageHandler.RawHandler? {
        self.messageHandlers[name]?.closure
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
        self.setMessageHandler(name: name) { (connection: XPCConnection, _: XPCNull) in
            try await handler(connection)
        }
    }

    public func setMessageHandler<Request: Codable, Response: Codable>(
        name: String,
        handler: @escaping (XPCConnection, Request) async throws -> Response
    ) {
        self.messageHandlers[name] = MessageHandler(closure: handler)
    }

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

    public func sendMessage(name: String) async throws {
        try await self.sendMessage(name: name, request: XPCNull.shared)
    }

    public func sendMessage<Request: Codable>(name: String, request: Request) async throws {
        _ = try await self.sendMessage(name: name, request: request) as XPCNull
    }

    public func sendMessage<Response: Codable>(name: String) async throws -> Response {
        try await self.sendMessage(name: name, request: XPCNull.shared)
    }

    public func sendMessage<Request: Codable, Response: Codable>(name: String, request: Request) async throws -> Response {
        let body = try XPCEncoder().encode(request)

        return try await withCheckedThrowingContinuation { continuation in
            let message = xpc_dictionary_create(nil, nil, 0)

            xpc_dictionary_set_string(message, MessageKeys.name, name)
            xpc_dictionary_set_value(message, MessageKeys.body, body)

            xpc_connection_send_message_with_reply(self.connection, message, nil) { event in
                do {
                    switch event.type {
                    case .dictionary: break
                    case .error: throw XPCError(error: event)
                    default: throw Error.typeMismatch(expected: .dictionary, actual: event.type)
                    }

                    if let error = xpc_dictionary_get_value(event, MessageKeys.error) {
                        throw try XPCErrorRegistry.shared.decodeError(error)
                    }

                    guard let body = xpc_dictionary_get_value(event, MessageKeys.body) else {
                        throw Error.missingMessageBody
                    }

                    continuation.resume(returning: try XPCDecoder().decode(type: Response.self, from: body))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func sendOnewayMessage<Message: Codable>(message: Message, withName name: String? = nil) throws {
        try self.sendOnewayRawMessage(name: name, body: XPCEncoder().encode(message), key: MessageKeys.body, asReplyTo: nil)
    }

    private func sendOnewayError(error: Swift.Error, asReplyTo original: xpc_object_t?) throws {
        try self.sendOnewayRawMessage(
            name: nil,
            body: XPCErrorRegistry.shared.encodeError(error),
            key: MessageKeys.error,
            asReplyTo: original
        )
    }

    private func sendOnewayRawMessage(
        name: String?,
        body: xpc_object_t,
        key: String,
        asReplyTo original: xpc_object_t?
    ) throws {
        let xpcMessage: xpc_object_t
        if let original = original, let reply = xpc_dictionary_create_reply(original) {
            xpcMessage = reply
        } else {
            xpcMessage = xpc_dictionary_create(nil, nil, 0)
        }

        if let name = name {
            xpc_dictionary_set_string(xpcMessage, MessageKeys.name, name)
        }

        xpc_dictionary_set_value(xpcMessage, key, body)

        xpc_connection_send_message(self.connection, xpcMessage)
    }

    public func sendBarrier(_ barrier: @escaping () -> Void) {
        xpc_connection_send_barrier(self.connection, barrier)
    }

    private func handleEvent(_ event: xpc_object_t) {
        if #available(macOS 12.0, *) {
        } else {
            do {
                try self.checkCallerCredentials(event: event)
            } catch {
                self.errorHandler?(self, error)
                return
            }
        }

        if let customEventHandler = self.customEventHandler {
            customEventHandler(event)
            return
        }

        do {
            switch event.type {
            case .dictionary:
                if let error = xpc_dictionary_get_value(event, MessageKeys.error) {
                    throw try XPCErrorRegistry.shared.decodeError(error)
                }

                self.respond(to: event)
            case .error:
                throw XPCError(error: event)
            default:
                throw Error.typeMismatch(expected: .dictionary, actual: event.type)
            }
        } catch {
            self.errorHandler?(self, error)
            return
        }
    }

    @available(macOS, obsoleted: 12.0)
    private func checkCallerCredentials(event: xpc_object_t) throws {
        guard let requirementString = self.codeSigningRequirement else { return }

        var code: SecCode? = nil
        var err: OSStatus

        if #available(macOS 11.0, *) {
            err = SecCodeCreateWithXPCMessage(event, [], &code)
        } else {
            var keyCB = kCFTypeDictionaryKeyCallBacks
            var valueCB = kCFTypeDictionaryValueCallBacks
            let key = kSecGuestAttributePid
            var pid = Int64(xpc_connection_get_pid(xpc_dictionary_get_remote_connection(event)!))
            let value = CFNumberCreate(kCFAllocatorDefault, .sInt64Type, &pid)
            let attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &keyCB, &valueCB)

            CFDictionarySetValue(
                attributes,
                unsafeBitCast(key, to: UnsafeRawPointer.self),
                unsafeBitCast(value, to: UnsafeRawPointer.self)
            )

            err = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        }

        guard err == errSecSuccess else {
            throw Error.callerFailedCredentialCheck(err)
        }

        let cfRequirementString = requirementString.withCString {
            CFStringCreateWithCString(kCFAllocatorDefault, $0, CFStringBuiltInEncodings.UTF8.rawValue)
        }

        var requirement: SecRequirement? = nil
        err = SecRequirementCreateWithString(cfRequirementString!, [], &requirement)
        guard err == errSecSuccess else {
            throw Error.callerFailedCredentialCheck(err)
        }

        err = SecCodeCheckValidity(code!, [], requirement)
        guard err == errSecSuccess else {
            throw Error.callerFailedCredentialCheck(err)
        }
    }

    private func respond(to event: xpc_object_t) {
        let messageHandler: MessageHandler.RawHandler

        do {
            guard let name = xpc_dictionary_get_value(event, MessageKeys.name).flatMap({ String($0) }) else {
                throw Error.missingMessageName
            }

            guard let _messageHandler = self.getMessageHandler(forName: name) else {
                throw Error.unexpectedMessage
            }

            messageHandler = _messageHandler
        } catch {
            self.errorHandler?(self, error)
            return
        }

        Task {
            let response: xpc_object_t

            do {
                response = try await messageHandler(self, event)
            } catch {
                try self.sendOnewayError(error: error, asReplyTo: event)
                return
            }

            do {
                try self.sendOnewayRawMessage(name: nil, body: response, key: MessageKeys.body, asReplyTo: event)
            } catch {
                self.errorHandler?(self, error)
            }
        }
    }
}
