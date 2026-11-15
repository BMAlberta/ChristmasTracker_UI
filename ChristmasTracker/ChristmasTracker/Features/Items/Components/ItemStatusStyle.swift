//
//  ItemStatusStyle.swift
//  ChristmasTracker
//
//  TH1-T3: the status style layer. `StatusKind` is the theme's six statuses; `StatusStyle` is the
//  pure description of one (fill token, words, label color per mode). The label colors come from
//  `ThemeStatusLabelTable`, which the contrast tests measure. The Color mapping at the bottom is the
//  only place a ThemeToken or ThemeLabel becomes a SwiftUI Color, and the only place `.white` is used.
//

import SwiftUI

/// The six statuses the theme styles. Item statuses map in; of the shipping statuses only `shipped` does.
nonisolated enum StatusKind: CaseIterable, Equatable, Hashable, Sendable {
    case available
    case partial
    case purchased
    case shipped
    case wrapped
    case gifted

    init(_ status: ItemStatus) {
        switch status {
        case .available: self = .available
        case .partial: self = .partial
        case .purchased: self = .purchased
        case .wrapped: self = .wrapped
        case .gifted: self = .gifted
        }
    }

    init?(shipping status: PurchaseShippingStatus) {
        switch status {
        case .shipped: self = .shipped
        default: return nil
        }
    }
}

/// How one status looks and reads: the fill token, the short label and the accessibility label.
nonisolated struct StatusStyle: Equatable, Sendable {
    let kind: StatusKind
    let fill: ThemeToken
    let shortLabel: String
    let accessibilityLabel: String

    /// The label color on the fill for a mode, from the contrast-tested table.
    func label(for mode: ThemeMode) -> ThemeLabel {
        ThemeStatusLabelTable.label(onFill: fill, mode: mode)
    }

    static func style(for kind: StatusKind) -> StatusStyle {
        let fill: ThemeToken
        let words: String
        switch kind {
        case .available: (fill, words) = (.statusAvailable, "Available")
        case .partial: (fill, words) = (.statusPartial, "Partial")
        case .purchased: (fill, words) = (.statusPurchased, "Purchased")
        case .shipped: (fill, words) = (.statusShipped, "Shipped")
        case .wrapped: (fill, words) = (.statusWrapped, "Wrapped")
        case .gifted: (fill, words) = (.statusGifted, "Gifted")
        }
        return StatusStyle(kind: kind, fill: fill, shortLabel: words, accessibilityLabel: "Status: \(words)")
    }
}

// MARK: - Color mapping (the only place tokens become SwiftUI Colors)

extension Color {
    init(token: ThemeToken) {
        switch token {
        case .primary: self = .primaryColor
        case .accent: self = .accentColor
        case .highlight: self = .highlightColor
        case .backgroundPrimary: self = .backgroundPrimaryColor
        case .backgroundSecondary: self = .backgroundSecondaryColor
        case .surface: self = .surfaceColor
        case .textPrimary: self = .textPrimaryColor
        case .textMuted: self = .textMutedColor
        case .border: self = .borderColor
        case .statusAvailable: self = .statusAvailableColor
        case .statusPurchased: self = .statusPurchasedColor
        case .statusPartial: self = .statusPartialColor
        case .statusShipped: self = .statusShippedColor
        case .statusWrapped: self = .statusWrappedColor
        case .statusGifted: self = .statusGiftedColor
        case .budgetSafe: self = .budgetSafeColor
        case .budgetWarning: self = .budgetWarningColor
        case .budgetOver: self = .budgetOverColor
        case .highlightStrong: self = .highlightStrongColor
        case .budgetWarningBar: self = .budgetWarningBarColor
        }
    }

    init(label: ThemeLabel) {
        switch label {
        case .white: self = .white
        case .token(let token): self.init(token: token)
        }
    }
}

extension Color {
    /// The budget token color of a level (bars and graphics; not for small text).
    static func budget(level: BudgetLevel) -> Color {
        Color(token: BudgetStateStyle.style(for: level).token)
    }
}

extension ColorScheme {
    /// The theme mode that matches this color scheme.
    var themeMode: ThemeMode {
        switch self {
        case .dark: return .dark
        default: return .light
        }
    }
}
