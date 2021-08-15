//
//  CFUUID+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFUUID: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        guard let uuid = xpc_uuid_get_bytes(xpcObject) else { return nil }

        return CFUUIDCreateWithBytes(
            kCFAllocatorDefault,
            uuid[0], uuid[1], uuid[2], uuid[3], uuid[4], uuid[5], uuid[6], uuid[7],
            uuid[8], uuid[9], uuid[10], uuid[11], uuid[12], uuid[13], uuid[14], uuid[15]
        ).map { unsafeDowncast($0, to: self) }
    }

    public func toXPCObject() -> xpc_object_t? {
        let bytes = CFUUIDGetUUIDBytes(self)

        let uuid = [
            bytes.byte0, bytes.byte1, bytes.byte2, bytes.byte3, bytes.byte4, bytes.byte5,
            bytes.byte6, bytes.byte7, bytes.byte8, bytes.byte9, bytes.byte10, bytes.byte11,
            bytes.byte12, bytes.byte13, bytes.byte14, bytes.byte15
        ]

        return uuid.withUnsafeBufferPointer {
            xpc_uuid_create($0.baseAddress!)
        }
    }
}
