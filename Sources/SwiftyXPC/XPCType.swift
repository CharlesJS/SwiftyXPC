//
//  XPCType.swift
//
//
//  Created by Charles Srstka on 12/20/21.
//

import XPC

public enum XPCType: Codable {
    case activity
    case array
    case bool
    case connection
    case data
    case date
    case dictionary
    case double
    case endpoint
    case error
    case fileDescriptor
    case null
    case sharedMemory
    case string
    case signedInteger
    case unsignedInteger
    case uuid
    case unknown(String)

    init(rawType: xpc_type_t) {
        switch rawType {
        case XPC_TYPE_ACTIVITY:
            self = .activity
        case XPC_TYPE_ARRAY:
            self = .array
        case XPC_TYPE_BOOL:
            self = .bool
        case XPC_TYPE_CONNECTION:
            self = .connection
        case XPC_TYPE_DATA:
            self = .data
        case XPC_TYPE_DATE:
            self = .date
        case XPC_TYPE_DICTIONARY:
            self = .dictionary
        case XPC_TYPE_DOUBLE:
            self = .double
        case XPC_TYPE_ENDPOINT:
            self = .endpoint
        case XPC_TYPE_ERROR:
            self = .error
        case XPC_TYPE_FD:
            self = .fileDescriptor
        case XPC_TYPE_NULL:
            self = .null
        case XPC_TYPE_STRING:
            self = .string
        case XPC_TYPE_INT64:
            self = .signedInteger
        case XPC_TYPE_UINT64:
            self = .unsignedInteger
        case XPC_TYPE_UUID:
            self = .uuid
        default:
            self = .unknown(String(cString: xpc_type_get_name(rawType)))
        }
    }

    public var name: String {
        switch self {
        case .activity:
            return String(cString: xpc_type_get_name(XPC_TYPE_ACTIVITY))
        case .array:
            return String(cString: xpc_type_get_name(XPC_TYPE_ARRAY))
        case .bool:
            return String(cString: xpc_type_get_name(XPC_TYPE_BOOL))
        case .connection:
            return String(cString: xpc_type_get_name(XPC_TYPE_CONNECTION))
        case .data:
            return String(cString: xpc_type_get_name(XPC_TYPE_DATA))
        case .date:
            return String(cString: xpc_type_get_name(XPC_TYPE_DATE))
        case .dictionary:
            return String(cString: xpc_type_get_name(XPC_TYPE_DICTIONARY))
        case .double:
            return String(cString: xpc_type_get_name(XPC_TYPE_DOUBLE))
        case .endpoint:
            return String(cString: xpc_type_get_name(XPC_TYPE_ENDPOINT))
        case .error:
            return String(cString: xpc_type_get_name(XPC_TYPE_ERROR))
        case .fileDescriptor:
            return String(cString: xpc_type_get_name(XPC_TYPE_FD))
        case .null:
            return String(cString: xpc_type_get_name(XPC_TYPE_NULL))
        case .sharedMemory:
            return String(cString: xpc_type_get_name(XPC_TYPE_SHMEM))
        case .string:
            return String(cString: xpc_type_get_name(XPC_TYPE_STRING))
        case .signedInteger:
            return String(cString: xpc_type_get_name(XPC_TYPE_INT64))
        case .unsignedInteger:
            return String(cString: xpc_type_get_name(XPC_TYPE_UINT64))
        case .uuid:
            return String(cString: xpc_type_get_name(XPC_TYPE_UUID))
        case .unknown(let name):
            return name
        }
    }
}

extension xpc_object_t {
    var type: XPCType { XPCType(rawType: xpc_get_type(self)) }
}
