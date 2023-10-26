//
//  JokeMessage.swift
//
//  Created by Charles Srstka on 10/13/23.
//

// swift-format-ignore: AllPublicDeclarationsHaveDocumentation
public struct JokeMessage {
    public struct NotAKnockKnockJoke: Error, Codable {
        public let complaint: String
        public init(complaint: String) {
            self.complaint = complaint
        }
    }

    public static let askForJoke = "ask-for-joke"
    public static let whosThere = "who's-there"
    public static let who = "who"
    public static let groan = "groan"
}
