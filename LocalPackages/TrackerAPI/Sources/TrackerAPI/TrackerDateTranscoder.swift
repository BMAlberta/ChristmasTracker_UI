import Foundation
import OpenAPIRuntime

/// ISO 8601 date transcoder that accepts dates both with and without
/// fractional seconds (server timestamps include .000Z; some fields omit them),
/// and always encodes without fractional seconds.
public struct TrackerDateTranscoder: DateTranscoder {
    public init() {}

    public func decode(_ dateString: String) throws -> Date {
        // Try with fractional seconds first (most common from server)
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }
        // Fall back to without fractional seconds
        let formatterWithout = ISO8601DateFormatter()
        formatterWithout.formatOptions = [.withInternetDateTime]
        if let date = formatterWithout.date(from: dateString) {
            return date
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Invalid ISO 8601 date string: \(dateString)")
        )
    }

    public func encode(_ date: Date) throws -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
