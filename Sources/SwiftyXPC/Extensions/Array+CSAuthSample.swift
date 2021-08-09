//
//  Array+CSAuthSample.swift
//  CSAuthSampleCommon
//
//  Created by Charles Srstka on 7/22/21.
//

import XPC

extension Array: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        (0..<xpc_array_get_count(xpcObject)).compactMap {
            convertFromXPC(xpc_array_get_value(xpcObject, $0)) as? Element
        }
    }

    public func toXPCObject() -> xpc_object_t? {
        self.compactMap { ($0 as? XPCConvertible)?.toXPCObject() }.withUnsafeBufferPointer {
            xpc_array_create($0.baseAddress, $0.count)
        }
    }
}
