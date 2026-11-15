//
//  ThemeTokenTable.swift
//  ChristmasTracker
//
//  The theme's color tokens as pure data: the colorset name for each token, the expected sRGB
//  value in light and dark, and the pill label color chosen for each status fill. Tests compare
//  these tables with the asset catalog and measure contrast from them.
//

import Foundation

nonisolated enum ThemeMode: CaseIterable, Sendable {
    case light
    case dark
}

nonisolated enum ThemeToken: String, CaseIterable, Sendable {
    case primary
    case accent
    case highlight
    case backgroundPrimary
    case backgroundSecondary
    case surface
    case textPrimary
    case textMuted
    case border
    case statusAvailable
    case statusPurchased
    case statusPartial
    case statusShipped
    case statusWrapped
    case statusGifted
    case budgetSafe
    case budgetWarning
    case budgetOver
    case highlightStrong
    case budgetWarningBar

    /// The asset catalog colorset that holds this token.
    var colorsetName: String {
        switch self {
        case .primary: return "primaryColor"
        case .accent: return "accentColor"
        case .highlight: return "highlightColor"
        case .backgroundPrimary: return "backgroundPrimaryColor"
        case .backgroundSecondary: return "backgroundSecondaryColor"
        case .surface: return "surfaceColor"
        case .textPrimary: return "primaryTextColor"
        case .textMuted: return "mutedTextColor"
        case .border: return "borderColor"
        case .statusAvailable: return "statusAvailableColor"
        case .statusPurchased: return "statusPurchasedColor"
        case .statusPartial: return "statusPartialColor"
        case .statusShipped: return "statusShippedColor"
        case .statusWrapped: return "statusWrappedColor"
        case .statusGifted: return "statusGiftedColor"
        case .budgetSafe: return "budgetSafeColor"
        case .budgetWarning: return "budgetWarningColor"
        case .budgetOver: return "budgetOverColor"
        case .highlightStrong: return "highlightStrongColor"
        case .budgetWarningBar: return "budgetWarningBarColor"
        }
    }
}

nonisolated enum ThemeTokenTable {

    /// The theme's values (light hex, dark hex) per token.
    private static func hex(_ token: ThemeToken) -> (light: String, dark: String) {
        switch token {
        case .primary: return ("#1F4D3A", "#4FA58A")
        case .accent: return ("#B23A48", "#E8737E")
        case .highlight: return ("#D6B25E", "#E4C76A")
        case .backgroundPrimary: return ("#FAF9F7", "#0F1A17")
        case .backgroundSecondary: return ("#F2EFEA", "#162622")
        case .surface: return ("#FFFFFF", "#1E2E2A")
        case .textPrimary: return ("#1F2933", "#E6ECEA")
        case .textMuted: return ("#656B77", "#9AA5A1")
        case .border: return ("#E2E2E2", "#2C3F3A")
        case .statusAvailable: return ("#1F4D3A", "#4FA58A")
        case .statusPurchased: return ("#2F7F6D", "#63BFA8")
        case .statusPartial: return ("#D6B25E", "#E4C76A")
        case .statusShipped: return ("#3A7CA5", "#6FAED6")
        case .statusWrapped: return ("#B23A48", "#E8737E")
        case .statusGifted: return ("#C9A227", "#F0D97C")
        case .budgetSafe: return ("#1F4D3A", "#4FA58A")
        case .budgetWarning: return ("#D6B25E", "#E4C76A")
        case .budgetOver: return ("#B23A48", "#E8737E")
        case .highlightStrong: return ("#9C7A2E", "#E4C76A")
        case .budgetWarningBar: return ("#9C7A2E", "#E4C76A")
        }
    }

    static func rgb(_ token: ThemeToken, _ mode: ThemeMode) -> ThemeRGB {
        let pair = hex(token)
        let text: String
        switch mode {
        case .light: text = pair.light
        case .dark: text = pair.dark
        }
        return ThemeRGB(hex: text) ?? ThemeRGB(red: 0, green: 0, blue: 0)
    }
}

/// Which status fills need a graphic edge: the light fills that fall under 3:1 against BOTH
/// `backgroundPrimary` and `surface`. Computed from `ThemeTokenTable`, never hard-coded.
nonisolated enum ThemeEdgeRule {

    /// The contrast a graphic needs against its surroundings.
    static let graphicThreshold = 3.0

    static func fillsNeedingEdge() -> Set<ThemeToken> {
        let page = ThemeTokenTable.rgb(.backgroundPrimary, .light)
        let card = ThemeTokenTable.rgb(.surface, .light)
        var result: Set<ThemeToken> = []
        for kind in StatusKind.allCases {
            let fill = StatusStyle.style(for: kind).fill
            let rgb = ThemeTokenTable.rgb(fill, .light)
            if ThemeContrast.ratio(rgb, page) < graphicThreshold,
               ThemeContrast.ratio(rgb, card) < graphicThreshold {
                result.insert(fill)
            }
        }
        return result
    }
}

/// The color of a pill label: pure white, or a theme token.
nonisolated enum ThemeLabel: Equatable, Sendable {
    case white
    case token(ThemeToken)
}

/// Which label color sits on which status fill, per mode. Chosen so every pair reaches 4.5:1.
nonisolated enum ThemeStatusLabelTable {

    static func label(onFill fill: ThemeToken, mode: ThemeMode) -> ThemeLabel {
        switch mode {
        case .dark:
            return .token(.backgroundPrimary)
        case .light:
            switch fill {
            case .statusPartial, .statusGifted:
                return .token(.textPrimary)
            default:
                return .white
            }
        }
    }

    /// White is #FFFFFF in both modes.
    static func rgb(_ label: ThemeLabel, _ mode: ThemeMode) -> ThemeRGB {
        switch label {
        case .white: return ThemeRGB(red: 255, green: 255, blue: 255)
        case .token(let token): return ThemeTokenTable.rgb(token, mode)
        }
    }
}
