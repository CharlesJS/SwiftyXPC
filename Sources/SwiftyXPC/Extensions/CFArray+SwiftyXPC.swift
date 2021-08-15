//
//  CFArray+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFArray: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        var callBacks = kCFTypeArrayCallBacks
        let count = xpc_array_get_count(xpcObject)
        let array = CFArrayCreateMutable(kCFAllocatorDefault, count, &callBacks)

        for i in 0..<count {
            if let theObj = convertFromXPC(xpc_array_get_value(xpcObject, i)) {
                CFArrayAppendValue(array, unsafeBitCast(theObj, to: UnsafeRawPointer.self))
            }
        }

        return array.map { unsafeDowncast($0, to: self) }
    }

    public func toXPCObject() -> xpc_object_t? {
        let count = CFArrayGetCount(self)

        let objs = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: count)
        defer { objs.deallocate() }

        let xpcObjs = UnsafeMutablePointer<xpc_object_t>.allocate(capacity: count)
        defer { xpcObjs.deallocate() }

        CFArrayGetValues(self, CFRangeMake(0, count), objs)

        let xpcCount = (0..<count).reduce(into: 0) {
            if let xpcObject = (objs[$1] as? XPCConvertible)?.toXPCObject() {
                xpcObjs[$0] = xpcObject
                $0 += 1
            }
        }

        return xpc_array_create(xpcObjs, xpcCount)
    }
}
