//
//  Logger.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation
import os

actor Logger {
    static let shared = Logger()
    // MARK: - Properties
    private var destinations: [LogDestination] = []
    private var buffer: [LogEvent] = []
    private var autoFlushTask: Task<Void, Never>?
    // MARK: - Initialization
    init() {
        // Note: We'll set up destinations and auto-flush asynchronously
        // This allows the Logger to be created synchronously
        Task {
            await setupDestinations()
            await startAutoFlush()
        }
    }
    
    private func setupDestinations() async {
        // Always add OSLog (native iOS)
        destinations.append(OSLogDestination())
#if DEBUG
        // Add console in debug builds
        destinations.append(ConsoleDestination())
#endif
        // Try New Relic (if available)
        if let licenseKey = ProcessInfo.processInfo.environment["NEW_RELIC_LICENSE_KEY"] {
            if let newRelic = NewRelicDestination(licenseKey: licenseKey) {
                destinations.append(newRelic)
            } else {
                // TODO: Phase 12 - Add backend fallback destination
                print("⚠ New Relic unavailable, logs will only go to OSLog/Console")
            }
        }
    }
    
    // MARK: - Logging Methods (Internal - Async)
    func log(_ level: LogLevel, _ message: String, category: LogCategory, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) async {
        // Filter PII
        let sanitizedMessage = PIIFilter.redact(message)
        var sanitizedMetadata = metadata
        for (key, value) in metadata {
            sanitizedMetadata[key] = PIIFilter.redact(value)
        }
        // Add file/function/line metadata
        sanitizedMetadata["file"] = file.components(separatedBy: "/").last ?? file
        sanitizedMetadata["function"] = function
        sanitizedMetadata["line"] = "\(line)"
        // Add app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            sanitizedMetadata["appVersion"] = version
            sanitizedMetadata["platform"] = "ios"
        }
        let event = LogEvent(
            timestamp: Date(),
            level: level,
            category: category,
            message: sanitizedMessage,
            metadata: sanitizedMetadata,
            signpost: nil,
            duration: nil,
            memoryUsage: nil
        )
        buffer.append(event)
        // Immediate flush for errors/critical
        if level == .error || level == .critical {
            await flush()
        }
    }
    
    // MARK: - Auto Flush
    private func startAutoFlush() async {
        autoFlushTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(await AppConfiguration.logFlushInterval))
                await self.flush()
            }
        }
    }
    func flush() async {
        guard !buffer.isEmpty else { return }
        let events = buffer
        buffer.removeAll()
        // Flush to all destinations in parallel
        await withTaskGroup(of: Void.self) { group in
            for destination in destinations {
                group.addTask {
                    await destination.flush(events)
                }
            }
        }
    }
    
    // MARK: - Lifecycle
    func flushOnBackground() async {
        await flush()
    }
    
    func flushOnLogout() async {
        await flush()
    }
    
    // MARK: - Helper for non-isolated contexts
    private func appendToBuffer(_ event: LogEvent) async {
        buffer.append(event)
    }
    
    // MARK: - Signposts (Non-Blocking)
    nonisolated func signpostBegin(_ name: String, metadata: [String: String] = [:]) -> UUID {
        let id = UUID()
        Task.detached(priority: .utility) {
            // Use OSLog Logger for signposts (supports dynamic strings)
            let logger = os.Logger(subsystem: "com.bmalberta.christmasTracker", category: "performance")
            logger.notice("Signpost Begin: \(name)")
            
            let event = LogEvent(
                timestamp: Date(),
                level: .debug,
                category: .performance,
                message: "Signpost Begin: \(name)",
                metadata: metadata,
                signpost: SignpostInfo(name: name, id: id, state: .begin),
                duration: nil,
                memoryUsage: ProcessInfo.processInfo.physicalMemory
            )
            await Logger.shared.appendToBuffer(event)
        }
        return id
    }
    
    nonisolated func signpostEnd(_ name: String, id: UUID, metadata: [String: String] = [:]) {
        Task.detached(priority: .utility) {
            // Use OSLog Logger for signposts (supports dynamic strings)
            let logger = os.Logger(subsystem: "com.bmalberta.christmasTracker", category: "performance")
            logger.notice("Signpost End: \(name)")
            
            let event = LogEvent(
                timestamp: Date(),
                level: .debug,
                category: .performance,
                message: "Signpost End: \(name)",
                metadata: metadata,
                signpost: SignpostInfo(name: name, id: id, state: .end),
                duration: nil,
                memoryUsage: ProcessInfo.processInfo.physicalMemory
            )
            await Logger.shared.appendToBuffer(event)
        }
    }
}

// MARK: - Global Convenience Functions (Fire-and-Forget)
/// Log debug message (non-blocking)
nonisolated func LogDebug(_ message: String, category: LogCategory = .business, metadata: [String: String] = [:]) {
    Task.detached(priority: .background) {
        await Logger.shared.log(.debug, message, category: category, metadata: metadata)
    }
}

/// Log info message (non-blocking)
nonisolated func LogInfo(_ message: String, category: LogCategory = .business, metadata: [String: String] = [:]) {
    Task.detached(priority: .background) {
        await Logger.shared.log(.info, message, category: category, metadata: metadata)
    }
}

/// Log warning message (non-blocking)
nonisolated func LogWarning(_ message: String, category: LogCategory = .business, metadata: [String: String] = [:]) {
    Task.detached(priority: .background) {
        await Logger.shared.log(.warning, message, category: category, metadata: metadata)
    }
}
/// Log error message (non-blocking)
nonisolated func LogError(_ message: String, category: LogCategory = .business, metadata: [String: String] = [:]) {
    Task.detached(priority: .background) {
        await Logger.shared.log(.error, message, category: category, metadata: metadata)
    }
}
/// Log critical message (non-blocking)
nonisolated func LogCritical(_ message: String,category: LogCategory = .business,metadata: [String: String] = [:]) {
    Task.detached(priority: .background) {
        await Logger.shared.log(.critical, message, category: category, metadata: metadata)
    }
}

