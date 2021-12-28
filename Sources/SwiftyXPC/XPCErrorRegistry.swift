//
//  XPCErrorRegistry.swift
//  
//
//  Created by Charles Srstka on 12/19/21.
//

import XPC

public class XPCErrorRegistry {
    public static let shared = XPCErrorRegistry()

    private var errorDomainMap: [String : (Error & Codable).Type] = [
        String(reflecting: XPCError.self) : XPCError.self,
        String(reflecting: XPCConnection.Error.self): XPCConnection.Error.self,
    ]

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

        public let errorDomain: String
        public var errorCode: Int {
            switch self.storage {
            case .codable(let error):
                return error._code
            case .uncodable(let code):
                return code
            }
        }

        public var _domain: String { self.errorDomain }
        public var _code: Int { self.errorCode }

        fileprivate var encodedError: Error? {
            switch self.storage {
            case .codable(let error):
                return error
            case .uncodable:
                return nil
            }
        }

        public var errorUserInfo: [String : Any] { [:] }

        public init(domain: String, code: Int) {
            self.errorDomain = domain
            self.storage = .uncodable(code: code)
        }

        public init(error: Error, domain: String? = nil) {
            self.errorDomain = domain ?? error._domain

            if let codableError = error as? (Error & Codable) {
                self.storage = .codable(codableError)
            } else {
                self.storage = .uncodable(code: error._code)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)

            self.errorDomain = try container.decode(String.self, forKey: .domain)
            let code = try container.decode(Int.self, forKey: .code)

            if let codableType = XPCErrorRegistry.shared.errorDomainMap[self.errorDomain],
               let codableError = try codableType.decodeIfPresent(from: container, key: .encodedError) {
                self.storage = .codable(codableError)
            } else {
                self.storage = .uncodable(code: code)
            }
        }

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

private extension Error where Self: Codable {
    static func decode(from error: xpc_object_t, using decoder: XPCDecoder) throws -> Error {
        try decoder.decode(type: self, from: error)
    }

    static func decodeIfPresent<Key>(from keyedContainer: KeyedDecodingContainer<Key>, key: Key) throws -> Self? {
        try keyedContainer.decodeIfPresent(Self.self, forKey: key)
    }

    func encode(using encoder: XPCEncoder) throws -> xpc_object_t {
        try encoder.encode(self)
    }

    func encode<Key>(into keyedContainer: inout KeyedEncodingContainer<Key>, forKey key: Key) throws {
        try keyedContainer.encode(self, forKey: key)
    }
}
