//
//  XPCEventHandler.swift
//  SwiftyXPC
//
//  Created by Charles Srstka on 8/8/21.
//

import XPC
import System

internal class XPCEventHandler {
    static let responseKey = "com.charlessoft.SwiftyXPC.XPCEventHandler.ResponseKey"
    static let errorKey = "com.charlessoft.SwiftyXPC.XPCEventHandler.ErrorKey"

    var messageHandler: (([String : Any]) async throws -> [String : Any]?)? = nil
    var errorHandler: ((Error) -> ())? = nil
    var sendReplyHandler: (([String : Any]) throws -> ())? = nil

    func handle(event: xpc_object_t) {
        let type = xpc_get_type(event)

        guard type == XPC_TYPE_DICTIONARY, let message = [String : Any].fromXPCObject(event) else {
            self.errorHandler?(type == XPC_TYPE_ERROR ? XPCError(error: event) : Errno.badFileTypeOrFormat)
            return
        }

        Task {
            do {
                if let response = try await self.messageHandler?(message) {
                    do {
                        try self.sendReplyHandler?([Self.responseKey : response])
                    } catch {
                        self.errorHandler?(error)
                    }
                }
            } catch {
                try self.sendReplyHandler?([Self.errorKey : error])
            }
        }
    }
}
