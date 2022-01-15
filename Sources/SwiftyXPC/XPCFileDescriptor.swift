//
//  XPCFileDescriptorWrapper.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/24/21.
//

import Darwin
import System

/// An owned wrapper around a file descriptor, which can be embedded within XPC messages to send file descriptors to other processes.
///
/// This wrapper takes ownership of the file descriptor so the user doesn't need to close it manually.
///
/// This wrapper serves two purposes:
/// 1. To provide compatibility with macOS 10.15, which does not support the `FileDescriptor` structure.
/// 2. To ensure that the file descriptor is closed when the message is embedded.
///
/// On versions of macOS greater than 11.0, you can also simply use a `FileDescriptor` from the `System` module. However, the `FileDescriptor`
/// is not owned, so you will need to make sure the file descriptor is not closed in the sender process before the message is embedded
/// in an XPC message.
public final class XPCFileDescriptor: Codable {
    internal let fileDescriptor: Int32

    /// Create an `XPCFileDescriptor` from a raw file descriptor and take the ownership of it.
    /// The file descriptor will be closed automatically when this instance is deinitialized.
    public init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    /// Create an `XPCFileDescriptor` from a `FileDescriptor` and take the ownership of it.
    /// The file descriptor will be closed automatically when this instance is deinitialized.
    @available(macOS 11.0, *)
    public init(fileDescriptor: FileDescriptor) {
        self.fileDescriptor = fileDescriptor.rawValue
    }

    /// Duplicate the file descriptor. The caller is responsible for closing the returned file descriptor.
    public func dup() throws -> Int32 {
        let fd = Darwin.dup(fileDescriptor)

        if fd < 0 {
            if #available(macOS 11.0, *) {
                throw Errno(rawValue: errno)
            } else {
                throw XPCErrorRegistry.BoxedError(domain: "NSPOSIXErrorDomain", code: Int(errno))
            }
        }

        return fd
    }

    /// Duplicate the file descriptor. The caller is responsible for closing the returned `FileDescriptor`.
    @available(macOS 11.0, *)
    public func duplicate() throws -> FileDescriptor {
        if #available(macOS 12.0, *) {
            return try FileDescriptor(rawValue: self.fileDescriptor).duplicate()
        } else {
            return try FileDescriptor(rawValue: self.dup())
        }
    }
    
    deinit {
        close(self.fileDescriptor)
    }
}
