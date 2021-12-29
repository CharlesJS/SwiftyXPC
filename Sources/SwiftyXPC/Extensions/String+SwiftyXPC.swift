//
//  String+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/29/21.
//

import XPC

extension String {
    /// Create a `String` from an `xpc_object_t`.
    ///
    /// - Parameter xpcObject: An `xpc_object_t` wrapping a string.
    public init?(_ xpcObject: xpc_object_t) {
        guard let ptr = xpc_string_get_string_ptr(xpcObject) else { return nil }
        let length = xpc_string_get_length(xpcObject)

        self = UnsafeBufferPointer(start: ptr, count: length).withMemoryRebound(to: UInt8.self) {
            String(decoding: $0, as: UTF8.self)
        }
    }

    /// Convert a `String` to an `xpc_object_t`.
    ///
    /// - Returns: An `xpc_object_t` wrapping the receiver's string.
    public func toXPCObject() -> xpc_object_t? { xpc_string_create(self) }
}
