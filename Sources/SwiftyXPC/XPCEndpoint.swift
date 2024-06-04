//
//  XPCEndpoint.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/24/21.
//

import XPC

/// A reference to an `XPCListener` object.
///
/// An `XPCEndpoint` can be passed over an active XPC connection, allowing the process on the other end to initialize a new `XPCConnection`
/// to communicate with it.
public struct XPCEndpoint: Codable, @unchecked Sendable {
    private struct CanOnlyBeDecodedByXPCDecoder: Error {
        var localizedDescription: String { "XPCEndpoint can only be decoded via XPCDecoder." }
    }

    private struct CanOnlyBeEncodedByXPCEncoder: Error {
        var localizedDescription: String { "XPCEndpoint can only be encoded via XPCEncoder." }
    }

    internal let endpoint: xpc_endpoint_t

    internal init(connection: xpc_connection_t) {
        self.endpoint = xpc_endpoint_create(connection)
    }

    internal init(endpoint: xpc_endpoint_t) {
        self.endpoint = endpoint
    }

    internal func makeConnection() -> xpc_connection_t {
        xpc_connection_create_from_endpoint(self.endpoint)
    }

    /// Required method for the purpose of conforming to the `Decodable` protocol.
    ///
    /// - Throws: Trying to decode this object from any decoder type other than `XPCDecoder` will result in an error.
    public init(from decoder: Decoder) throws {
        throw CanOnlyBeDecodedByXPCDecoder()
    }

    /// Required method for the purpose of conforming to the `Encodable` protocol.
    ///
    /// - Throws: Trying to encode this object from any encoder type other than `XPCEncoder` will result in an error.
    public func encode(to encoder: Encoder) throws {
        throw CanOnlyBeEncodedByXPCEncoder()
    }
}
