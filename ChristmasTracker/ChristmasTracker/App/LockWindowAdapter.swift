//
//  LockWindowAdapter.swift
//  ChristmasTracker
//
//  Thin UIKit adapter that shows the inactivity lock screen in a dedicated UIWindow.
//  MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
//  This is the only untested piece; it is verified manually.
//

@preconcurrency import UIKit
import SwiftUI

/// Shows and hides the inactivity lock window above all app content but below the
/// privacy cover window.
internal final class LockWindowAdapter {

    private weak var scene: UIWindowScene?
    private var lockWindow: UIWindow?

    init(scene: UIWindowScene) {
        self.scene = scene
    }

    func showLock(
        controller: InactivityLockController,
        biometricAuthenticator: any BiometricAuthenticating
    ) {
        guard lockWindow == nil, let scene else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .inactivityLockLevel

        let rootView = LockView(controller: controller, biometricAuthenticator: biometricAuthenticator)
        let hostingController = UIHostingController(rootView: rootView)
        window.rootViewController = hostingController

        window.isHidden = false
        lockWindow = window
    }

    func hideLock() {
        lockWindow?.isHidden = true
        lockWindow?.rootViewController = nil
        lockWindow = nil
    }
}
