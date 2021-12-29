import XPC

/// An XPC-related communication error.
///
/// To avoid dependencies on Foundation, this does not formally adopt the `LocalizedError` protocol, but it does implement its methods,
/// so you can simply make this class conform to `LocalizedError` with an empty implementation to allow Foundation clients to easily get
/// user-facing error description strings:
///
///     extension XPCError: LocalizedError {}
///
/// However, this default implementation is not guaranteed to be correctly localized.
public enum XPCError: Error, Codable {
    /// Will be delivered to the connection’s error handler if the remote service exited.
    /// The connection is still live even in this case, and resending a message will cause the service to be launched on-demand.
    /// This error serves as a client’s indication that it should resynchronize any state that it had given the service.
    case connectionInterrupted
    /// An error that sends to the connection's error handler to indicate that the connection is no longer usable.
    case connectionInvalid
    /// An error that sends to a peer connection’s error handler when the XPC runtime determines that the program needs to exit
    /// and that all outstanding transactions must wind down.
    case terminationImminent
    /// A code signature requirement passed to a connection or listener was not able to be parsed.
    case invalidCodeSignatureRequirement
    /// An unknown error. The string parameter represents the description coming from the XPC system.
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

    /// A description of the error, intended to be a default implementation for the `LocalizedError` protocol.
    ///
    /// Is not guaranteed to be localized.
    public var errorDescription: String? { self.failureReason }

    /// A string describing the reason that the error occurred, intended to be a default implementation for the `LocalizedError` protocol.
    ///
    /// Is not guaranteed to be localized.
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
