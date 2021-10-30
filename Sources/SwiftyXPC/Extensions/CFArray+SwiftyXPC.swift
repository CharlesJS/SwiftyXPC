//
//  CFArray+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFArray {
    public subscript<I: BinaryInteger>(index: I) -> CFTypeRef? {
        unsafeBitCast(CFArrayGetValueAtIndex(self, CFIndex(index)), to: CFTypeRef?.self)
    }

    public subscript<I: BinaryInteger, T: CFTypeRef>(index: I, as typeID: CFTypeID) -> T? {
        guard let value = self[index], CFGetTypeID(value) == typeID else { return nil }

        return value as? T
    }
}

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

        CFArrayGetValues(self, CFRangeMake(0, count), objs)

        let xpcObjs: [xpc_object_t] = (0..<count).compactMap {
            if let pointer = objs[$0], let xpcObject = convertToXPC(pointer) {
                return xpcObject
            } else {
                return nil
            }
        }

        return xpcObjs.withUnsafeBufferPointer { xpc_array_create($0.baseAddress, $0.count) }
    }
}
