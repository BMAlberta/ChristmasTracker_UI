//
//  ServiceInstrumentationScanTests.swift
//  ChristmasTrackerTests
//
//  LG1-L4, rule R3: "a new service file must be instrumented".
//  Every `.swift` file directly under `Features/<feature>/Services/` (not only `*Service.swift`) that calls a
//  repository or the generated client (see `ServiceSourceWalk`) must have, in code (comments stripped):
//    - `@Instrumented` (the macro), or
//    - `InstrumentedOperation.run` (the main-actor helper, where the macro cannot be applied), or
//    - a hand span `SentrySDK.startTransaction` together with a comment containing "@Instrumented cannot" or
//      "Actor-isolated" that explains why the macro is not used.
//  A file with none of these fails. Files are found by walking the tree.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Service instrumentation Scan Tests")
struct ServiceInstrumentationScanTests {

    private let call = "func go() async throws { _ = try await repository.fetch() }\n"

    // MARK: Rule self-proofs

    @Test("A repository call with no instrumentation fails")
    func uninstrumentedFails() {
        #expect(ServiceInstrumentationRule.isMissingInstrumentation(call))
        #expect(ServiceInstrumentationRule.isMissingInstrumentation("// @Instrumented\n" + call))
        #expect(ServiceInstrumentationRule.isMissingInstrumentation(
            "// Actor-isolated\n" + call), "an explaining comment alone is not a span")
        #expect(ServiceInstrumentationRule.isMissingInstrumentation(
            "SentrySDK.startTransaction(name: \"x\")\n" + call), "a hand span with no explaining comment")
    }

    @Test("The accepted instrumentation forms pass")
    func instrumentedPasses() {
        #expect(!ServiceInstrumentationRule.isMissingInstrumentation("@Instrumented\n" + call))
        #expect(!ServiceInstrumentationRule.isMissingInstrumentation(
            "try await InstrumentedOperation.run(\"x\") { }\n" + call))
        #expect(!ServiceInstrumentationRule.isMissingInstrumentation(
            "// Actor-isolated (@MainActor): manual span.\nlet s = SentrySDK.startTransaction(name: \"x\")\n" + call))
        #expect(!ServiceInstrumentationRule.isMissingInstrumentation(
            "// @Instrumented cannot be applied here.\nlet s = SentrySDK.startTransaction(name: \"x\")\n" + call))
    }

    @Test("A file that makes no repository call needs no instrumentation")
    func nonCallingFileIsExempt() {
        #expect(!ServiceInstrumentationRule.isMissingInstrumentation("struct Plain { let value = 1 }\n"))
        #expect(!ServiceInstrumentationRule.isMissingInstrumentation("// try await repository.fetch()\n"))
    }

    // MARK: The rule on disk

    @Test("The walk finds the Services folders and several repository-calling files (not vacuous)")
    func walkIsNotVacuous() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let files = ServiceSourceWalk.featureServiceFolderFiles(in: tree)
        #expect(files.count >= 20, "Only \(files.count) files found under Features/*/Services")
        let calling = files.filter { ServiceSourceWalk.callsRepository($0.code) }
        #expect(calling.count >= 8, "Only \(calling.count) files call a repository")
    }

    @Test("Every file under Features/*/Services that calls a repository is instrumented")
    func serviceFilesAreInstrumented() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let missing = ServiceSourceWalk.featureServiceFolderFiles(in: tree).filter {
            !ServiceInstrumentationRule.knownExceptions.contains($0.path)
                && ServiceInstrumentationRule.isMissingInstrumentation($0.raw)
        }
        let paths = missing.map(\.path)
        #expect(missing.isEmpty, "Calls a repository with no @Instrumented / InstrumentedOperation: \(paths)")
    }
}
