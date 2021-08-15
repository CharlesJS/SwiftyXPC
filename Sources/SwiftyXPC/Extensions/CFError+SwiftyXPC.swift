//
//  CFError+SwiftyXPC.swift
//  SwiftyXPC
//
//  An extension to give CFError conformance to the Error protocol
//  without requiring your tool to link against Foundation.
//
//  Created by Charles Srstka on 7/20/21.
//

import CoreFoundation
import XPC

extension CFError: Error {
    public var _domain: String { CFErrorGetDomain(self).toString() }
    public var _code: Int { Int(CFErrorGetCode(self)) }
    public var _userInfo: AnyObject? { CFErrorCopyUserInfo(self) }

    public static func make(_ status: OSStatus) -> CFError {
        let domain: CFString
        let code: CFIndex

        let posixErrorBase: OSStatus = 100000

        if (posixErrorBase..<(posixErrorBase + 1000)).contains(status) {
            domain = CFString.fromString("NSPOSIXErrorDomain")
            code = CFIndex(status - posixErrorBase)
        } else {
            domain = CFString.fromString("NSOSStatusErrorDomain")
            code = CFIndex(status)
        }

        return CFErrorCreate(kCFAllocatorDefault, domain, code, nil)
    }
}

extension CFError: XPCConvertible {
    struct EncodingKeys {
        static let dictionaryKey = "com.charlessoft.SwiftyXPC.CFDictionaryEncodingKeys.error"

        static let domain = "com.charlessoft.SwiftyXPC.error.domain"
        static let code = "com.charlessoft.SwiftyXPC.error.code"
        static let userInfo = "com.charlessoft.SwiftyXPC.error.userInfo"
    }

    static func isXPCEncodedError(_ object: xpc_object_t) -> Bool {
        xpc_dictionary_get_value(object, EncodingKeys.dictionaryKey) != nil
    }

    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        guard let dict = xpc_dictionary_get_value(xpcObject, EncodingKeys.dictionaryKey) else { return nil }

        let domain = xpc_dictionary_get_value(dict, EncodingKeys.domain).flatMap { convertFromXPC($0) }
        let code = xpc_dictionary_get_int64(dict, EncodingKeys.code)
        let userInfo = xpc_dictionary_get_value(dict, EncodingKeys.userInfo).flatMap { convertFromXPC($0) }

        return CFErrorCreate(
            kCFAllocatorDefault,
            unsafeBitCast(domain as AnyObject, to: CFString?.self),
            CFIndex(code),
            unsafeBitCast(userInfo as AnyObject, to: CFDictionary?.self)
        ).map { unsafeDowncast($0, to: self) }
    }

    public func toXPCObject() -> xpc_object_t? {
        guard let domain = CFErrorGetDomain(self)?.toString() else { return nil }

        var dict: [String : XPCConvertible] = [
            EncodingKeys.domain: domain,
            EncodingKeys.code: Int64(CFErrorGetCode(self))
        ]

        if let userInfo = CFErrorCopyUserInfo(self) {
            dict[EncodingKeys.userInfo] = userInfo
        }

        return [EncodingKeys.dictionaryKey: dict].toXPCObject()
    }
}
