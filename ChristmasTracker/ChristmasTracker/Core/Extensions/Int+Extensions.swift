//
//  Int+Extensions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation

extension Int {
    /// Display year without thousands separator
    /// Example: 2026 → "2026" (not "2,026")
    var yearDisplay: String {
        self.formatted(.number.grouping(.never))
    }
}
