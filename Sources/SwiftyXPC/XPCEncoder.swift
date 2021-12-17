//
//  XPCDecoder.swift
//
//  Created by Charles Srstka on 11/2/21.
//

import XPC

private protocol XPCEncodingContainer {}
private extension XPCEncodingContainer {
    func encodeNil() -> xpc_object_t { xpc_null_create() }
    func encodeBool(_ flag: Bool) -> xpc_object_t { xpc_bool_create(flag) }
    func encodeInteger<I: SignedInteger>(_ i: I) -> xpc_object_t { xpc_int64_create(Int64(i)) }
    func encodeInteger<I: UnsignedInteger>(_ i: I) -> xpc_object_t { xpc_uint64_create(UInt64(i)) }
    func encodeFloat<F: BinaryFloatingPoint>(_ f: F) -> xpc_object_t { xpc_double_create(Double(f)) }
    func encodeString(_ string: String) -> xpc_object_t { xpc_string_create(string) }
}

public class XPCEncoder {
    internal enum Key: CodingKey {
        case arrayIndex(Int)
        case `super`

        var stringValue: String {
            switch self {
            case .arrayIndex(let int):
                return "Index: \(int)"
            case .super:
                return "super"
            }
        }

        var intValue: Int? {
            switch self {
            case .arrayIndex(let int):
                return int
            case .super:
                return nil
            }
        }

        init?(stringValue: String) { return nil }
        init(intValue: Int) { self = .arrayIndex(intValue) }
    }

    internal struct UnkeyedContainerDictionaryKeys {
        static let items = "Items"
        static let `super` = "Super"
    }

    private class KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol, XPCEncodingContainer {
        let dict: xpc_object_t
        var codingPath: [CodingKey] = []

        init(wrapping dict: xpc_object_t, codingPath: [CodingKey]) {
            precondition(xpc_get_type(dict) == XPC_TYPE_DICTIONARY, "Keyed container is not wrapping a dictionary")

            self.dict = dict
            self.codingPath = codingPath
        }

        private func encode(xpcValue: xpc_object_t, for key: Key) {
            key.stringValue.withCString {
                precondition(xpc_dictionary_get_value(self.dict, $0) == nil, "Value already keyed for \(key)")

                xpc_dictionary_set_value(self.dict, $0, xpcValue)
            }
        }

        func encodeNil(forKey key: Key) throws { self.encode(xpcValue: self.encodeNil(), for: key) }
        func encode(_ value: Bool, forKey key: Key) throws { self.encode(xpcValue: self.encodeBool(value), for: key) }
        func encode(_ value: String, forKey key: Key) throws { self.encode(xpcValue: self.encodeString(value), for: key) }
        func encode(_ value: Double, forKey key: Key) throws { self.encode(xpcValue: self.encodeFloat(value), for: key) }
        func encode(_ value: Float, forKey key: Key) throws { self.encode(xpcValue: self.encodeFloat(value), for: key) }
        func encode(_ value: Int, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: Int8, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: Int16, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: Int32, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: Int64, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: UInt, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: UInt8, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: UInt16, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: UInt32, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }
        func encode(_ value: UInt64, forKey key: Key) throws { self.encode(xpcValue: self.encodeInteger(value), for: key) }

        func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            let encoder = _XPCEncoder(parentXPC: self.dict, codingPath: self.codingPath + [key])

            try value.encode(to: encoder)
        }

        func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            let dict = xpc_dictionary_create_empty()
            self.encode(xpcValue: dict, for: key)

            return KeyedEncodingContainer(KeyedContainer<NestedKey>(wrapping: dict, codingPath: self.codingPath + [key]))
        }

        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let array = xpc_array_create_empty()
            self.encode(xpcValue: array, for: key)

            return UnkeyedContainer(wrapping: array, codingPath: self.codingPath + [key])
        }

        func superEncoder() -> Encoder {
            _XPCEncoder(parentXPC: self.dict, codingPath: self.codingPath + [XPCEncoder.Key.super])
        }

        func superEncoder(forKey key: Key) -> Encoder {
            _XPCEncoder(parentXPC: self.dict, codingPath: self.codingPath + [key])
        }
    }

    private class UnkeyedContainer: UnkeyedEncodingContainer, XPCEncodingContainer {
        let dict: xpc_object_t
        private let array: xpc_object_t

        let codingPath: [CodingKey]
        var count: Int { xpc_array_get_count(self.array) }

        init(wrapping array: xpc_object_t, codingPath: [CodingKey]) {
            precondition(xpc_get_type(array) == XPC_TYPE_ARRAY, "Unkeyed container is not wrapping array")

            let dict = xpc_dictionary_create_empty()
            xpc_dictionary_set_value(dict, UnkeyedContainerDictionaryKeys.items, array)

            self.dict = dict
            self.array = array
            self.codingPath = codingPath
        }

        func encodeNil() { xpc_array_append_value(self.array, self.encodeNil()) }
        func encode(_ value: Bool) throws { xpc_array_append_value(self.array, self.encodeBool(value)) }
        func encode(_ value: String) throws { xpc_array_append_value(self.array, self.encodeString(value)) }
        func encode(_ value: Double) throws { xpc_array_append_value(self.array, self.encodeFloat(value)) }
        func encode(_ value: Float) throws { xpc_array_append_value(self.array, self.encodeFloat(value)) }
        func encode(_ value: Int) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: Int8) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: Int16) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: Int32) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: Int64) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: UInt) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: UInt8) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: UInt16) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: UInt32) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }
        func encode(_ value: UInt64) throws { xpc_array_append_value(self.array, self.encodeInteger(value)) }

        func encode<T>(_ value: T) throws where T : Encodable {
            let encoder = _XPCEncoder(parentXPC: self.array, codingPath: self.nextCodingPath())

            self.encodeNil() // leave placeholder which will be overwritten later

            try value.encode(to: encoder)
        }

        func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            let dict = xpc_dictionary_create_empty()
            xpc_array_append_value(self.array, dict)

            return KeyedEncodingContainer(KeyedContainer(wrapping: dict, codingPath: self.nextCodingPath()))
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let array = xpc_array_create_empty()
            xpc_array_append_value(self.array, array)

            return UnkeyedContainer(wrapping: array, codingPath: self.nextCodingPath())
        }

        func superEncoder() -> Encoder {
            _XPCEncoder(parentXPC: self.dict, codingPath: self.codingPath + [XPCEncoder.Key.super])
        }

        private func nextCodingPath() -> [CodingKey] {
            self.codingPath + [XPCEncoder.Key.arrayIndex(self.count)]
        }
    }

    private class SingleValueContainer: SingleValueEncodingContainer, XPCEncodingContainer {
        let encoder: _XPCEncoder
        var hasBeenEncoded = false

        var codingPath: [CodingKey] { self.encoder.codingPath }

        init(encoder: _XPCEncoder) {
            self.encoder = encoder
        }

        private func encode(xpcValue: xpc_object_t) {
            precondition(!self.hasBeenEncoded, "Cannot encode to SingleValueContainer twice")
            defer { self.hasBeenEncoded = true }

            self.encoder.setEncodedValue(value: xpcValue)
        }

        func encodeNil() throws { self.encode(xpcValue: self.encodeNil()) }
        func encode(_ value: Bool) throws { self.encode(xpcValue: self.encodeBool(value)) }
        func encode(_ value: String) throws { self.encode(xpcValue: self.encodeString(value)) }
        func encode(_ value: Double) throws { self.encode(xpcValue: self.encodeFloat(value)) }
        func encode(_ value: Float) throws { self.encode(xpcValue: self.encodeFloat(value)) }
        func encode(_ value: Int) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: Int8) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: Int16) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: Int32) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: Int64) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: UInt) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: UInt8) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: UInt16) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: UInt32) throws { self.encode(xpcValue: self.encodeInteger(value)) }
        func encode(_ value: UInt64) throws { self.encode(xpcValue: self.encodeInteger(value)) }

        func encode<T>(_ value: T) throws where T : Encodable {
            let encoder = _XPCEncoder(parentXPC: nil, codingPath: self.codingPath)
            try value.encode(to: encoder)

            guard let encoded = encoder.encodedValue else {
                preconditionFailure("XPCEncoder did not set encoded value")
            }

            self.encode(xpcValue: encoded)
        }
    }

    private class _XPCEncoder: Encoder {
        let codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey : Any] { [:] }
        private(set) var encodedValue: xpc_object_t? = nil

        private let parentXPC: xpc_object_t?
        private var hasCreatedContainer = false

        init(parentXPC: xpc_object_t?, codingPath: [CodingKey]) {
            self.parentXPC = parentXPC
            self.codingPath = codingPath
        }

        func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
            precondition(!self.hasCreatedContainer, "Can only have one top-level container")
            defer { self.hasCreatedContainer = true }

            let dict = xpc_dictionary_create_empty()
            self.setEncodedValue(value: dict)

            return KeyedEncodingContainer(KeyedContainer<Key>(wrapping: dict, codingPath: self.codingPath))
        }

        func unkeyedContainer() -> UnkeyedEncodingContainer {
            precondition(!self.hasCreatedContainer, "Can only have one top-level container")
            defer { self.hasCreatedContainer = true }

            let array = xpc_array_create_empty()
            self.setEncodedValue(value: array)

            return UnkeyedContainer(wrapping: array, codingPath: self.codingPath)
        }

        func singleValueContainer() -> SingleValueEncodingContainer {
            precondition(!self.hasCreatedContainer, "Can only have one top-level container")
            defer { self.hasCreatedContainer = true }

            return SingleValueContainer(encoder: self)
        }

        func setEncodedValue(value: xpc_object_t) {
            self.encodedValue = value

            if let parentXPC = self.parentXPC {
                guard let key = self.codingPath.last else {
                    preconditionFailure("No coding key with parent XPC object")
                }

                if let specialKey = key as? XPCEncoder.Key {
                    switch specialKey {
                    case .arrayIndex(let index):
                        precondition(xpc_get_type(parentXPC) == XPC_TYPE_ARRAY, "Index passed to non-array")

                        xpc_array_set_value(parentXPC, index, value)
                    default:
                        preconditionFailure("Invalid key '\(specialKey.stringValue)'")
                    }
                } else {
                    precondition(xpc_get_type(parentXPC) == XPC_TYPE_DICTIONARY, "Key passed to non-dictionary")

                    key.stringValue.withCString { xpc_dictionary_set_value(parentXPC, $0, value) }
                }
            }
        }
    }

    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> xpc_object_t {
        let encoder = _XPCEncoder(parentXPC: nil, codingPath: [])

        try value.encode(to: encoder)

        guard let encoded = encoder.encodedValue else {
            preconditionFailure("XPCEncoder did not set encoded value")
        }

        return encoded
    }
}
