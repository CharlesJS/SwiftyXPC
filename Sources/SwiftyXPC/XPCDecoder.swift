//
//  XPCEncoder.swift
//
//  Created by Charles Srstka on 11/2/21.
//

import System
import XPC

private protocol XPCDecodingContainer {
    var codingPath: [CodingKey] { get }
}
private extension XPCDecodingContainer {
    func makeErrorContext(description: String, underlyingError: Error? = nil) -> DecodingError.Context {
        DecodingError.Context(codingPath: self.codingPath, debugDescription: description, underlyingError: underlyingError)
    }

    func checkType(xpcType: xpc_type_t, swiftType: Any.Type, xpc: xpc_object_t) throws {
        if xpc_get_type(xpc) != xpcType {
            let expectedTypeName = String(cString: xpc_type_get_name(xpcType))
            let actualTypeName = String(cString: xpc_type_get_name(xpc_get_type(xpc)))

            let context = self.makeErrorContext(
                description: "Incorrect XPC type; want \(expectedTypeName), got \(actualTypeName)"
            )

            throw DecodingError.typeMismatch(swiftType, context)
        }
    }

    func decodeNil(xpc: xpc_object_t) throws {
        try self.checkType(xpcType: XPC_TYPE_NULL, swiftType: Any?.self, xpc: xpc)
    }

    func decodeBool(xpc: xpc_object_t) throws -> Bool {
        try self.checkType(xpcType: XPC_TYPE_BOOL, swiftType: Bool.self, xpc: xpc)

        return xpc_bool_get_value(xpc)
    }

    func decodeInteger<I: FixedWidthInteger & SignedInteger>(xpc: xpc_object_t) throws -> I {
        try self.checkType(xpcType: XPC_TYPE_INT64, swiftType: I.self, xpc: xpc)
        let int = xpc_int64_get_value(xpc)

        if let i = I(exactly: int) {
            return i
        } else {
            let context = self.makeErrorContext(description: "Integer overflow; \(int) out of bounds")
            throw DecodingError.dataCorrupted(context)
        }
    }

    func decodeInteger<I: FixedWidthInteger & UnsignedInteger>(xpc: xpc_object_t) throws -> I {
        try self.checkType(xpcType: XPC_TYPE_UINT64, swiftType: I.self, xpc: xpc)
        let int = xpc_uint64_get_value(xpc)

        if let i = I(exactly: int) {
            return i
        } else {
            let context = self.makeErrorContext(description: "Integer overflow; \(int) out of bounds")
            throw DecodingError.dataCorrupted(context)
        }
    }

    func decodeFloatingPoint<F: BinaryFloatingPoint>(xpc: xpc_object_t) throws -> F {
        try self.checkType(xpcType: XPC_TYPE_DOUBLE, swiftType: F.self, xpc: xpc)

        return F(xpc_double_get_value(xpc))
    }

    func decodeString(xpc: xpc_object_t) throws -> String {
        try self.checkType(xpcType: XPC_TYPE_STRING, swiftType: String.self, xpc: xpc)

        let length = xpc_string_get_length(xpc)
        let pointer = xpc_string_get_string_ptr(xpc)

        return withExtendedLifetime(xpc) {
            UnsafeBufferPointer(start: pointer, count: length).withMemoryRebound(to: UInt8.self) {
                String(decoding: $0, as: UTF8.self)
            }
        }
    }
}

public final class XPCDecoder {
    private final class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol, XPCDecodingContainer {
        let dict: xpc_object_t
        let codingPath: [CodingKey]

        private var checkedType = false

        var allKeys: [Key] {
            var keys: [Key] = []

            xpc_dictionary_apply(self.dict) { cKey, _ in
                let stringKey = String(cString: cKey)
                guard let key = Key(stringValue: stringKey) else {
                    preconditionFailure("Couldn't convert string '\(stringKey)' into key")
                }

                keys.append(key)
                return true
            }

            return keys
        }

        init(wrapping dict: xpc_object_t, codingPath: [CodingKey]) {
            self.dict = dict
            self.codingPath = codingPath
        }

        func contains(_ key: Key) -> Bool { (try? self.getValue(for: key)) != nil }

        private func getValue(for key: CodingKey, allowNull: Bool = false) throws -> xpc_object_t {
            guard let value = try self.getOptionalValue(for: key, allowNull: allowNull) else {
                let context = self.makeErrorContext(description: "No value for key '\(key.stringValue)'")
                throw DecodingError.valueNotFound(Any.self, context)
            }

            return value
        }

        private func getOptionalValue(for key: CodingKey, allowNull: Bool = false) throws -> xpc_object_t? {
            try key.stringValue.withCString {
                if !self.checkedType {
                    guard xpc_get_type(dict) == XPC_TYPE_DICTIONARY else {
                        let type = String(cString: xpc_type_get_name(xpc_get_type(dict)))
                        let desc = "Unexpected type for KeyedContainer wrapped object: expected dictionary, got \(type)"
                        let context = self.makeErrorContext( description: desc)

                        throw DecodingError.typeMismatch([String : Any].self, context)
                    }

                    self.checkedType = true
                }

                let value = xpc_dictionary_get_value(self.dict, $0)

                if !allowNull, let value = value, case .null = value.type {
                    return nil
                }

                return value
            }
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            xpc_get_type(try self.getValue(for: key, allowNull: true)) == XPC_TYPE_NULL
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            try self.decodeBool(xpc: self.getValue(for: key))
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try self.decodeString(xpc: self.getValue(for: key))
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try self.decodeFloatingPoint(xpc: self.getValue(for: key))
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            try self.decodeFloatingPoint(xpc: self.getValue(for: key))
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
            try self.getOptionalValue(for: key).map { try self.decodeBool(xpc: $0) }
        }

        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            try self.getOptionalValue(for: key).map { try self.decodeString(xpc: $0) }
        }

        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            try self.getOptionalValue(for: key).map { try self.decodeFloatingPoint(xpc: $0) }
        }

        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            try self.getOptionalValue(for: key).map { try self.decodeFloatingPoint(xpc: $0) }
        }

        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
            try self.getOptionalValue(for: key).map { try self.decodeInteger(xpc: $0) }
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            let xpc = try self.getValue(for: key, allowNull: true)
            let codingPath = self.codingPath + [key]

            if type == XPCFileDescriptor.self {
                try checkType(xpcType: XPC_TYPE_FD, swiftType: XPCFileDescriptor.self, xpc: xpc)

                return XPCFileDescriptor(fileDescriptor: xpc_fd_dup(xpc)) as! T
            } else if #available(macOS 11.0, *), type == FileDescriptor.self {
                try checkType(xpcType: XPC_TYPE_FD, swiftType: XPCFileDescriptor.self, xpc: xpc)

                return FileDescriptor(rawValue: xpc_fd_dup(xpc)) as! T
            } else if type == XPCNull.self {
                try checkType(xpcType: XPC_TYPE_NULL, swiftType: XPCNull.self, xpc: xpc)

                return XPCNull.shared as! T
            } else {
                return try type.init(from: _XPCDecoder(xpc: xpc, codingPath: codingPath))
            }
        }

        func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try self.getValue(for: key)
            let codingPath = self.codingPath + [key]

            return KeyedDecodingContainer(KeyedContainer<NestedKey>(wrapping: value, codingPath: codingPath))
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            let value = try self.getValue(for: key)
            let codingPath = self.codingPath + [key]

            return UnkeyedContainer(wrapping: value, codingPath: codingPath)
        }

        func superDecoder() throws -> Decoder {
            let xpc = try self.getValue(for: XPCEncoder.Key.super)

            return _XPCDecoder(xpc: xpc, codingPath: self.codingPath + [XPCEncoder.Key.super])
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            let xpc = try self.getValue(for: XPCEncoder.Key.super)

            return _XPCDecoder(xpc: xpc, codingPath: self.codingPath + [key])
        }
    }

    private final class UnkeyedContainer: UnkeyedDecodingContainer, XPCDecodingContainer {
        private enum Storage {
            case array(xpc_object_t)
            case data([UInt8])
            case error(Error)
        }

        let dict: xpc_object_t
        private let storage: Storage

        let codingPath: [CodingKey]
        var count: Int? {
            switch self.storage {
            case .array(let array):
                return xpc_array_get_count(array)
            case .data(let data):
                return data.count
            case .error:
                return nil
            }
        }

        var isAtEnd: Bool { self.currentIndex >= (self.count ?? 0) }
        private(set) var currentIndex: Int

        init(wrapping dict: xpc_object_t, codingPath: [CodingKey]) {
            self.dict = dict
            self.codingPath = codingPath
            self.currentIndex = 0

            do {
                guard xpc_get_type(dict) == XPC_TYPE_DICTIONARY else {
                    let type = String(cString: xpc_type_get_name(xpc_get_type(dict)))
                    let description = "Expected dictionary, got \(type))"
                    let context = DecodingError.Context(codingPath: codingPath, debugDescription: description)

                    throw DecodingError.typeMismatch([String : Any].self, context)
                }

                guard let xpc = xpc_dictionary_get_value(dict, XPCEncoder.UnkeyedContainerDictionaryKeys.contents) else {
                    let description = "Missing contents for unkeyed container"
                    let context = DecodingError.Context(codingPath: codingPath, debugDescription: description)

                    throw DecodingError.dataCorrupted(context)
                }

                switch xpc_get_type(xpc) {
                case XPC_TYPE_ARRAY:
                    self.storage = .array(xpc)
                case XPC_TYPE_DATA:
                    let length = xpc_data_get_length(xpc)
                    var bytes = [UInt8].init(repeating: 0, count: length)

                    try bytes.withUnsafeMutableBytes {
                        let bytesCopied = xpc_data_get_bytes(xpc, $0.baseAddress!, 0, length)

                        if bytesCopied != length {
                            let description = "Couldn't read data for unknown reason"
                            let context = DecodingError.Context(codingPath: codingPath, debugDescription: description)

                            throw DecodingError.dataCorrupted(context)
                        }
                    }

                    self.storage = .data(bytes)
                default:
                    let type = String(cString: xpc_type_get_name(xpc_get_type(xpc)))
                    let description = "Invalid XPC type for unkeyed container: \(type)"
                    let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: description)

                    throw DecodingError.typeMismatch(Any.self, context)
                }
            } catch {
                self.storage = .error(error)
            }
        }

        private func readNext(xpcType: xpc_type_t?, swiftType: Any.Type) throws -> xpc_object_t {
            if self.isAtEnd {
                let context = self.makeErrorContext(description: "Premature end of array data")
                throw DecodingError.dataCorrupted(context)
            }

            switch self.storage {
            case .array(let array):
                defer { self.currentIndex += 1 }

                let value = xpc_array_get_value(array, self.currentIndex)

                if let xpcType = xpcType {
                    try self.checkType(xpcType: xpcType, swiftType: swiftType, xpc: value)
                }

                return value
            case .data:
                throw DecodingError.dataCorruptedError(
                    in: self,
                    debugDescription: "Tried to read non-byte value from data"
                )
            case .error(let error):
                throw error
            }
        }

        private func decodeFloatingPoint<F: BinaryFloatingPoint>() throws -> F {
            try self.decodeFloatingPoint(xpc: self.readNext(xpcType: XPC_TYPE_DOUBLE, swiftType: F.self))
        }

        private func decodeInteger<I: FixedWidthInteger & SignedInteger>() throws -> I {
            try self.decodeInteger(xpc: self.readNext(xpcType: nil, swiftType: I.self))
        }

        private func decodeInteger<I: FixedWidthInteger & UnsignedInteger>() throws -> I {
            try self.decodeInteger(xpc: self.readNext(xpcType: nil, swiftType: I.self))
        }

        private func decodeByte() throws -> UInt8 {
            if case .data(let bytes) = self.storage {
                if self.currentIndex > bytes.count {
                    let context = self.makeErrorContext(description: "Read past end of data buffer")
                    throw DecodingError.dataCorrupted(context)
                }

                defer { self.currentIndex += 1 }

                return bytes[self.currentIndex]
            } else {
                return try self.decodeInteger()
            }
        }

        private func decodeByte() throws -> Int8 {
            return Int8(bitPattern: try self.decodeByte())
        }

        func decodeNil() throws -> Bool {
            _ = try self.readNext(xpcType: XPC_TYPE_NULL, swiftType: Any.self)
            return true
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            try self.decodeBool(xpc: self.readNext(xpcType: XPC_TYPE_BOOL, swiftType: type))
        }

        func decode(_ type: String.Type) throws -> String {
            try self.decodeString(xpc: try self.readNext(xpcType: XPC_TYPE_STRING, swiftType: type))
        }

        func decode(_ type: Double.Type) throws -> Double { try self.decodeFloatingPoint() }
        func decode(_ type: Float.Type) throws -> Float { try self.decodeFloatingPoint() }
        func decode(_ type: Int.Type) throws -> Int { try self.decodeInteger() }
        func decode(_ type: Int8.Type) throws -> Int8 { try self.decodeByte() }
        func decode(_ type: Int16.Type) throws -> Int16 { try self.decodeInteger() }
        func decode(_ type: Int32.Type) throws -> Int32 { try self.decodeInteger() }
        func decode(_ type: Int64.Type) throws -> Int64 { try self.decodeInteger() }
        func decode(_ type: UInt.Type) throws -> UInt { try self.decodeInteger() }
        func decode(_ type: UInt8.Type) throws -> UInt8 { try self.decodeByte() }
        func decode(_ type: UInt16.Type) throws -> UInt16 { try self.decodeInteger() }
        func decode(_ type: UInt32.Type) throws -> UInt32 { try self.decodeInteger() }
        func decode(_ type: UInt64.Type) throws -> UInt64 { try self.decodeInteger() }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            if type == Bool.self {
                return try self.decode(Bool.self) as! T
            } else if type == String.self {
                return try self.decode(String.self) as! T
            } else if type == Double.self {
                return try self.decode(Double.self) as! T
            } else if type == Float.self {
                return try self.decode(Float.self) as! T
            } else if type == Int.self {
                return try self.decode(Int.self) as! T
            } else if type == Int8.self {
                return try self.decode(Int8.self) as! T
            } else if type == Int16.self {
                return try self.decode(Int16.self) as! T
            } else if type == Int32.self {
                return try self.decode(Int32.self) as! T
            } else if type == Int64.self {
                return try self.decode(Int64.self) as! T
            } else if type == UInt.self {
                return try self.decode(UInt.self) as! T
            } else if type == UInt8.self {
                return try self.decode(UInt8.self) as! T
            } else if type == UInt16.self {
                return try self.decode(UInt16.self) as! T
            } else if type == UInt32.self {
                return try self.decode(UInt32.self) as! T
            } else if type == UInt64.self {
                return try self.decode(UInt64.self) as! T
            } else if type == XPCFileDescriptor.self {
                let xpc = try self.readNext(xpcType: XPC_TYPE_FD, swiftType: type)

                return XPCFileDescriptor(fileDescriptor: xpc_fd_dup(xpc)) as! T
            } else if #available(macOS 11.0, *), type == FileDescriptor.self {
                let xpc = try self.readNext(xpcType: XPC_TYPE_FD, swiftType: type)

                return FileDescriptor(rawValue: xpc_fd_dup(xpc)) as! T
            } else if type == XPCNull.self {
                _ = try self.readNext(xpcType: XPC_TYPE_NULL, swiftType: XPCNull.self)

                return XPCNull.shared as! T
            } else {
                let codingPath = self.nextCodingPath()
                let xpc = try self.readNext(xpcType: nil, swiftType: type)

                return try type.init(from: _XPCDecoder(xpc: xpc, codingPath: codingPath))
            }
        }

        func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> {
            let codingPath = self.nextCodingPath()
            let xpc = try self.readNext(xpcType: nil, swiftType: Any.self)

            return KeyedDecodingContainer(KeyedContainer(wrapping: xpc, codingPath: codingPath))
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let codingPath = self.nextCodingPath()
            let xpc = try self.readNext(xpcType: nil, swiftType: Any.self)

            return UnkeyedContainer(wrapping: xpc, codingPath: codingPath)
        }

        func superDecoder() throws -> Decoder {
            let key = XPCEncoder.Key.super

            guard let xpc = xpc_dictionary_get_value(self.dict, key.stringValue) else {
                let context = self.makeErrorContext(description: "No encoded value for super")
                throw DecodingError.valueNotFound(Any.self, context)
            }

            return _XPCDecoder(xpc: xpc, codingPath: self.codingPath + [key])
        }

        private func nextCodingPath() -> [CodingKey] {
            self.codingPath + [XPCEncoder.Key.arrayIndex(self.currentIndex)]
        }
    }

    private final class SingleValueContainer: SingleValueDecodingContainer, XPCDecodingContainer {
        let codingPath: [CodingKey]
        let xpc: xpc_object_t

        init(wrapping xpc: xpc_object_t, codingPath: [CodingKey]) {
            self.codingPath = codingPath
            self.xpc = xpc
        }

        func decodeNil() -> Bool {
            do {
                try self.decodeNil(xpc: self.xpc)
                return true
            } catch {
                return false
            }
        }

        func decode(_ type: Bool.Type) throws -> Bool { try self.decodeBool(xpc: self.xpc) }
        func decode(_ type: String.Type) throws -> String { try self.decodeString(xpc: self.xpc) }
        func decode(_ type: Double.Type) throws -> Double { try self.decodeFloatingPoint(xpc: self.xpc) }
        func decode(_ type: Float.Type) throws -> Float { try self.decodeFloatingPoint(xpc: self.xpc) }
        func decode(_ type: Int.Type) throws -> Int { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: Int8.Type) throws -> Int8 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: Int16.Type) throws -> Int16 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: Int32.Type) throws -> Int32 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: Int64.Type) throws -> Int64 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: UInt.Type) throws -> UInt { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: UInt8.Type) throws -> UInt8 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: UInt16.Type) throws -> UInt16 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: UInt32.Type) throws -> UInt32 { try self.decodeInteger(xpc: self.xpc) }
        func decode(_ type: UInt64.Type) throws -> UInt64 { try self.decodeInteger(xpc: self.xpc) }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            if type == XPCFileDescriptor.self {
                try checkType(xpcType: XPC_TYPE_FD, swiftType: XPCFileDescriptor.self, xpc: self.xpc)

                return XPCFileDescriptor(fileDescriptor: xpc_fd_dup(self.xpc)) as! T
            } else if #available(macOS 11.0, *), type == FileDescriptor.self {
                try checkType(xpcType: XPC_TYPE_FD, swiftType: XPCFileDescriptor.self, xpc: self.xpc)

                return FileDescriptor(rawValue: xpc_fd_dup(self.xpc)) as! T
            } else if type == XPCNull.self {
                try checkType(xpcType: XPC_TYPE_NULL, swiftType: XPCNull.self, xpc: self.xpc)

                return XPCNull.shared as! T
            } else {
                return try T.init(from: _XPCDecoder(xpc: self.xpc, codingPath: self.codingPath))
            }
        }
    }

    private final class _XPCDecoder: Decoder {
        let xpc: xpc_object_t
        let codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey : Any] { [:] }
        private var hasCreatedContainer = false

        init(xpc: xpc_object_t, codingPath: [CodingKey]) {
            self.xpc = xpc
            self.codingPath = codingPath
        }

        func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> {
            precondition(!self.hasCreatedContainer, "Can only have one top-level container")
            defer { self.hasCreatedContainer = true }

            return KeyedDecodingContainer(KeyedContainer<Key>(wrapping: self.xpc, codingPath: self.codingPath))
        }

        func unkeyedContainer() -> UnkeyedDecodingContainer {
            precondition(!self.hasCreatedContainer, "Can only have one top-level container")
            defer { self.hasCreatedContainer = true }

            return UnkeyedContainer(wrapping: self.xpc, codingPath: self.codingPath)
        }

        func singleValueContainer() -> SingleValueDecodingContainer {
            precondition(!self.hasCreatedContainer, "Can only have one top-level container")
            defer { self.hasCreatedContainer = true }

            return SingleValueContainer(wrapping: self.xpc, codingPath: self.codingPath)
        }
    }

    public init() {}

    public func decode<T: Decodable>(type: T.Type, from xpcObject: xpc_object_t) throws -> T {
        let decoder = _XPCDecoder(xpc: xpcObject, codingPath: [])
        let container = decoder.singleValueContainer()

        return try container.decode(type)
    }
}
