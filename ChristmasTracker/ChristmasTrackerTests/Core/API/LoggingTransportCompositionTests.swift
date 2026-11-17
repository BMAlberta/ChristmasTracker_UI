// LoggingTransportCompositionTests.swift
// ChristmasTrackerTests
//
// Package LG1, story L2: the logging transport is wired into the app composition root.
// The transport type is not observable from the client, so the wiring is checked two ways:
// buildGeneratedClient(mode: .real, ...) still returns a client, and a source scan of
// ChristmasTrackerApp.swift asserts the TrackerClientFactory.make( call passes
// `transport: LoggingClientTransport.production()`.
//
// Fails to compile until LoggingClientTransport exists; the scan fails until the app wires it.

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Logging transport composition (LG1 L2)")
struct LoggingTransportCompositionTests {

    @Test("buildGeneratedClient in real mode still returns a client with the logging transport wired")
    func realModeStillBuildsClient() throws {
        let url = try #require(URL(string: "https://example.invalid"))

        let client = buildGeneratedClient(
            mode: .real,
            serverURL: url,
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: ListFakeTokenProvider(token: nil),
            sessionRefresher: ListFakeRefresher(),
            versionOutdatedHandler: ListFakeVersionHandler()
        )

        #expect(client != nil)
    }

    @Test("the app passes transport: LoggingClientTransport.production() to TrackerClientFactory.make(")
    func appPassesLoggingTransport() throws {
        let testFile = URL(fileURLWithPath: #filePath).standardizedFileURL
        let source = try Self.appSource(from: testFile)
        let code = source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        let call = try #require(Self.callText(in: code, startingAt: "TrackerClientFactory.make("),
                                "TrackerClientFactory.make( call not found in ChristmasTrackerApp.swift")

        #expect(call.contains("transport: LoggingClientTransport.production()"))
    }

    // MARK: - Helpers

    private static func appSource(from testFile: URL) throws -> String {
        var directory = testFile.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                let appFile = directory.deletingLastPathComponent()
                    .appendingPathComponent("ChristmasTracker", isDirectory: true)
                    .appendingPathComponent("ChristmasTrackerApp.swift")
                return try String(contentsOf: appFile, encoding: .utf8)
            }
            directory = directory.deletingLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    /// The text from `marker` to its matching closing parenthesis.
    private static func callText(in code: String, startingAt marker: String) -> String? {
        guard let start = code.range(of: marker) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            switch code[index] {
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            default: break
            }
            index = code.index(after: index)
        }
        return nil
    }
}
