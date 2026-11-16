//
//  EnvironmentValues+LinkPreviewService.swift
//  ChristmasTracker
//
//  The environment default is built from the inert loader: a view that reads the service without
//  the app injecting one always gets "no image", never fake data and never a network call.
//

import SwiftUI

private struct LinkPreviewServiceKey: EnvironmentKey {
    static let defaultValue: LinkPreviewService = LinkPreviewService(repository: InertLinkPreviewLoader())
}

extension EnvironmentValues {
    var linkPreviewService: LinkPreviewService {
        get { self[LinkPreviewServiceKey.self] }
        set { self[LinkPreviewServiceKey.self] = newValue }
    }
}
