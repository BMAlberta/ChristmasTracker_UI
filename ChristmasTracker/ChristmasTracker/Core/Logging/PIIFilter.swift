//
//  PIIFilter.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation

/// Filters personally identifiable information from logs
struct PIIFilter {
    // MARK: - Regex Patterns
    nonisolated private static let patterns: [NSRegularExpression] = [
        // Email addresses
        try! NSRegularExpression(
            pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        ),
        // Bearer tokens
        try! NSRegularExpression(
            pattern: #"\bBearer\s+[A-Za-z0-9\-._~+/]+=*"#
        ),
        // SSN (xxx-xx-xxxx)
        try! NSRegularExpression(
            pattern: #"\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b"#
        ),
        // Credit cards (16 digits)
        try! NSRegularExpression(
            pattern: #"\b[0-9]{16}\b"#
        ),
        // UUIDs
        try! NSRegularExpression(
            pattern: #"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#,
            options: .caseInsensitive
        )
    ]
    // MARK: - Public Methods
    /// Redact PII from text
    nonisolated static func redact(_ text: String) -> String {
        var redacted = text
        for pattern in Self.patterns {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = pattern.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: "[REDACTED]"
            )
        }
        return redacted
    }
}
