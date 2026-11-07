// SessionEndingSeamTests.swift
// ChristmasTrackerTests
//
// Package I2b-2c, story U2: SessionEndingSeam (SessionEnding) forwards the reason to its
// injected closure. Composition through makeClientSeams() is covered in
// ClientSeamsTests.swift.
//
// Package I2b-2d, story E1: the seam is sessionEnded(reason:requestToken:) and forwards
// both values to the closure, init(onSessionEnded: (SessionEndReason, String?) async -> Void).
//
// Fails to compile until the implementer changes Core/API/SessionEndingSeam.swift and the
// package SessionEnding protocol to the E1 signature.

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

// MARK: - ReasonRecorder

private actor ReasonRecorder {
    struct Call: Equatable {
        let reason: SessionEndReason
        let requestToken: String?
    }

    private(set) var calls: [Call] = []
    var reasons: [SessionEndReason] { calls.map(\.reason) }
    var requestTokens: [String?] { calls.map(\.requestToken) }

    func record(_ reason: SessionEndReason, _ requestToken: String?) {
        calls.append(Call(reason: reason, requestToken: requestToken))
    }
}

// MARK: - Suite

@Suite("SessionEndingSeam Tests")
@MainActor
struct SessionEndingSeamTests {

    private func makeSUT(recorder: ReasonRecorder) -> SessionEndingSeam {
        SessionEndingSeam(onSessionEnded: { reason, requestToken in
            await recorder.record(reason, requestToken)
        })
    }

    @Test("sessionEnded(reason: .accountDisabled) calls the closure once with .accountDisabled")
    func forwardsAccountDisabled() async {
        let recorder = ReasonRecorder()
        let sut = makeSUT(recorder: recorder)

        await sut.sessionEnded(reason: .accountDisabled, requestToken: "T1")

        #expect(await recorder.reasons == [.accountDisabled])
    }

    @Test("sessionEnded(reason: .userNotFound) calls the closure once with .userNotFound")
    func forwardsUserNotFound() async {
        let recorder = ReasonRecorder()
        let sut = makeSUT(recorder: recorder)

        await sut.sessionEnded(reason: .userNotFound, requestToken: "T1")

        #expect(await recorder.reasons == [.userNotFound])
    }

    @Test("SessionEndingSeam is usable as the package's any SessionEnding")
    func conformsToSessionEnding() async {
        let recorder = ReasonRecorder()
        let handler: any SessionEnding = makeSUT(recorder: recorder)

        await handler.sessionEnded(reason: .accountDisabled, requestToken: "T1")
        await handler.sessionEnded(reason: .userNotFound, requestToken: "T2")

        #expect(await recorder.reasons == [.accountDisabled, .userNotFound])
    }

    // MARK: - I2b-2d E1: the request token is forwarded unchanged

    @Test("sessionEnded forwards the request token to the closure unchanged")
    func forwardsRequestToken() async {
        let recorder = ReasonRecorder()
        let sut = makeSUT(recorder: recorder)

        await sut.sessionEnded(reason: .accountDisabled, requestToken: "T1")

        #expect(await recorder.calls == [.init(reason: .accountDisabled, requestToken: "T1")])
    }

    @Test("sessionEnded forwards a nil request token to the closure as nil")
    func forwardsNilRequestToken() async {
        let recorder = ReasonRecorder()
        let sut = makeSUT(recorder: recorder)

        await sut.sessionEnded(reason: .userNotFound, requestToken: nil)

        #expect(await recorder.calls == [.init(reason: .userNotFound, requestToken: nil)])
    }

    @Test("Through any SessionEnding, each call forwards its own reason and token, in order")
    func forwardsEachCallInOrder() async {
        let recorder = ReasonRecorder()
        let handler: any SessionEnding = makeSUT(recorder: recorder)

        await handler.sessionEnded(reason: .accountDisabled, requestToken: "T1")
        await handler.sessionEnded(reason: .userNotFound, requestToken: nil)
        await handler.sessionEnded(reason: .accountDisabled, requestToken: "T2")

        #expect(await recorder.requestTokens == ["T1", nil, "T2"])
    }
}
