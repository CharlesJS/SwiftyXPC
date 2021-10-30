//
//  Dictionary+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/30/21.
//

import CoreFoundation
import XPC

extension Dictionary {
    public subscript<T: CFTypeRef>(key: Key, as typeID: CFTypeID) -> T? {
        guard let value = self[key] as AnyObject?, CFGetTypeID(value) == typeID else { return nil }

        return value as? T
    }
}

extension Dictionary: XPCConvertible where Key: StringProtocol {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Dictionary<Key, Value>? {
        var dict = Self.init()

        guard xpc_dictionary_apply(xpcObject, {
            let key = Key(cString: $0)

            guard let value = convertFromXPC($1) as? Value else { return false }

            dict[key] = value
            return true
        }) else { return nil }

        return dict
    }

    public func toXPCObject() -> xpc_object_t? {
        self.toXPCObject(replyTo: nil)
    }

    public func toXPCObject(replyTo: xpc_object_t?) -> xpc_object_t? {
        guard let dict: xpc_object_t = self.createEmptyXPCObject(replyTo: replyTo) else { return nil }

        for (eachKey, eachValue) in self {
            if let value = convertToXPC(eachValue) {
                eachKey.withCString {
                    xpc_dictionary_set_value(dict, $0, value)
                }
            }
        }

        return dict
    }

    private func createEmptyXPCObject(replyTo: xpc_object_t?) -> xpc_object_t? {
        if let original = replyTo {
            guard let dict = xpc_dictionary_create_reply(original) else { return nil }
            return dict
        } else {
            return xpc_dictionary_create_empty()
        }
    }
}

extension Dictionary: _XPCConvertible where Key: StringProtocol {}
