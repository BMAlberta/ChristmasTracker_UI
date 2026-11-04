//
//  AppWindowLevels.swift
//  ChristmasTracker
//
//  Defines UIWindow.Level constants used across the app's overlay windows.
//

import UIKit

extension UIWindow.Level {
    /// Privacy cover window (I2c): above all alerts and sheets.
    /// Matches the hardcoded value in PrivacyCoverWindowAdapter (not modified).
    static let privacyCoverLevel: UIWindow.Level = .alert + 1
    /// Inactivity lock window: above all app content and sheets, below the privacy cover.
    static let inactivityLockLevel: UIWindow.Level = .alert + 0.5
}
