//
//  LegacyTokenSeamTests.swift
//  ChristmasTrackerTests
//
//  I2b-2d E3 (D2(d)): logout and clearForSession clear the stored session tokens through the
//  LegacyTokenCleaning seam (clearStoredSessionTokens), never through KeychainService directly,
//  and no unit test builds AuthenticationService with the real LegacyTokenCleanup default.
//
//  Expected red until the implementer adds `clearStoredSessionTokens()` to LegacyTokenCleaning
//  and routes AuthenticationService.clearStoredTokens() through it: the fake's method exists but
//  production never calls it, so the call counts stay 0.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// Keeps the remembered email in memory so these tests never write UserDefaults.
private struct SeamTestEmailStore: RememberedEmailStoring {
    var rememberedEmail: String?
}

@Suite("LegacyTokenCleaning seam")
@MainActor
struct LegacyTokenSeamTests {

    // MARK: - Factory

    private func makeSUT() -> (service: AuthenticationService, cleanup: FakeLegacyTokenCleanup) {
        let cleanup = FakeLegacyTokenCleanup()
        let service = AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(initialClearables: []),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            emailStore: SeamTestEmailStore(),
            legacyCleanup: cleanup,
            credentialStore: InMemoryBiometricCredentialStore()
        )
        return (service, cleanup)
    }

    // MARK: - Logout

    @Test("logout clears the stored session tokens through the seam exactly once")
    func logoutCallsClearStoredSessionTokensOnce() async throws {
        let (service, cleanup) = makeSUT()
        await service.login(email: "seam@example.com", password: "password-FAKE", rememberEmail: false)
        try #require(service.isAuthenticated == true, "Precondition: must be authenticated")
        #expect(cleanup.clearStoredSessionTokensCallCount == 0,
                "Precondition: init and login must not clear the stored session tokens")

        await service.logout()

        #expect(service.isAuthenticated == false)
        #expect(cleanup.clearStoredSessionTokensCallCount == 1,
                "logout must clear the stored session tokens through LegacyTokenCleaning exactly once")
        #expect(cleanup.cleanUpCallCount == 1,
                "cleanUpLegacyTokens must stay at 1 (from init); logout must not call it")
    }

    // MARK: - clearForSession

    @Test("clearForSession clears the stored session tokens through the seam")
    func clearForSessionCallsClearStoredSessionTokens() async throws {
        let (service, cleanup) = makeSUT()
        await service.login(email: "seam@example.com", password: "password-FAKE", rememberEmail: false)
        try #require(service.isAuthenticated == true, "Precondition: must be authenticated")

        try await service.clearForSession()

        #expect(service.isAuthenticated == false)
        #expect(cleanup.clearStoredSessionTokensCallCount == 1,
                "clearForSession must clear the stored session tokens through LegacyTokenCleaning once")
        #expect(cleanup.cleanUpCallCount == 1,
                "cleanUpLegacyTokens must stay at 1 (from init); clearForSession must not call it")
    }

    // MARK: - Guard: no unit test uses the real LegacyTokenCleanup default

    @Test("every AuthenticationService construction in the unit-test sources injects legacyCleanup")
    func everyTestConstructionInjectsLegacyCleanup() throws {
        let thisFile = URL(fileURLWithPath: #filePath).standardizedFileURL
        let root = try #require(Self.testSourcesRoot(from: thisFile),
                                "Could not find the ChristmasTrackerTests directory above \(thisFile.path)")

        let files = Self.swiftFiles(under: root)
        try #require(!files.isEmpty,
                     "The test process could not read any .swift file under \(root.path)")

        var constructionCount = 0
        var offenders: [String] = []
        for file in files where file.standardizedFileURL.path != thisFile.path {
            let source = try String(contentsOf: file, encoding: .utf8)
            for call in Self.constructionCalls(in: Self.codeOnly(source)) {
                constructionCount += 1
                if !call.arguments.contains("legacyCleanup:") {
                    offenders.append("\(file.path):\(call.line)")
                }
            }
        }

        #expect(constructionCount > 0,
                "The scanner found no AuthenticationService( call sites, so it is not scanning the test sources")
        #expect(offenders.isEmpty,
                "AuthenticationService built without legacyCleanup: (it would run the real Keychain cleanup) at:\n\(offenders.joined(separator: "\n"))")
    }

    // MARK: - Scanner helpers

    /// Walks up from this file to the ChristmasTrackerTests directory.
    private static func testSourcesRoot(from file: URL) -> URL? {
        var directory = file.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    private static func swiftFiles(under root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            result.append(url)
        }
        return result
    }

    /// Returns the source with comments and string-literal contents replaced by spaces.
    /// Newlines are kept, so line numbers stay correct.
    private static func codeOnly(_ source: String) -> [Character] {
        let chars = Array(source)
        var out = chars
        var index = 0
        var blockDepth = 0

        func blank(_ position: Int) {
            if out[position] != "\n" { out[position] = " " }
        }
        func at(_ position: Int, _ text: String) -> Bool {
            let pattern = Array(text)
            guard position + pattern.count <= chars.count else { return false }
            return Array(chars[position..<(position + pattern.count)]) == pattern
        }

        while index < chars.count {
            if blockDepth > 0 {
                if at(index, "/*") {
                    blockDepth += 1
                    blank(index); blank(index + 1); index += 2
                } else if at(index, "*/") {
                    blockDepth -= 1
                    blank(index); blank(index + 1); index += 2
                } else {
                    blank(index); index += 1
                }
            } else if at(index, "//") {
                while index < chars.count, chars[index] != "\n" {
                    blank(index); index += 1
                }
            } else if at(index, "/*") {
                blockDepth = 1
                blank(index); blank(index + 1); index += 2
            } else if at(index, "\"\"\"") {
                index += 3
                while index < chars.count, !at(index, "\"\"\"") {
                    if chars[index] == "\\" { blank(index); index += 1 }
                    if index < chars.count { blank(index); index += 1 }
                }
                index += 3
            } else if chars[index] == "\"" {
                index += 1
                while index < chars.count, chars[index] != "\"", chars[index] != "\n" {
                    if chars[index] == "\\" { blank(index); index += 1 }
                    if index < chars.count { blank(index); index += 1 }
                }
                index += 1
            } else {
                index += 1
            }
        }
        return out
    }

    private struct ConstructionCall {
        let line: Int
        let arguments: String
    }

    /// Finds each `AuthenticationService(` or `AuthenticationService.init(` call whose name is
    /// not part of a longer identifier, and returns the text inside its balanced parentheses.
    private static func constructionCalls(in code: [Character]) -> [ConstructionCall] {
        let names = [Array("AuthenticationService("), Array("AuthenticationService.init(")]
        var calls: [ConstructionCall] = []
        var line = 1
        var index = 0
        while index < code.count {
            if code[index] == "\n" { line += 1 }
            let precededByIdentifier = index > 0
                && (code[index - 1].isLetter || code[index - 1].isNumber || code[index - 1] == "_")
            var openParen: Int?
            if !precededByIdentifier {
                for name in names where index + name.count <= code.count
                    && Array(code[index..<(index + name.count)]) == name {
                    openParen = index + name.count - 1
                }
            }
            guard let open = openParen else {
                index += 1
                continue
            }
            var depth = 0
            var close = open
            while close < code.count {
                if code[close] == "(" { depth += 1 }
                if code[close] == ")" {
                    depth -= 1
                    if depth == 0 { break }
                }
                close += 1
            }
            let end = min(close, code.count)
            calls.append(ConstructionCall(line: line, arguments: String(code[(open + 1)..<end])))
            index = open + 1
        }
        return calls
    }
}
