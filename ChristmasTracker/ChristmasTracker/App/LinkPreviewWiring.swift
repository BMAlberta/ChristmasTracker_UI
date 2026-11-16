//
//  LinkPreviewWiring.swift
//  ChristmasTracker
//
//  Builds the LinkPreviewService for the composition root. A failed bootstrap is inert (no network,
//  no mock data); mock mode uses the mock repository and the mock image provider; real mode uses the
//  generated client and the on-device LinkPresentation provider, and falls back to inert when there
//  is no client.
//

import Foundation
import TrackerAPI

@MainActor
func makeLinkPreviewService(
    mode: APIMode,
    state: BootstrapState,
    client: (any APIProtocol)?
) -> LinkPreviewService {
    guard state == .ready else { return inertLinkPreviewService() }
    switch mode {
    case .mock:
        return LinkPreviewService(repository: MockLinkPreviewRepository(), provider: MockProductImageProvider())
    case .real:
        guard let client else { return inertLinkPreviewService() }
        return LinkPreviewService(
            repository: GeneratedClientLinkPreviewRepository(client: client),
            provider: LinkPresentationProductImageProvider()
        )
    }
}

@MainActor
private func inertLinkPreviewService() -> LinkPreviewService {
    LinkPreviewService(repository: InertLinkPreviewLoader(), provider: InertProductImageProvider())
}
