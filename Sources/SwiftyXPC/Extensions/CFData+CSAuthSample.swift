//
//  CFData+CSAuthSample.swift
//  CSAuthSampleCommon
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFData: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        let length = xpc_data_get_length(xpcObject)
        let bytes = xpc_data_get_bytes_ptr(xpcObject)?.bindMemory(to: UInt8.self, capacity: length)

        return CFDataCreate(kCFAllocatorDefault, bytes, length).map { unsafeDowncast($0, to: self) }
    }

    public func toXPCObject() -> xpc_object_t? {
        xpc_data_create(CFDataGetBytePtr(self), CFDataGetLength(self))
    }
}
