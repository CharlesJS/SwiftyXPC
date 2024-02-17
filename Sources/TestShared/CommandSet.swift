//
//  CommandSet.swift
//  Example XPC Service
//
//  Created by Charles Srstka on 5/5/22.
//

// swift-format-ignore: AllPublicDeclarationsHaveDocumentation
public struct CommandSet {
    public static let reportIDs = "com.charlessoft.SwiftyXPC.Tests.ReportIDs"
    public static let capitalizeString = "com.charlessoft.SwiftyXPC.Tests.CapitalizeString"
    public static let multiplyBy5 = "com.charlessoft.SwiftyXPC.Tests.MultiplyBy5"
    public static let transportData = "com.charlessoft.SwiftyXPC.Tests.TransportData"
    public static let tellAJoke = "com.charlessoft.SwiftyXPC.Tests.TellAJoke"
    public static let pauseOneSecond = "com.charlessoft.SwiftyXPC.Tests.PauseOneSecond"
}
