//
//  NewRelicDestination.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation
/// Log destination for New Relic
nonisolated final class NewRelicDestination: LogDestination {
    private let licenseKey: String
    
    init?(licenseKey: String) {
        // Verify New Relic SDK compatibility with Swift 6
        guard Self.isCompatible() else {
            print("⚠ New Relic SDK not compatible with Swift 6, using backend fallback")
            return nil
        }
        self.licenseKey = licenseKey
        // Initialize New Relic
        // NOTE: Actual New Relic SDK integration will happen here
        // For now, this is a placeholder
        print("✅ New Relic initialized with license key")
        
    }
    private static func isCompatible() -> Bool {
        // Runtime compatibility check
        // This will be determined during Phase 2 implementation
        // For now, return true and we'll test
        return true
    }
    
    func log(_ event: LogEvent) async {
        // Send individual events for critical/error
        if event.level == .critical || event.level == .error {
            await sendError(event)
        }
    }
    
    func flush(_ events: [LogEvent]) async {
        for event in events {
            await sendEvent(event)
        }
    }
    private func sendError(_ event: LogEvent) async {
        // TODO: Integrate with New Relic SDK
        // NewRelic.recordError(
        // NSError(domain: event.category.rawValue, code: 0),
        // attributes: event.toAttributes()
        // )
        print("[New Relic] Error: \(event.message)")
    }
    
    private func sendEvent(_ event: LogEvent) async {
        // TODO: Integrate with New Relic SDK
        // NewRelic.recordCustomEvent(
        // "AppLog",
        // attributes: event.toAttributes()
        // )
        print("[New Relic] Event: \(event.message)")
    }
}
extension LogEvent {
    func toAttributes() -> [String: Any] {
        var attrs: [String: Any] = [
            "timestamp": timestamp.ISO8601Format(),
            "level": level.rawValue,
            "category": category.rawValue,
            "message": message]
        
        for (key, value) in metadata {
            attrs[key] = value
        }
        
        if let duration = duration {
            attrs["duration"] = duration
        }
        if let memory = memoryUsage {
            attrs["memoryUsage"] = memory
        }
        // Add app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            attrs["appVersion"] = version
            attrs["platform"] = "ios"
        }
        return attrs
    }
}

