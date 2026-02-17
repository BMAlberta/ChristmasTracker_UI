//
//  Date+Extensions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//

// Core/Extensions/Date+Extensions.swift

import Foundation

extension Date {
    /// Relative time display (e.g., "2 min ago", "1 hour ago")
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var fullDateTimeString: String {
        Self.dateTimeFormatter.string(from: self)
    }
}
