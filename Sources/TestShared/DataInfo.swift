//
//  DataInfo.swift
//
//
//  Created by Charles Srstka on 2/16/24.
//

import Foundation

public struct DataInfo: Codable {
    public struct DataError: LocalizedError, Codable {
        public let failureReason: String?
        public init(failureReason: String) { self.failureReason = failureReason }
    }

    public init(characterName: Data, playedBy: Data, otherCharacters: [Data]) {
        self.characterName = characterName
        self.playedBy = playedBy
        self.otherCharacters = otherCharacters
    }

    public let characterName: Data
    public let playedBy: Data
    public let otherCharacters: [Data]
}
