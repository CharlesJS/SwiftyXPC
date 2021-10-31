import XPC

public enum XPCError: Error {
    case connectionInterrupted
    case connectionInvalid
    case terminationImminent
    case invalidCodeSignatureRequirement
    case unknown(String)

    internal init(error: xpc_object_t) {
        if error === XPC_ERROR_CONNECTION_INTERRUPTED {
            self = .connectionInterrupted
        } else if error === XPC_ERROR_CONNECTION_INVALID {
            self = .connectionInvalid
        } else if error === XPC_ERROR_TERMINATION_IMMINENT {
            self = .terminationImminent
        } else {
            let errorString = Self.errorString(error: error)

            self = .unknown(errorString)
        }
    }

    private static func errorString(error: xpc_object_t) -> String {
        if let rawString = xpc_dictionary_get_string(error, XPC_ERROR_KEY_DESCRIPTION) {
            return String(cString: rawString)
        } else {
            return "(unknown error)"
        }
    }
}
