//
//  AuthenticationServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch D: the step lines AuthenticationService writes through ServiceLog for login,
//  register, biometric sign-in, refresh, force refresh and logout: started and processed on
//  success, exactly one error on failure, cancelled (never an error) on cancellation, only the
//  failure line in a Release-style run, no secret fixture in any line, and the session-end
//  best-effort logout failure line. The harness types (AuthLogRig and friends) are shared with
//  AuthenticationServiceLogSessionTests.swift.
//
//  Will fail to compile until AuthenticationService.init gains the defaulted trailing
//  parameter `log: ServiceLog = ServiceLog()`.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Secret fixtures

enum AuthLogSecret {
    static let email = "zz-secret@example.com"
    static let password = "ZZ-secret-password"
    static let name = "ZZ-secret-name"
    static let token = "ZZ-secret-token"
    static let server = "ZZ-secret-server-text"
    static let error = "ZZ-secret-error"
    static let all = [email, password, name, token, server, error, "zz-secret", "ZZ-secret"]
}

struct AuthLogSecretError: Error, LocalizedError, CustomStringConvertible {
    var errorDescription: String? { AuthLogSecret.error }
    var description: String { AuthLogSecret.error }
}

// MARK: - Scripted repository

@MainActor final class ScriptedAuthRepository: AuthenticationRepository {
    var loginError: (any Error)?
    var registerError: (any Error)?
    var refreshError: (any Error)?
    var logoutError: (any Error)?
    var loginExpiresIn = 0

    /// When true, logout() suspends until releaseLogout() is called.
    var holdLogout = false
    private(set) var logoutCalls = 0
    private var heldLogout: CheckedContinuation<Void, Never>?

    func releaseLogout() {
        heldLogout?.resume()
        heldLogout = nil
    }

    private func session(expiresIn: Int) -> AuthSession {
        AuthSession(
            user: User(
                id: "u1", email: AuthLogSecret.email, firstName: AuthLogSecret.name,
                lastName: AuthLogSecret.name, displayName: AuthLogSecret.name, role: .user,
                isActive: true, createdAt: Date(timeIntervalSince1970: 0),
                updatedAt: Date(timeIntervalSince1970: 0), lastLoginAt: nil
            ),
            accessToken: AuthLogSecret.token, refreshToken: AuthLogSecret.token, expiresIn: expiresIn
        )
    }

    func login(email: String, password: String) async throws -> AuthSession {
        if let loginError { throw loginError }
        return session(expiresIn: loginExpiresIn)
    }

    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        if let registerError { throw registerError }
        return session(expiresIn: 900)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        if let refreshError { throw refreshError }
        return session(expiresIn: 900)
    }

    func logout() async throws {
        logoutCalls += 1
        if holdLogout {
            await withCheckedContinuation { heldLogout = $0 }
        }
        if let logoutError { throw logoutError }
    }
}

// MARK: - Operations under test

enum AuthLogOp: CaseIterable, Sendable {
    case login, register, biometric, refresh, forceRefresh, logout

    var name: String {
        switch self {
        case .login: "auth login"
        case .register: "auth register"
        case .biometric: "auth biometric sign-in"
        case .refresh: "auth refresh"
        case .forceRefresh: "auth force refresh"
        case .logout: "auth logout"
        }
    }
}

// MARK: - Rig

@MainActor struct AuthLogRig {
    let service: AuthenticationService
    let repo: ScriptedAuthRepository
    let sink: CapturingOperationLog
    let store: InMemoryBiometricCredentialStore
    var baseline = 0

    init(verbose: Bool = true) {
        let repo = ScriptedAuthRepository()
        let sink = CapturingOperationLog()
        let store = InMemoryBiometricCredentialStore()
        try? store.enroll(refreshToken: AuthLogSecret.token, userId: "u1", firstName: AuthLogSecret.name)
        self.service = AuthenticationService(
            repository: repo,
            sessionManager: SessionManager(initialClearables: []),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: store,
            log: ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        )
        self.repo = repo
        self.sink = sink
        self.store = store
    }

    /// Signs in when the operation needs a session, and marks where the lines under test start.
    static func prepared(_ op: AuthLogOp, verbose: Bool = true) async -> AuthLogRig {
        var rig = AuthLogRig(verbose: verbose)
        switch op {
        case .refresh, .forceRefresh, .logout:
            await rig.service.login(email: AuthLogSecret.email, password: AuthLogSecret.password)
        case .login, .register, .biometric:
            break
        }
        rig.baseline = rig.sink.lines.count
        return rig
    }

    func fail(_ op: AuthLogOp, with error: any Error) {
        switch op {
        case .login: repo.loginError = error
        case .register: repo.registerError = error
        case .biometric, .refresh, .forceRefresh: repo.refreshError = error
        case .logout: repo.logoutError = error
        }
    }

    /// Runs the operation. Logout's best-effort API step is not guaranteed to have logged by the
    /// time the call returns, so a logout waits (bounded) for its terminal line when
    /// `waitForLines` is true.
    func run(_ op: AuthLogOp, waitForLines: Bool = true) async {
        switch op {
        case .login:
            await service.login(email: AuthLogSecret.email, password: AuthLogSecret.password, rememberEmail: false)
        case .register:
            await service.register(email: AuthLogSecret.email, password: AuthLogSecret.password,
                                   firstName: AuthLogSecret.name, lastName: AuthLogSecret.name,
                                   registrationCode: "CODE-FAKE")
        case .biometric:
            await service.signInWithBiometric()
        case .refresh:
            await service.refreshTokenIfNeeded()
        case .forceRefresh:
            _ = try? await service.forceRefresh()
        case .logout:
            await service.logout()
            if waitForLines {
                let terminal = ["processed", "failed", "cancelled"].map { "\(op.name) \($0)" }
                await waitUntil { messages.contains { terminal.contains($0) } }
            }
        }
    }

    /// Bounded poll: yields and short sleeps for up to about 2 seconds, then returns either way.
    func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Gives pending work a short, fixed chance to log before an absence is asserted.
    func settle() async {
        for _ in 0..<5 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(150))
    }

    var added: [CapturingOperationLog.Line] { Array(sink.lines.dropFirst(baseline)) }
    var messages: [String] { added.map(\.message) }
    var errors: [String] { added.filter { $0.level == .error }.map(\.message) }

    func expectClean(sourceLocation: SourceLocation = #_sourceLocation) {
        for line in sink.lines {
            for secret in AuthLogSecret.all {
                #expect(!line.message.contains(secret), "line leaked a secret: \(line.message)", sourceLocation: sourceLocation)
            }
            #expect(!line.message.contains("@"), "line contains @: \(line.message)", sourceLocation: sourceLocation)
            #expect(!line.message.contains("://"), "line contains ://: \(line.message)", sourceLocation: sourceLocation)
        }
    }
}

@Suite("AuthenticationService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct AuthenticationServiceLogTests {

    @Test("a success logs started then processed, in order", arguments: AuthLogOp.allCases)
    func success(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op)

        await rig.run(op)

        #expect(rig.messages == ["\(op.name) started", "\(op.name) processed"])
        #expect(rig.added.allSatisfy { $0.level == .debug })
        #expect(rig.errors.isEmpty)
        rig.expectClean()
    }

    @Test("an AuthenticationError failure logs exactly one error line", arguments: AuthLogOp.allCases)
    func authErrorFailure(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op)
        rig.fail(op, with: AuthenticationError.networkError)

        await rig.run(op)

        #expect(rig.errors == ["\(op.name) failed"])
        #expect(rig.messages.first == "\(op.name) started")
        #expect(!rig.messages.contains("\(op.name) processed"))
        rig.expectClean()
    }

    @Test("a generic error failure logs exactly one error line without the error text", arguments: AuthLogOp.allCases)
    func genericFailure(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op)
        rig.fail(op, with: AuthLogSecretError())

        await rig.run(op)

        #expect(rig.errors == ["\(op.name) failed"])
        #expect(!rig.messages.contains("\(op.name) processed"))
        rig.expectClean()
    }

    @Test("a server message in a validation error never reaches a line", arguments: [AuthLogOp.login, .register])
    func serverTextFailure(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op)
        rig.fail(op, with: AuthenticationError.validation(message: AuthLogSecret.server))

        await rig.run(op)

        #expect(rig.errors == ["\(op.name) failed"])
        rig.expectClean()
    }

    @Test("a cancelled call logs cancelled and no error", arguments: AuthLogOp.allCases)
    func cancellation(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op)
        rig.fail(op, with: CancellationError())

        await rig.run(op)

        #expect(rig.messages.first == "\(op.name) started")
        #expect(rig.messages.contains("\(op.name) cancelled"))
        #expect(rig.errors.isEmpty)
        #expect(!rig.messages.contains("\(op.name) failed"))
        rig.expectClean()
    }

    @Test("a Release-style success logs nothing", arguments: AuthLogOp.allCases)
    func releaseSuccess(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op, verbose: false)

        await rig.run(op, waitForLines: false)
        await rig.settle()

        #expect(rig.sink.lines.isEmpty)
    }

    @Test("a Release-style failure logs only the failed line", arguments: AuthLogOp.allCases)
    func releaseFailure(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op, verbose: false)
        rig.fail(op, with: AuthLogSecretError())

        await rig.run(op)

        #expect(rig.sink.lines.map(\.message) == ["\(op.name) failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("a Release-style cancellation logs nothing", arguments: AuthLogOp.allCases)
    func releaseCancellation(op: AuthLogOp) async {
        let rig = await AuthLogRig.prepared(op, verbose: false)
        rig.fail(op, with: CancellationError())

        await rig.run(op, waitForLines: false)
        await rig.settle()

        #expect(rig.sink.lines.isEmpty)
    }

    @Test("a server session end whose best-effort logout fails logs one literal error line")
    func serverSessionEndLogoutFailure() async throws {
        let rig = await AuthLogRig.prepared(.logout)
        let token = try #require(rig.service.currentAccessToken)
        rig.repo.logoutError = AuthLogSecretError()

        await rig.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: token)
        await rig.waitUntil { !rig.errors.isEmpty }
        await rig.settle()

        #expect(rig.errors == ["auth logout failed"])
        rig.expectClean()
    }

    @Test("a server session end for a stale or missing token logs no error")
    func serverSessionEndStale() async {
        let rig = await AuthLogRig.prepared(.logout)
        rig.repo.logoutError = AuthLogSecretError()

        await rig.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: "ZZ-secret-stale-token")
        await rig.service.handleServerSessionEnd(reason: .userNotFound, requestToken: nil)
        await rig.settle()

        #expect(rig.errors.isEmpty)
        rig.expectClean()
    }

    @Test("a server session end whose best-effort logout succeeds logs no error")
    func serverSessionEndLogoutSuccess() async throws {
        let rig = await AuthLogRig.prepared(.logout)
        let token = try #require(rig.service.currentAccessToken)

        await rig.service.handleServerSessionEnd(reason: .userNotFound, requestToken: token)
        await rig.settle()

        #expect(rig.errors.isEmpty)
        rig.expectClean()
    }
}
