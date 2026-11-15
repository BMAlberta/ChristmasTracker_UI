//
//  LinkPreviewWiring.swift
//  ChristmasTracker
//
//  Builds the LinkPreviewService for the composition root. A failed bootstrap is inert (no network,
//  no mock data); mock mode uses the mock repository; real mode uses the generated client and falls
//  back to inert when there is none.
//

import Foundation
import TrackerAPI

@MainActor
func makeLinkPreviewService(
    mode: APIMode,
    state: BootstrapState,
    client: (any APIProtocol)?
) -> LinkPreviewService {
    guard state == .ready else { return LinkPreviewService(repository: InertLinkPreviewLoader()) }
    switch mode {
    case .mock:
        return LinkPreviewService(repository: MockLinkPreviewRepository())
    case .real:
        guard let client else { return LinkPreviewService(repository: InertLinkPreviewLoader()) }
        return LinkPreviewService(repository: GeneratedClientLinkPreviewRepository(client: client))
    }
}
