//
//  XPCConvertible.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

public protocol XPCConvertible: _XPCConvertible {
    static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self?
    func toXPCObject() -> xpc_object_t?
}

public protocol _XPCConvertible {
    static func _fromXPCObject(_ xpcObject: xpc_object_t) -> _XPCConvertible?
    func toXPCObject() -> xpc_object_t?
}

extension XPCConvertible {
    public static func _fromXPCObject(_ xpcObject: xpc_object_t) -> _XPCConvertible? {
        self.fromXPCObject(xpcObject)
    }
}

public func convertFromXPC(_ object: xpc_object_t) -> XPCConvertible? {
    switch xpc_get_type(object) {
    case XPC_TYPE_NULL:
        return CFNull.fromXPCObject(object)
    case XPC_TYPE_BOOL:
        return Bool.fromXPCObject(object)
    case XPC_TYPE_INT64:
        return Int64.fromXPCObject(object)
    case XPC_TYPE_UINT64:
        return UInt64.fromXPCObject(object)
    case XPC_TYPE_DOUBLE:
        return Double.fromXPCObject(object)
    case XPC_TYPE_DATE:
        return CFDate.fromXPCObject(object)
    case XPC_TYPE_DATA:
        return CFData.fromXPCObject(object)
    case XPC_TYPE_ENDPOINT:
        return XPCEndpoint(connection: object)
    case XPC_TYPE_FD:
        return XPCFileDescriptorWrapper.fromXPCObject(object)
    case XPC_TYPE_STRING:
        return String.fromXPCObject(object)
    case XPC_TYPE_UUID:
        return CFUUID.fromXPCObject(object)
    case XPC_TYPE_ARRAY:
        return [Any].fromXPCObject(object)
    case XPC_TYPE_DICTIONARY:
        if CFError.isXPCEncodedError(object) {
            return CFError.fromXPCObject(object)
        } else if CFURL.isXPCEncodedURL(object) {
            return CFURL.fromXPCObject(object)
        } else {
            return [String : Any].fromXPCObject(object)
        }
    default:
        return nil
    }
}

public func convertToXPC(_ val: Any) -> xpc_object_t? {
    if let convertible = val as? _XPCConvertible {
        return convertible.toXPCObject()
    } else {
        let obj = convertToObject(val)

        switch CFGetTypeID(obj) {
        case CFNullGetTypeID():
            return unsafeBitCast(obj, to: CFNull.self).toXPCObject()
        case CFBooleanGetTypeID():
            return unsafeBitCast(obj, to: CFBoolean.self).toXPCObject()
        case CFNumberGetTypeID():
            return unsafeBitCast(obj, to: CFNumber.self).toXPCObject()
        case CFDateGetTypeID():
            return unsafeBitCast(obj, to: CFDate.self).toXPCObject()
        case CFDataGetTypeID():
            return unsafeBitCast(obj, to: CFData.self).toXPCObject()
        case CFStringGetTypeID():
            return unsafeBitCast(obj, to: CFString.self).toXPCObject()
        case CFUUIDGetTypeID():
            return unsafeBitCast(obj, to: CFUUID.self).toXPCObject()
        case CFArrayGetTypeID():
            return unsafeBitCast(obj, to: CFArray.self).toXPCObject()
        case CFDictionaryGetTypeID():
            return unsafeBitCast(obj, to: CFDictionary.self).toXPCObject()
        case CFURLGetTypeID():
            return unsafeBitCast(obj, to: CFURL.self).toXPCObject()
        case CFErrorGetTypeID():
            return unsafeBitCast(obj, to: CFError.self).toXPCObject()
        default:
            return nil
        }
    }
}

private func convertToObject(_ val: Any) -> AnyObject {
    if let pointer = val as? UnsafeRawPointer {
       return unsafeBitCast(UInt(bitPattern: pointer), to: AnyObject.self)
    } else if let pointer = val as? UnsafeMutableRawPointer {
        return unsafeBitCast(UInt(bitPattern: pointer), to: AnyObject.self)
    } else {
        return val as AnyObject
    }
}
