//
//  PrivacyCoverWindowAdapter.swift
//  ChristmasTracker
//

import UIKit
import SwiftUI

// UIKit adapter that shows the privacy cover in a dedicated UIWindow.
// This is the only untested piece; it is verified manually.
// MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
final class PrivacyCoverWindowAdapter: PrivacyCoverPresenting {

    private weak var scene: UIWindowScene?
    private var coverWindow: UIWindow?

    init(scene: UIWindowScene) {
        self.scene = scene
    }

    func showCover() {
        guard coverWindow == nil, let scene else { return }

        let window = UIWindow(windowScene: scene)
        // Above .alert (2000.0) so the cover appears over sheets, alerts, and all other windows.
        window.windowLevel = UIWindow.Level.alert + 1
        window.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: PrivacyCoverView())
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController

        // Show without animation (snapshot must capture the cover) and without
        // making the cover window key (the app's main window must remain key).
        window.isHidden = false
        coverWindow = window
    }

    func hideCover() {
        coverWindow = nil
    }
}
