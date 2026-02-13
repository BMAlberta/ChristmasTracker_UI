//
//  LogEvent.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation

/// Log event model
struct LogEvent: Sendable, Codable {
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let metadata: [String: String]
    let signpost: SignpostInfo?
    let duration: TimeInterval?
    let memoryUsage: UInt64?
    
    nonisolated init(timestamp: Date,
         level: LogLevel,
         category: LogCategory,
         message: String,
         metadata: [String : String],
         signpost: SignpostInfo?,
         duration: TimeInterval?,
         memoryUsage: UInt64?)
    {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.signpost = signpost
        self.duration = duration
        self.memoryUsage = memoryUsage
    }
}
