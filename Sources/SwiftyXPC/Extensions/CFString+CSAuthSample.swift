//
//  CFString+CSAuthSample.swift
//  CSAuthSampleCommon
//
//  Some helper methods to facilitate working with CFStrings without requiring your tool to link against Foundation.
//
//  Created by Charles Srstka on 7/20/21.
//

import CoreFoundation
import XPC

extension CFString {
    public static func fromString(_ string: String) -> CFString {
        let utf8 = CFStringBuiltInEncodings.UTF8.rawValue
        return string.withCString { CFStringCreateWithCString(kCFAllocatorDefault, $0, utf8) }
    }

    public func toString() -> String {
        self.withCString { String(cString: $0) }
    }

    public func withCString<T>(
        encoding: CFStringEncoding = CFStringBuiltInEncodings.UTF8.rawValue,
        closure: (UnsafePointer<CChar>) throws -> T
    ) rethrows -> T {
        if let ptr = CFStringGetCStringPtr(self, encoding) {
            return try closure(ptr)
        } else {
            let bufferSize = Int(CFStringGetMaximumSizeForEncoding(CFStringGetLength(self), encoding))
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            CFStringGetCString(self, buffer, bufferSize, encoding)
            return try closure(buffer)
        }
    }
}

extension CFString: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        let length = xpc_string_get_length(xpcObject)

        return xpc_string_get_string_ptr(xpcObject)?.withMemoryRebound(to: UInt8.self, capacity: length) {
            CFStringCreateWithBytes(
                kCFAllocatorDefault,
                $0,
                length,
                CFStringBuiltInEncodings.UTF8.rawValue,
                false
            ).map { unsafeDowncast($0, to: self) }
        }
    }

    public func toXPCObject() -> xpc_object_t? {
        xpc_string_create(self.toString())
    }
}
