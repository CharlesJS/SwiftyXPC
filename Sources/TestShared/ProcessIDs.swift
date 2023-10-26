//
//  ProcessIDs.swift
//
//
//  Created by Charles Srstka on 10/14/23.
//

import Darwin
import SwiftyXPC
import System

// swift-format-ignore: AllPublicDeclarationsHaveDocumentation
public struct ProcessIDs: Codable {
    public let pid: pid_t
    public let effectiveUID: uid_t
    public let effectiveGID: gid_t
    public let auditSessionID: au_asid_t

    public init(connection: XPCConnection) throws {
        self.pid = getpid()
        self.effectiveUID = geteuid()
        self.effectiveGID = getegid()
        self.auditSessionID = connection.auditSessionIdentifier
    }
}
