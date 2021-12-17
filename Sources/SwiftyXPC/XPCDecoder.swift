//
//  XPCEncoder.swift
//
//  Created by Charles Srstka on 11/2/21.
//

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

        defer { _ = xpc.self } // guard against xpc getting prematurely reaped by ARC

        return UnsafeBufferPointer(start: pointer, count: length).withMemoryRebound(to: UInt8.self) {
            String(decoding: $0, as: UTF8.self)
        }
    }
}

public class XPCDecoder {
    private class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol, XPCDecodingContainer {
        let dict: xpc_object_t
        let codingPath: [CodingKey]

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
            precondition(xpc_get_type(dict) == XPC_TYPE_DICTIONARY, "KeyedContainer is not wrapping a dictionary")

            self.dict = dict
            self.codingPath = codingPath
        }

        func contains(_ key: Key) -> Bool { (try? self.getValue(for: key)) != nil }

        private func getValue(for key: CodingKey) throws -> xpc_object_t {
            try key.stringValue.withCString {
                guard let value = xpc_dictionary_get_value(self.dict, $0) else {
                    let context = self.makeErrorContext(description: "No value for key '\(key.stringValue)'")
                    throw DecodingError.valueNotFound(Any.self, context)
                }

                return value
            }
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            xpc_get_type(try self.getValue(for: key)) == XPC_TYPE_NULL
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
            try self.decodeBool(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            try self.decodeString(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            try self.decodeFloatingPoint(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            try self.decodeFloatingPoint(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
            try self.decodeInteger(xpc: self.getValue(for: key))
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            let xpc = try self.getValue(for: key)
            let codingPath = self.codingPath + [key]

            return try type.init(from: _XPCDecoder(xpc: xpc, codingPath: codingPath))
        }

        func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
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

    private class UnkeyedContainer: UnkeyedDecodingContainer, XPCDecodingContainer {
        let dict: xpc_object_t
        let array: xpc_object_t

        let codingPath: [CodingKey]
        var count: Int? { xpc_array_get_count(self.array) }
        var isAtEnd: Bool { self.currentIndex >= xpc_array_get_count(self.array) }
        private(set) var currentIndex: Int

        init(wrapping array: xpc_object_t, codingPath: [CodingKey]) {
            precondition(xpc_get_type(array) == XPC_TYPE_ARRAY, "UnkeyedContainer is not wrapping an array")

            let dict = xpc_dictionary_create_empty()
            xpc_dictionary_set_value(dict, XPCEncoder.UnkeyedContainerDictionaryKeys.items, array)

            self.dict = dict
            self.array = array
            self.codingPath = codingPath
            self.currentIndex = 0
        }

        private func readNext(xpcType: xpc_type_t?, swiftType: Any.Type) throws -> xpc_object_t {
            if self.isAtEnd {
                let context = self.makeErrorContext(description: "Premature end of array data")
                throw DecodingError.dataCorrupted(context)
            }

            defer { self.currentIndex += 1 }
            let value = xpc_array_get_value(self.array, self.currentIndex)

            if let xpcType = xpcType {
                try self.checkType(xpcType: xpcType, swiftType: swiftType, xpc: value)
            }

            return value
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
        func decode(_ type: Int8.Type) throws -> Int8 { try self.decodeInteger() }
        func decode(_ type: Int16.Type) throws -> Int16 { try self.decodeInteger() }
        func decode(_ type: Int32.Type) throws -> Int32 { try self.decodeInteger() }
        func decode(_ type: Int64.Type) throws -> Int64 { try self.decodeInteger() }
        func decode(_ type: UInt.Type) throws -> UInt { try self.decodeInteger() }
        func decode(_ type: UInt8.Type) throws -> UInt8 { try self.decodeInteger() }
        func decode(_ type: UInt16.Type) throws -> UInt16 { try self.decodeInteger() }
        func decode(_ type: UInt32.Type) throws -> UInt32 { try self.decodeInteger() }
        func decode(_ type: UInt64.Type) throws -> UInt64 { try self.decodeInteger() }

        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            let codingPath = self.nextCodingPath()
            let xpc = try self.readNext(xpcType: nil, swiftType: type)

            return try type.init(from: _XPCDecoder(xpc: xpc, codingPath: codingPath))
        }

        func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
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

    private class SingleValueContainer: SingleValueDecodingContainer, XPCDecodingContainer {
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

        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            try T.init(from: _XPCDecoder(xpc: self.xpc, codingPath: self.codingPath))
        }
    }

    private class _XPCDecoder: Decoder {
        let xpc: xpc_object_t
        let codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey : Any] { [:] }
        private var hasCreatedContainer = false

        init(xpc: xpc_object_t, codingPath: [CodingKey]) {
            self.xpc = xpc
            self.codingPath = codingPath
        }

        func container<Key>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> where Key : CodingKey {
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

        return try type.init(from: decoder)
    }
}