//
//  Numerics+CSAuthSample.swift
//  CSAuthSampleCommon
//
//  Created by Charles Srstka on 7/29/21.
//

import XPC

extension SignedInteger {
    public static func fromXPCObject(_ xpc: xpc_object_t) -> Self? {
        self.init(exactly: xpc_int64_get_value(xpc))
    }

    public func toXPCObject() -> xpc_object_t? { xpc_int64_create(Int64(self)) }
}

extension UnsignedInteger {
    public static func fromXPCObject(_ xpc: xpc_object_t) -> Self? {
        self.init(exactly: xpc_uint64_get_value(xpc))
    }

    public func toXPCObject() -> xpc_object_t? { xpc_uint64_create(UInt64(self)) }
}

extension BinaryFloatingPoint {
    public static func fromXPCObject(_ xpc: xpc_object_t) -> Self? {
        self.init(xpc_double_get_value(xpc))
    }

    public func toXPCObject() -> xpc_object_t? { xpc_double_create(Double(self)) }
}

extension Int: XPCConvertible {}
extension Int8: XPCConvertible {}
extension Int16: XPCConvertible {}
extension Int32: XPCConvertible {}
extension Int64: XPCConvertible {}
extension UInt: XPCConvertible {}
extension UInt8: XPCConvertible {}
extension UInt16: XPCConvertible {}
extension UInt32: XPCConvertible {}
extension UInt64: XPCConvertible {}
extension Float32: XPCConvertible {}
extension Float64: XPCConvertible {}
