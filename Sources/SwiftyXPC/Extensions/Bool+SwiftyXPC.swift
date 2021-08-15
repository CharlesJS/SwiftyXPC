//
//  Bool+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/29/21.
//

import XPC

extension Bool: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? { xpc_bool_get_value(xpcObject) }
    public func toXPCObject() -> xpc_object_t? { xpc_bool_create(self) }
}
