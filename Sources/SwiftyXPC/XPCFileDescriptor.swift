//
//  XPCFileDescriptorWrapper.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 7/24/21.
//

import Darwin

/// A wrapper around a file descriptor, which can be embedded within XPC messages to send file descriptors to other processes.
///
/// Included for compatibility with macOS 10.15.
/// On versions of macOS greater than 11.0, this class is unnecessary, and you can simply use a `FileDescriptor` from the `System` module instead.
public final class XPCFileDescriptor: Codable {
    /// The wrapped raw file descriptor.
    public let fileDescriptor: Int32

    /// Create an `XPCFileDescriptor` from a raw file descriptor.
    public init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }
}
