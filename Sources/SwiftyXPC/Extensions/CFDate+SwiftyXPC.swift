//
//  CFDate+SwiftyXPC.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/20/21.
//

import CoreFoundation
import XPC

extension CFDate: XPCConvertible {
    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> Self? {
        let nsSince1970 = xpc_date_get_value(xpcObject)

        let sec = nsSince1970 / Int64(NSEC_PER_SEC)
        let ns = nsSince1970 % Int64(NSEC_PER_SEC)

        let interval = CFTimeInterval(sec) + CFTimeInterval(ns) / CFTimeInterval(NSEC_PER_SEC)

        return CFDateCreate(kCFAllocatorDefault, kCFAbsoluteTimeIntervalSince1970 + interval).map {
            unsafeDowncast($0, to: self)
        }
    }

    public func toXPCObject() -> xpc_object_t? {
        let absTime = CFDateGetAbsoluteTime(self)

        let timeSince1970 = absTime - kCFAbsoluteTimeIntervalSince1970

        var iPart: Double = 0
        let fPart = modf(timeSince1970, &iPart)

        let nsSince1970 = Int64(iPart) * Int64(NSEC_PER_SEC) + Int64(fPart * Double(NSEC_PER_SEC))

        return xpc_date_create(nsSince1970)
    }
}
