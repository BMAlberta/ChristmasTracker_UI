// UpdateSequenceTests.swift
// ChristmasTrackerTests

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("UpdateSequence")
@MainActor
struct UpdateSequenceTests {

    @Test("next() starts above zero")
    func startsAboveZero() {
        let sut = UpdateSequence()
        #expect(sut.next() > 0)
    }

    @Test("next() is strictly increasing")
    func strictlyIncreasing() {
        let sut = UpdateSequence()
        let first = sut.next()
        let second = sut.next()
        let third = sut.next()
        #expect(second > first)
        #expect(third > second)
    }
}
