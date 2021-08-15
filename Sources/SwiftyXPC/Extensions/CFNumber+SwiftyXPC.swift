//
//  CFNumber+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFBoolean: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        unsafeDowncast(xpc_bool_get_value(xpcObject) ? kCFBooleanTrue : kCFBooleanFalse, to: self)
    }

    public func toXPCObject() -> xpc_object_t? {
        xpc_bool_create(CFBooleanGetValue(self))
    }
}

extension CFNumber: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        switch xpc_get_type(xpcObject) {
        case XPC_TYPE_INT64:
            var int = xpc_int64_get_value(xpcObject)

            return CFNumberCreate(kCFAllocatorDefault, .sInt64Type, &int).map { unsafeDowncast($0, to: self) }
        case XPC_TYPE_UINT64:
            var uint = xpc_int64_get_value(xpcObject)

            return CFNumberCreate(kCFAllocatorDefault, .sInt64Type, &uint).map { unsafeDowncast($0, to: self) }
        case XPC_TYPE_DOUBLE:
            var double = xpc_double_get_value(xpcObject)

            return CFNumberCreate(kCFAllocatorDefault, .doubleType, &double).map { unsafeDowncast($0, to: self) }
        default:
            return nil
        }
    }

    public func toXPCObject() -> xpc_object_t? {
        switch CFNumberGetType(self) {
        case .floatType, .float32Type, .float64Type, .doubleType, .cgFloatType:
            var double: Double = 0

            if !CFNumberGetValue(self, .doubleType, &double) {
                double = 0
            }

            return xpc_double_create(double)
        default:
            var int: Int64 = 0

            if !CFNumberGetValue(self, .sInt64Type, &int) {
                int = 0
            }

            return xpc_int64_create(int)
        }
    }
}
