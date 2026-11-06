// VersionGate.swift — VersionOutdatedHandling implementation.
// Stores the latest outdated-version details for downstream UI (I6b).
import Foundation
import TrackerAPI
import Observation

@MainActor
@Observable
final class VersionGate: VersionOutdatedHandling {
    private(set) var latestDetails: VersionOutdatedDetails?

    nonisolated func handleVersionOutdated(_ details: VersionOutdatedDetails) async {
        await MainActor.run {
            self.latestDetails = details
        }
    }
}
