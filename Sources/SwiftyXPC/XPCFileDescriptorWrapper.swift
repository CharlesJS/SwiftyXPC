//
//  XPCFileDescriptorWrapper.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/24/21.
//

import System
import XPC

public final class XPCFileDescriptorWrapper: XPCConvertible {
    public let fileDescriptor: FileDescriptor

    public init(fileDescriptor: FileDescriptor) {
        self.fileDescriptor = fileDescriptor
    }

    deinit {
        _ = try? self.fileDescriptor.close()
    }

    public static func fromXPCObject(_ xpcObject: xpc_object_t) -> XPCFileDescriptorWrapper? {
        self.init(fileDescriptor: FileDescriptor(rawValue: xpc_fd_dup(xpcObject)))
    }

    public func toXPCObject() -> xpc_object_t? {
        xpc_fd_create(self.fileDescriptor.rawValue)
    }
}
