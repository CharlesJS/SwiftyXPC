//
//  CommandSet.swift
//  Example XPC Service
//
//  Created by Charles Srstka on 5/5/22.
//

struct CommandSet {
    static let capitalizeString = "com.charlessoft.SwiftyXPC.Example-App.CapitalizeString"
    static let longRunningTask = "com.charlessoft.SwiftyXPC.Example-App.LongRunningTask"
}

struct LongRunningTaskMessage {
    static let progressNotification = "com.charlessoft.SwiftyXPC.Example-App.LongRunningTask.Progress"
}
