// UpdateSequence.swift
// ChristmasTracker
//
// Shared counter that orders policy results and 426 responses against each other.

import Foundation

@MainActor
final class UpdateSequence {
    private var value = 0

    init() {}

    func next() -> Int {
        value += 1
        return value
    }
}
