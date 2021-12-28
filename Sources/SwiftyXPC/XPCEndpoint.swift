//
//  XPCEndpoint.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/24/21.
//

import XPC

public struct XPCEndpoint: Codable {
    private struct CanOnlyBeDecodedByXPCDecoder: Error {
        var localizedDescription: String { "XPCEndpoint can only be decoded via XPCDecoder." }
    }

    private struct CanOnlyBeEncodedByXPCEncoder: Error {
        var localizedDescription: String { "XPCEndpoint can only be encoded via XPCEncoder." }
    }

    private let endpoint: xpc_endpoint_t

    internal init(connection: xpc_connection_t) {
        self.endpoint = xpc_endpoint_create(connection)
    }

    internal func makeConnection() -> xpc_connection_t {
        xpc_connection_create_from_endpoint(self.endpoint)
    }

    public init(from decoder: Decoder) throws {
        throw CanOnlyBeDecodedByXPCDecoder()
    }

    public func encode(to encoder: Encoder) throws {
        throw CanOnlyBeEncodedByXPCEncoder()
    }
}
