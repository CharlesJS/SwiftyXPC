//
//  File.swift
//
//
//  Created by Charles Srstka on 12/27/21.
//

/// A class representing a null value in XPC.
public struct XPCNull: Codable {
    /// The shared `XPCNull` instance.
    public static let shared = Self()
}
