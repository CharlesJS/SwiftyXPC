import XPC

public enum XPCError: Error, Codable {
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

    public var errorDescription: String? { self.failureReason }

    public var failureReason: String? {
        switch self {
        case .connectionInterrupted:
            return Self.errorString(error: XPC_ERROR_CONNECTION_INTERRUPTED)
        case .connectionInvalid:
            return Self.errorString(error: XPC_ERROR_CONNECTION_INVALID)
        case .terminationImminent:
            return Self.errorString(error: XPC_ERROR_TERMINATION_IMMINENT)
        case .invalidCodeSignatureRequirement:
            return "Invalid Code Signature Requirement"
        case .unknown(let failureReason):
            return failureReason
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
