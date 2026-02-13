//
//  ConsoleLogDestination.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation
/// Log destination for debug console (debug builds only)
struct ConsoleDestination: LogDestination {
    func log(_ event: LogEvent) async {
#if DEBUG
        let timestamp = formatTimestamp(event.timestamp)
        let level = event.level.rawValue.uppercased()
        let category = event.category.rawValue
        
        print("[\(timestamp)] [\(level)] [\(category)] \(event.message)")
        
        if !event.metadata.isEmpty {
            print(" Metadata: \(event.metadata)")
        }
#endif
    }
    
    func flush(_ events: [LogEvent]) async {
        for event in events {
            await log(event)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
