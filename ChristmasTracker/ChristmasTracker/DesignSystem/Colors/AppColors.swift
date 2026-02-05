//
//  AppColors.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    /// Primary brand color (Evergreen)
    /// Light: #1F4D3A, Dark: #4FA58A
    static let primaryColor = Color("primaryColor")
    /// Accent color (Cranberry)
    /// Light: #B23A48, Dark: #E06A75
    static let accentColor = Color("accentColor")
    /// Highlight color (Warm Gold)
    /// Light: #D6B25E, Dark: #E4C76A
    static let highlightColor = Color("highlightColor")
    // MARK: - Background Colors
    /// Primary background color
    /// Light: #FAF9F7, Dark: #0F1A17
    static let backgroundPrimaryColor = Color("backgroundPrimaryColor")
    /// Secondary background color
    /// Light: #F2EFEA, Dark: #162622
    static let backgroundSecondaryColor = Color("backgroundSecondaryColor")
    /// Surface color for cards/modals
    /// Light: #FFFFFF, Dark: #1E2E2A
    static let surfaceColor = Color("surfaceColor")
    // MARK: - Text Colors
    /// Primary text color
    /// Light: #1F2933, Dark: #E6ECEA
    static let textPrimaryColor = Color("primaryTextColor")
    /// Muted text color
    /// Light: #6B7280, Dark: #9AA5A1
    static let textMutedColor = Color("mutedTextColor")
    // MARK: - Border Colors
    /// Border and divider color
    /// Light: #E2E2E2, Dark: #2C3F3A
    static let borderColor = Color("borderColor")
    // MARK: - Status Colors
    static let statusAvailableColor = Color("statusAvailableColor")
    static let statusPurchasedColor = Color("statusPurchasedColor")
    static let statusPartialColor = Color("statusPartialColor")
    static let statusShippedColor = Color("statusShippedColor")
    static let statusWrappedColor = Color("statusWrappedColor")
    static let statusGiftedColor = Color("statusGiftedColor")
}
