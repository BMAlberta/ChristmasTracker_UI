//
//  DismissedLoads.swift
//  ChristmasTracker
//
//  UX1a Story U3: which load sources the user dismissed. A failure of a dismissed source stays hidden
//  until the screen resets the value (when a new load of that screen starts or the screen disappears).
//

import Foundation

nonisolated struct DismissedLoads: Sendable, Equatable {
    private var sources: Set<LoadSource> = []

    init() {}

    mutating func dismiss(_ sources: [LoadSource]) {
        self.sources.formUnion(sources)
    }

    mutating func reset() {
        sources.removeAll()
    }

    /// Shows the failures of just these sources again (their next load started).
    mutating func reset(_ sources: [LoadSource]) {
        self.sources.subtract(sources)
    }

    func visible(_ failures: [LoadFailure]) -> [LoadFailure] {
        failures.filter { !sources.contains($0.source) }
    }
}
