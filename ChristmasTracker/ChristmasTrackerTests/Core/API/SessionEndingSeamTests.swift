// SessionEndingSeamTests.swift
// ChristmasTrackerTests
//
// Package I2b-2c, story U2: SessionEndingSeam (SessionEnding) forwards the reason to its
// injected closure. Composition through makeClientSeams() is covered in
// ClientSeamsTests.swift.
//
// Fails to compile until the implementer adds Core/API/SessionEndingSeam.swift and the
// package SessionEnding / SessionEndReason types.

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

// MARK: - ReasonRecorder

private actor ReasonRecorder {
    private(set) var reasons: [SessionEndReason] = []
    func record(_ reason: SessionEndReason) { reasons.append(reason) }
}

// MARK: - Suite

@Suite("SessionEndingSeam Tests")
@MainActor
struct SessionEndingSeamTests {

    private func makeSUT(recorder: ReasonRecorder) -> SessionEndingSeam {
        SessionEndingSeam(onSessionEnded: { reason in
            await recorder.record(reason)
        })
    }

    @Test("sessionEnded(reason: .accountDisabled) calls the closure once with .accountDisabled")
    func forwardsAccountDisabled() async {
        let recorder = ReasonRecorder()
        let sut = makeSUT(recorder: recorder)

        await sut.sessionEnded(reason: .accountDisabled)

        #expect(await recorder.reasons == [.accountDisabled])
    }

    @Test("sessionEnded(reason: .userNotFound) calls the closure once with .userNotFound")
    func forwardsUserNotFound() async {
        let recorder = ReasonRecorder()
        let sut = makeSUT(recorder: recorder)

        await sut.sessionEnded(reason: .userNotFound)

        #expect(await recorder.reasons == [.userNotFound])
    }

    @Test("SessionEndingSeam is usable as the package's any SessionEnding")
    func conformsToSessionEnding() async {
        let recorder = ReasonRecorder()
        let handler: any SessionEnding = makeSUT(recorder: recorder)

        await handler.sessionEnded(reason: .accountDisabled)
        await handler.sessionEnded(reason: .userNotFound)

        #expect(await recorder.reasons == [.accountDisabled, .userNotFound])
    }
}
