//
//  ServiceLogsWhenCallingScanTests.swift
//  ChristmasTrackerTests
//
//  LG1-L4, rule R1: "a service logs when it calls".
//  Every `*Service.swift` under `Features/<feature>/Services/` and `Core/API/` (found by walking the app source
//  folder, not from a list) that calls a repository or the generated client (see `ServiceSourceWalk`) must
//  contain at least one `log.<step>(` call or `Log*(` call in the same file. A service file that makes no
//  repository call by that same detection is exempt automatically (there is no hand-kept exemption list).
//  The walk must find at least 10 service files, so the scan can never pass by finding nothing.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Service logs when it calls Scan Tests")
struct ServiceLogsWhenCallingScanTests {

    // MARK: Detection self-proofs

    @Test("A repository or client call is detected", arguments: [
        "let a = try await repository.fetch()",
        "let a = try await perform { try await itemRepository.fetchItems(listId: id) }",
        "let a = try await perform { try await work(repository) }",
        "let a = try await\n    authRepository.login()",
        "let a = client.getItem(id)"
    ])
    func detectsRepositoryCalls(source: String) {
        #expect(ServiceSourceWalk.callsRepository(ItemSourceScan.codeOnly(source)), "\(source)")
    }

    @Test("Look-alikes and comments are not repository calls", arguments: [
        "let a = try await helper.run()",
        "private let repository: any Loading",
        "// let a = try await repository.fetch()",
        "/* client.getItem(id) */",
        "let subclient = 1"
    ])
    func ignoresNonCalls(source: String) {
        #expect(!ServiceSourceWalk.callsRepository(ItemSourceScan.codeOnly(source)), "\(source)")
    }

    @Test("A step call or a Log call counts as a log line; a comment or a look-alike does not", arguments: [
        ("log.started(op)", true),
        ("log.skipped(op, reason: reason)", true),
        ("LogInfo(\"x\", category: .business)", true),
        ("LogError(\"x\", category: .auth)", true),
        ("// log.started(op)", false),
        ("catalog.started(op)", false),
        ("let logger = 1", false)
    ])
    func detectsLogLines(source: String, expected: Bool) {
        #expect(ServiceSourceWalk.writesLogLine(ItemSourceScan.codeOnly(source)) == expected, "\(source)")
    }

    // MARK: The rule on disk

    @Test("The walk finds the service files and most of them call a repository (not vacuous)")
    func walkIsNotVacuous() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let files = ServiceSourceWalk.serviceFiles(in: tree)
        #expect(files.count >= 10, "Only \(files.count) service files found: \(files.map(\.path))")
        let calling = files.filter { ServiceSourceWalk.callsRepository($0.code) }
        #expect(calling.count >= 8, "Only \(calling.count) service files call a repository")
    }

    @Test("Every service file that calls a repository writes at least one log line")
    func servicesLogWhenTheyCall() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let silent = ServiceSourceWalk.serviceFiles(in: tree).filter {
            ServiceSourceWalk.callsRepository($0.code) && !ServiceSourceWalk.writesLogLine($0.code)
        }
        #expect(silent.isEmpty, "Service files call a repository but never log: \(silent.map(\.path))")
    }
}
