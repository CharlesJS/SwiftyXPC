import XPC

public enum XPCError: Error {
    case connectionInterrupted
    case connectionInvalid
    case terminationImminent
    case unknown

    internal init(error: xpc_object_t) {
        if error === XPC_ERROR_CONNECTION_INTERRUPTED {
            self = .connectionInterrupted
        } else if error === XPC_ERROR_CONNECTION_INVALID {
            self = .connectionInvalid
        } else if error === XPC_ERROR_TERMINATION_IMMINENT {
            self = .terminationImminent
        } else {
            self = .unknown
        }
    }
}
