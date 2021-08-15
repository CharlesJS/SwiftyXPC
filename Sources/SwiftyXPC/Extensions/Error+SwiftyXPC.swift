//
//  File.swift
//  File
//
//  Created by Charles Srstka on 8/15/21.
//

import CoreFoundation
import XPC

extension Error {
    public func toXPCObject() -> xpc_object_t? {
        let domain = self._domain

        var dict: [String : XPCConvertible] = [
            CFError.EncodingKeys.domain: domain,
            CFError.EncodingKeys.code: Int64(self._code)
        ]

        if let userInfo = unsafeBitCast(self._userInfo, to: CFDictionary?.self) {
            dict[CFError.EncodingKeys.userInfo] = userInfo
        }

        return [CFError.EncodingKeys.dictionaryKey: dict].toXPCObject()
    }
}
