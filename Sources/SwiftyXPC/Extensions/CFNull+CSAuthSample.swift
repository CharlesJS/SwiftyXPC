//
//  CFNull+CSAuthSample.swift
//  CSAuthSampleCommon
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFNull: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? { unsafeDowncast(kCFNull, to: self) }
    public func toXPCObject() -> xpc_object_t? { xpc_null_create() }
}
