//
//  ChildServiceEnvironmentTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the SwiftUI environment default of ChildService (key `childService` in
//  EnvironmentValues+ChildService.swift) is built from InertChildRepository, never a Mock.
//
//  - Behavior: reading `EnvironmentValues().childService` needs no view; calling loadChildren on
//    the default ends in phase .failed with no children (the inert repository throws).
//  - Source scan: the key file contains no `Mock` (comment lines ignored).
//

import Foundation
import SwiftUI
import Testing
@testable import ChristmasTracker

@Suite("ChildService environment default", .timeLimit(.minutes(1)))
@MainActor
struct ChildServiceEnvironmentTests {

    @Test("the default ChildService is inert: loadChildren ends failed with no children")
    func defaultIsInert() async {
        let service = EnvironmentValues().childService

        await service.loadChildren()

        guard case .failed = service.phase else {
            Issue.record("expected the inert default to end in .failed, got \(service.phase)")
            return
        }
        #expect(service.children.isEmpty)
    }

    @Test("the default ChildService cannot add or delete a child")
    func defaultCannotMutate() async {
        let service = EnvironmentValues().childService

        await #expect(throws: (any Error).self) {
            try await service.addChild(
                CreateChildInput(firstName: "Eli", lastName: "Example", displayName: nil, relationship: .parent)
            )
        }
        await #expect(throws: (any Error).self) {
            try await service.deleteChild(id: "child-a")
        }
        #expect(service.children.isEmpty)
    }

    // MARK: - Source scan

    private static func appSourceRoot(from file: URL) -> URL? {
        var directory = file.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                let root = directory.deletingLastPathComponent().appendingPathComponent("ChristmasTracker", isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return root
                }
                return nil
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    @Test("EnvironmentValues+ChildService.swift contains no Mock")
    func environmentKeyFileHasNoMock() throws {
        let thisFile = URL(fileURLWithPath: #filePath).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile), "Could not find the app source folder")
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var found: URL?
        for case let url as URL in enumerator where url.lastPathComponent == "EnvironmentValues+ChildService.swift" {
            found = url
        }
        let keyFile = try #require(found, "EnvironmentValues+ChildService.swift must exist")
        let code = try String(contentsOf: keyFile, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        #expect(!code.contains("Mock"), "the environment default must never construct a Mock")
        #expect(code.contains("InertChildRepository"), "the default must be built from InertChildRepository")
    }
}
