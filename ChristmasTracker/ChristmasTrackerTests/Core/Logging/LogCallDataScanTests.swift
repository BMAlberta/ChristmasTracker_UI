//
//  LogCallDataScanTests.swift
//  ChristmasTrackerTests
//
//  LG1-L4, rule R2: "no data in a log call".
//  Across ALL `*Service.swift` files (found by walking the tree) plus `Core/API/LoggingClientTransport.swift`:
//    - every `Log(Debug|Info|Warning|Error|Critical)(` call has one string-literal message and an optional
//      `category: .x`; every `log.log(` / `sink.log(` call in the transport is `<level>, <literal>, category:`;
//    - every interpolation in those messages is one of an explicit set of names (operation name, method, attempt,
//      status, ms, duration, request id, category, count, noun, reason, plus the transport's `parts` / `detail`
//      locals and `<path>.count`): see `LogCallDataScan.allowedNames`;
//    - every `log.<started|processed|cancelled|failed|skipped>(` call and `let op` / `let opName` is a fixed shape
//      (reuses `ServiceLogCallScan`);
//    - every `op:` / `opName:` argument at a call site is a string literal or the pass-through `op` / `opName`
//      (closes the gap on runManagement / failure / managementFailure / recordLoadError / recordDetailLoadError).
//  The scanner is proven on in-memory strings first.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Log call data Scan Tests")
struct LogCallDataScanTests {

    private func violations(_ source: String) throws -> [String] {
        try LogCallDataScan.violations(in: ItemSourceScan.codeOnly(source))
    }

    // MARK: Scanner self-proofs

    @Test("The scanner fires on data in a log call, a non-literal message, and a non-literal op", arguments: [
        #"LogError("x \(price)")"#,
        #"LogInfo("Loaded \(items)", category: .business)"#,
        #"LogError("failed \(error)", category: .auth)"#,
        "LogInfo(message)",
        #"LogInfo("a" + name)"#,
        "LogWarning(String(describing: error))",
        #"LogError("x", error: error)"#,
        "log.processed(notes)",
        #"log.started("x \(id)")"#,
        #"runManagement(spanName: "s", op: "x \(id)") { }"#,
        "runManagement(spanName: \"s\", op: name) { }",
        "throw failure(error, generation: gen, op: someId)",
        "recordLoadError(error, generation: gen, token: token, op: describe(error))",
        #"log.log(.debug, "\(token) seen", category: .network)"#,
        #"sink.log(.debug, message, category: .network)"#,
        #"log.log(.error, "\(operationID) failed (\(error))", category: .network)"#,
        #"log.log(.debug, "\(request.url)", category: .network)"#,
        "let op = \"load \\(name)\""
    ])
    func scannerFires(source: String) throws {
        #expect(!(try violations(source)).isEmpty, "\(source)")
    }

    @Test("The scanner allows the legitimate shapes, comments and look-alike names", arguments: [
        #"LogInfo("Created item", category: .business)"#,
        #"LogDebug("Refreshing access token", category: .auth)"#,
        #"LogInfo("Loaded \(fetched.count) lists", category: .business)"#,
        #"LogInfo("Archived \(archivedCount) of \(ids.count) lists", category: .business)"#,
        #"LogWarning("\(op) skipped (\(reason))")"#,
        #"log.log(.debug, "\(operationID) request made (\(method), attempt \(attempt))", category: .network)"#,
        #"log.log(.debug, "\(operationID) request made (\(method.rawValue))", category: .network)"#,
        #"log.log(isProblem ? .warning : .debug, "\(operationID) response (\(parts.joined(separator: ", ")))", "#
            + "category: .network)",
        "log.log(\n    .error,\n    \"\\(operationID) request failed (\\(detail))\",\n    category: .network\n)",
        #"sink.log(.debug, "\(operationID) done in \(ms) ms, status \(status)", category: .network)"#,
        "log.started(op)",
        "log.processed(op, count: items.count, noun: \"items\")",
        "let op = \"load items\"",
        "runManagement(spanName: \"s\", op: \"fetch purchase\") { }",
        "throw failure(error, generation: gen, op: op)",
        "recordLoadError(error, generation: gen, token: token, op: opName)",
        "private func failure(_ error: any Error, generation gen: Int, op: String) -> any Error {",
        "opName: String,",
        #"// LogError("x \(price)")"#,
        #"/* log.log(.debug, "\(token)", category: .network) */"#,
        "let loop: Int = 1",
        "Catalog.log(thing)"
    ])
    func scannerAllows(source: String) throws {
        #expect(try violations(source).isEmpty, "\(source)")
    }

    @Test("The scanner reads past a quote or parenthesis inside a message and reports the line")
    func scannerReadsLinesAndStrings() throws {
        let first = "LogInfo(\"quoted ) paren ( and \\\"quote\\\"\", category: .auth)"
        let source = "let a = 1\n" + first + "\nLogError(\"x \\(price)\")\n"
        let found = try violations(source)
        #expect(found.count == 1, "\(found)")
        #expect(found.first?.contains("line 3") == true, "\(found)")
    }

    // MARK: The scanned files

    @Test("Every log call and op argument in every service file and the transport carries no data")
    func serviceAndTransportLogCallsCarryNoData() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        var files = ServiceSourceWalk.serviceFiles(in: tree)
        let transportPath = "Core/API/LoggingClientTransport.swift"
        let transportRaw = try #require(tree.source(transportPath), "Could not read \(transportPath)")
        files.append(ServiceSourceWalk.File(
            path: transportPath, raw: transportRaw, code: ItemSourceScan.codeOnly(transportRaw)
        ))
        #expect(files.count >= 11, "Only \(files.count) files scanned: scan is vacuous")

        var logCalls = 0
        var transportCalls = 0
        for file in files {
            logCalls += try LogCallDataScan.callCount(in: file.code, transport: false)
            transportCalls += try LogCallDataScan.callCount(in: file.code, transport: true)
            let found = try LogCallDataScan.violations(in: file.code)
            #expect(found.isEmpty, "\(file.path):\n\(found.joined(separator: "\n"))")
        }
        #expect(logCalls >= 10, "Only \(logCalls) Log*( calls scanned: scan is vacuous")
        #expect(transportCalls >= 4, "Only \(transportCalls) transport log calls scanned: scan is vacuous")
    }
}
