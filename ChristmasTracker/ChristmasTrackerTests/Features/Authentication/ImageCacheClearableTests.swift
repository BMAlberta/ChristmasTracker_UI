//
//  ImageCacheClearableTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T6: the image cache is cleared once per session end, through a fake seam.
//  No test touches URLCache.shared.
//

import Testing
import Foundation
@testable import ChristmasTracker

/// Spy for the image cache seam (nonisolated Sendable protocol, so a lock-guarded class).
final class MockImageCacheClearing: ImageCacheClearing, @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    var clearCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _count
    }

    func removeAllCachedResponses() {
        lock.lock(); defer { lock.unlock() }
        _count += 1
    }
}

enum TestTeardownReason: Sendable, CustomTestStringConvertible, CaseIterable {
    case userLogout, sessionExpired, forcedUpdate, lockFallback

    var reason: TeardownReason {
        switch self {
        case .userLogout: .userLogout
        case .sessionExpired: .sessionExpired
        case .forcedUpdate: .forcedUpdate
        case .lockFallback: .lockFallback
        }
    }

    var testDescription: String {
        switch self {
        case .userLogout: "userLogout"
        case .sessionExpired: "sessionExpired"
        case .forcedUpdate: "forcedUpdate"
        case .lockFallback: "lockFallback"
        }
    }
}

@Suite("Image cache clearable Tests")
struct ImageCacheClearableTests {

    private func makeSUT() -> (sut: ImageCacheClearable, cache: MockImageCacheClearing) {
        let cache = MockImageCacheClearing()
        return (ImageCacheClearable(cache: cache), cache)
    }

    @Test("Nothing is cleared before a session ends")
    func notClearedOnInit() {
        let (_, cache) = makeSUT()
        #expect(cache.clearCount == 0)
    }

    @Test("One clearForSession clears the cache exactly once")
    func clearsOnce() async throws {
        let (sut, cache) = makeSUT()
        try await sut.clearForSession()
        #expect(cache.clearCount == 1)
    }

    @Test("Two clearForSession calls clear twice, one per session end")
    func clearsTwice() async throws {
        let (sut, cache) = makeSUT()
        try await sut.clearForSession()
        try await sut.clearForSession()
        #expect(cache.clearCount == 2)
    }

    @Test("A registered clearable clears exactly once per teardown", arguments: TestTeardownReason.allCases)
    func clearsOncePerTeardown(reason: TestTeardownReason) async {
        let (sut, cache) = makeSUT()
        let manager = SessionManager(initialClearables: [])
        await manager.register(sut)
        await manager.teardown(reason: reason.reason)
        #expect(cache.clearCount == 1)
    }

    @Test("A throwing sibling registered first does not stop the clear")
    func throwingSiblingBefore() async {
        let (sut, cache) = makeSUT()
        let failing = MockSessionClearable()
        failing.configureToThrow(true)
        let manager = SessionManager(initialClearables: [])
        await manager.register(failing)
        await manager.register(sut)
        await manager.teardown(reason: .userLogout)
        #expect(failing.wasClearCalled)
        #expect(cache.clearCount == 1)
    }

    @Test("A throwing sibling registered after is still reached")
    func throwingSiblingAfter() async {
        let (sut, cache) = makeSUT()
        let failing = MockSessionClearable()
        failing.configureToThrow(true)
        let manager = SessionManager(initialClearables: [])
        await manager.register(sut)
        await manager.register(failing)
        await manager.teardown(reason: .sessionExpired)
        #expect(cache.clearCount == 1)
        #expect(failing.wasClearCalled)
    }
}
