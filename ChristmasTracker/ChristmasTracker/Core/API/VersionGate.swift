// VersionGate.swift — VersionOutdatedHandling implementation.
// Stores the latest outdated-version details for downstream UI (I6b).
import Foundation
import TrackerAPI
import Observation

@MainActor
@Observable
final class VersionGate: VersionOutdatedHandling {
    private(set) var latestDetails: VersionOutdatedDetails?
    /// Position of the latest 426 in the shared sequence; 0 until one arrives.
    private(set) var outdatedOrder = 0

    @ObservationIgnored private let sequence: UpdateSequence

    init(sequence: UpdateSequence = UpdateSequence()) {
        self.sequence = sequence
    }

    nonisolated func handleVersionOutdated(_ details: VersionOutdatedDetails) async {
        await MainActor.run {
            self.outdatedOrder = self.sequence.next()
            self.latestDetails = details
        }
    }
}
