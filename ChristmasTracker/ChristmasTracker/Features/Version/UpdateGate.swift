// UpdateGate.swift
// ChristmasTracker
//
// The one pure answer to "what should the update UI show": none, recommended, or required.
// The server decides the state; nothing here compares app versions.

import Foundation
import TrackerAPI

nonisolated struct RequiredUpdate: Equatable, Sendable {
    let minimumVersion: String
    let minimumBuild: Int?
    let manifest: String?
    let releaseNotes: String?

    init(minimumVersion: String, minimumBuild: Int?, manifest: String?, releaseNotes: String?) {
        self.minimumVersion = minimumVersion
        self.minimumBuild = minimumBuild
        self.manifest = manifest
        self.releaseNotes = releaseNotes
    }
}

nonisolated struct UpdateGate {
    enum Decision {
        case none
        case recommended(VersionPolicy)
        case required(RequiredUpdate)
    }

    /// A source is a policy with state != ok, or a 426. The newer source wins; a 426 whose order
    /// is at least the policy order is required. A dismissed latestVersion hides recommended only.
    static func decide(
        policy: VersionPolicy?,
        policyOrder: Int,
        outdated: VersionOutdatedDetails?,
        outdatedOrder: Int,
        dismissedLatestVersion: String?
    ) -> Decision {
        // Pattern match: `policy == nil` would need VersionPolicy's main-actor Equatable.
        let policyIsAbsent: Bool
        if case .some = policy { policyIsAbsent = false } else { policyIsAbsent = true }
        if let outdated, policyIsAbsent || outdatedOrder >= policyOrder {
            return .required(RequiredUpdate(
                minimumVersion: outdated.minimumVersion,
                minimumBuild: outdated.minimumBuild,
                manifest: outdated.manifestUrl,
                releaseNotes: nil
            ))
        }
        guard let policy else { return .none }
        switch policy.state {
        case .ok:
            return .none
        case .forceUpdate:
            return .required(RequiredUpdate(
                minimumVersion: policy.minimumVersion,
                minimumBuild: policy.minimumBuild,
                manifest: policy.manifestURL?.absoluteString,
                releaseNotes: policy.releaseNotes
            ))
        case .updateRecommended:
            if dismissedLatestVersion == policy.latestVersion { return .none }
            return .recommended(policy)
        }
    }
}
