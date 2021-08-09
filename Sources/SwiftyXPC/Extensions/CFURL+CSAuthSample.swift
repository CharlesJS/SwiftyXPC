//
//  CFURL+CSAuthSample.swift
//  CSAuthSampleCommon
//
//  Created by Charles Srstka on 7/22/21.
//

import CoreFoundation
import XPC

extension CFURL: XPCConvertible {
    private static let dictionaryKey = "com.charlessoft.CSAuthSample.CFDictionaryEncodingKeys.url"

    static func isXPCEncodedURL(_ object: xpc_object_t) -> Bool {
        xpc_dictionary_get_value(object, Self.dictionaryKey) != nil
    }

    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        guard let xpcString = xpc_dictionary_get_value(xpcObject, Self.dictionaryKey),
              let string = CFString.fromXPCObject(xpcString) else { return nil }

        return CFURLCreateWithString(kCFAllocatorDefault, string, nil).map { unsafeDowncast($0, to: self) }
    }

    public func toXPCObject() -> xpc_object_t? {
        [Self.dictionaryKey : CFURLGetString(self)].toXPCObject()
    }
}

extension CFURL {
    public func withUnsafeFileSystemRepresentation<T>(closure: (UnsafePointer<CChar>) throws -> T) rethrows -> T {
        let bufferSize = Int(PATH_MAX) + 1

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        CFURLGetFileSystemRepresentation(self, true, buffer, bufferSize)

        return try buffer.withMemoryRebound(to: CChar.self, capacity: bufferSize) { try closure($0) }
    }
}
