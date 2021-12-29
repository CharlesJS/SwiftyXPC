//
//  XPCErrorRegistry.swift
//
//
//  Created by Charles Srstka on 12/19/21.
//

import XPC

/// A registry which facilitates decoding error types that are sent over an XPC connection.
///
/// If an error is received, it will be looked up in the registry by its domain.
/// If a matching error type exists, that type is used to decode the error using `XPCDecoder`.
/// However, if the error domain is not registered, it will be encapsulated in a `BoxedError` which resembles Foundation's `NSError` class.
///
/// Use this registry to communicate rich error information without being beholden to `Foundation` user info dictionaries.
///
/// In the example below, any `MyError`s which are received over the wire will be converted back to a `MyError` enum, allowing handler functions to check for them:
///
///     enum MyError: Error, Codable {
///         case foo(Int)
///         case bar(String)
///     }
///
///     // then, at app startup time:
///
///     func someAppStartFunction() {
///        XPCErrorRegistry.shared.registerDomain(forErrorType: MyError.self)
///     }
///
///     // and later you can:
///
///     do {
///         try await connection.sendMessage(name: someName)
///     } catch let error as MyError {
///         switch error {
///         case .foo(let foo):
///             print("got foo: \(foo)")
///         case .bar(let bar):
///             print("got bar: \(bar)")
///         }
///     } catch {
///         print("got some other error")
///     }
public class XPCErrorRegistry {
    /// The shared `XPCErrorRegistry` instance.
    public static let shared = XPCErrorRegistry()

    private var errorDomainMap: [String: (Error & Codable).Type] = [
        String(reflecting: XPCError.self): XPCError.self,
        String(reflecting: XPCConnection.Error.self): XPCConnection.Error.self,
    ]

    /// Register an error type.
    ///
    /// - Parameters:
    ///   - domain: An `NSError`-style domain string to associate with this error type. In most cases, you will just pass `nil` for this parameter, in which case the default value of `String(reflecting: errorType)` will be used instead.
    ///   - errorType: An error type to register. This type must conform to `Codable`.
    public func registerDomain(_ domain: String? = nil, forErrorType errorType: (Error & Codable).Type) {
        errorDomainMap[domain ?? String(reflecting: errorType)] = errorType
    }

    internal func encodeError(_ error: Error, domain: String? = nil) throws -> xpc_object_t {
        try XPCEncoder().encode(BoxedError(error: error, domain: domain))
    }

    internal func decodeError(_ error: xpc_object_t) throws -> Error {
        let boxedError = try XPCDecoder().decode(type: BoxedError.self, from: error)

        return boxedError.encodedError ?? boxedError
    }

    /// An error type representing errors for which we have an `NSError`-style domain and code, but do not know the exact error class.
    ///
    /// To avoid requiring Foundation, this type does not formally adopt the `CustomNSError` protocol, but implements methods which
    /// can be used as a default implementation of the protocol. Foundation clients may want to add an empty implementation as in the example below.
    ///
    ///     extension XPCErrorRegistry.BoxedError: CustomNSError {}
    public struct BoxedError: Error, Codable {
        private enum Storage {
            case codable(Error & Codable)
            case uncodable(code: Int)
        }

        private enum Key: CodingKey {
            case domain
            case code
            case encodedError
        }

        private let storage: Storage

        /// An `NSError`-style error domain.
        public let errorDomain: String

        /// An `NSError`-style error code.
        public var errorCode: Int {
            switch self.storage {
            case .codable(let error):
                return error._code
            case .uncodable(let code):
                return code
            }
        }

        /// An `NSError`-style user info dictionary.
        public var errorUserInfo: [String: Any] { [:] }

        /// Hacky default implementation for internal `Error` requirements.
        ///
        /// This isn't great, but it allows this class to have basic functionality without depending on Foundation.
        ///
        /// Give `BoxedError` a default implementation of `CustomNSError` in Foundation clients to avoid this being called.
        public var _domain: String { self.errorDomain }

        /// Hacky default implementation for internal `Error` requirements.
        ///
        /// This isn't great, but it allows this class to have basic functionality without depending on Foundation.
        ///
        /// Give `BoxedError` a default implementation of `CustomNSError` to avoid this being called.
        public var _code: Int { self.errorCode }

        fileprivate var encodedError: Error? {
            switch self.storage {
            case .codable(let error):
                return error
            case .uncodable:
                return nil
            }
        }

        internal init(domain: String, code: Int) {
            self.errorDomain = domain
            self.storage = .uncodable(code: code)
        }

        internal init(error: Error, domain: String? = nil) {
            self.errorDomain = domain ?? error._domain

            if let codableError = error as? (Error & Codable) {
                self.storage = .codable(codableError)
            } else {
                self.storage = .uncodable(code: error._code)
            }
        }

        /// Included for `Decodable` conformance.
        ///
        /// - Parameter decoder: A decoder.
        ///
        /// - Throws: Any errors that come up in the process of decoding the error.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)

            self.errorDomain = try container.decode(String.self, forKey: .domain)
            let code = try container.decode(Int.self, forKey: .code)

            if let codableType = XPCErrorRegistry.shared.errorDomainMap[self.errorDomain],
                let codableError = try codableType.decodeIfPresent(from: container, key: .encodedError)
            {
                self.storage = .codable(codableError)
            } else {
                self.storage = .uncodable(code: code)
            }
        }

        /// Included for `Encodable` conformance.
        ///
        /// - Parameter encoder: An encoder.
        ///
        /// - Throws: Any errors that come up in the process of encoding the error.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)

            try container.encode(self.errorDomain, forKey: .domain)
            try container.encode(self.errorCode, forKey: .code)

            if case .codable(let error) = self.storage {
                try error.encode(into: &container, forKey: .encodedError)
            }
        }
    }
}

extension Error where Self: Codable {
    fileprivate static func decode(from error: xpc_object_t, using decoder: XPCDecoder) throws -> Error {
        try decoder.decode(type: self, from: error)
    }

    fileprivate static func decodeIfPresent<Key>(from keyedContainer: KeyedDecodingContainer<Key>, key: Key) throws -> Self?
    {
        try keyedContainer.decodeIfPresent(Self.self, forKey: key)
    }

    fileprivate func encode(using encoder: XPCEncoder) throws -> xpc_object_t {
        try encoder.encode(self)
    }

    fileprivate func encode<Key>(into keyedContainer: inout KeyedEncodingContainer<Key>, forKey key: Key) throws {
        try keyedContainer.encode(self, forKey: key)
    }
}
