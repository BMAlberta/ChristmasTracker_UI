//
//  ThemeTestSupport.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: shared helpers for the theme tests. Holds the independent expected token table
//  (hard-coded from the epic brief), a reader for the asset catalog JSON on disk (located from
//  #filePath the same way ItemSourceTree does), and the list of contrast pairs measured from the
//  catalog values.
//

import Foundation
@testable import ChristmasTracker

// MARK: - Expected values

nonisolated enum ThemeTestSupport {

    /// The brief's values, written out independently of ThemeTokenTable so a wrong table is caught.
    static let expectedHex: [ThemeToken: (light: String, dark: String)] = [
        .primary: ("#1F4D3A", "#4FA58A"),
        .accent: ("#B23A48", "#E06A75"),
        .highlight: ("#D6B25E", "#E4C76A"),
        .backgroundPrimary: ("#FAF9F7", "#0F1A17"),
        .backgroundSecondary: ("#F2EFEA", "#162622"),
        .surface: ("#FFFFFF", "#1E2E2A"),
        .textPrimary: ("#1F2933", "#E6ECEA"),
        .textMuted: ("#6B7280", "#9AA5A1"),
        .border: ("#E2E2E2", "#2C3F3A"),
        .statusAvailable: ("#1F4D3A", "#4FA58A"),
        .statusPurchased: ("#2F7F6D", "#63BFA8"),
        .statusPartial: ("#D6B25E", "#E4C76A"),
        .statusShipped: ("#3A7CA5", "#6FAED6"),
        .statusWrapped: ("#B23A48", "#E06A75"),
        .statusGifted: ("#C9A227", "#F0D97C"),
        .budgetSafe: ("#1F4D3A", "#4FA58A"),
        .budgetWarning: ("#D6B25E", "#E4C76A"),
        .budgetOver: ("#B23A48", "#E06A75")
    ]

    static let expectedColorsetNames: [ThemeToken: String] = [
        .primary: "primaryColor",
        .accent: "accentColor",
        .highlight: "highlightColor",
        .backgroundPrimary: "backgroundPrimaryColor",
        .backgroundSecondary: "backgroundSecondaryColor",
        .surface: "surfaceColor",
        .textPrimary: "primaryTextColor",
        .textMuted: "mutedTextColor",
        .border: "borderColor",
        .statusAvailable: "statusAvailableColor",
        .statusPurchased: "statusPurchasedColor",
        .statusPartial: "statusPartialColor",
        .statusShipped: "statusShippedColor",
        .statusWrapped: "statusWrappedColor",
        .statusGifted: "statusGiftedColor",
        .budgetSafe: "budgetSafeColor",
        .budgetWarning: "budgetWarningColor",
        .budgetOver: "budgetOverColor"
    ]

    static func expectedHex(_ token: ThemeToken, _ mode: ThemeMode) -> String {
        guard let pair = expectedHex[token] else { return "" }
        switch mode {
        case .light: return pair.light
        case .dark: return pair.dark
        }
    }

    static func expectedRGB(_ token: ThemeToken, _ mode: ThemeMode) -> ThemeRGB {
        ThemeRGB(hex: expectedHex(token, mode)) ?? ThemeRGB(red: 0, green: 0, blue: 0)
    }

    static func modeName(_ mode: ThemeMode) -> String {
        switch mode {
        case .light: return "light"
        case .dark: return "dark"
        }
    }

    static func labelName(_ label: ThemeLabel) -> String {
        switch label {
        case .white: return "white"
        case .token(let token): return token.rawValue
        }
    }

    static let statusFills: [ThemeToken] = [
        .statusAvailable, .statusPurchased, .statusPartial, .statusShipped, .statusWrapped, .statusGifted
    ]

    static let budgetFills: [ThemeToken] = [.budgetSafe, .budgetWarning, .budgetOver]
}

// MARK: - Asset catalog reader

nonisolated struct ThemeCatalogError: Error, CustomStringConvertible {
    let description: String
}

nonisolated struct ThemeCatalog: Sendable {

    struct Entry: Sendable {
        let light: ThemeRGB
        let dark: ThemeRGB
    }

    /// Colorset name (directory name without ".colorset") to its Contents.json.
    let colorsets: [String: URL]

    static func load(from file: String) throws -> ThemeCatalog {
        guard let tree = ItemSourceTree.load(from: file) else {
            throw ThemeCatalogError(description: "source tree not found from \(file)")
        }
        let assets = tree.root.appendingPathComponent("Assets.xcassets", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(at: assets, includingPropertiesForKeys: nil) else {
            throw ThemeCatalogError(description: "Assets.xcassets not found at \(assets.path)")
        }
        var found: [String: URL] = [:]
        for case let url as URL in enumerator where url.pathExtension == "colorset" {
            found[url.deletingPathExtension().lastPathComponent] = url.appendingPathComponent("Contents.json")
        }
        return ThemeCatalog(colorsets: found)
    }

    func entry(_ name: String) throws -> Entry {
        guard let url = colorsets[name] else {
            throw ThemeCatalogError(description: "colorset \(name) not found")
        }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = object["colors"] as? [[String: Any]] else {
            throw ThemeCatalogError(description: "\(name): Contents.json has no colors array")
        }
        var light: ThemeRGB?
        var dark: ThemeRGB?
        var fallbackCount = 0
        for color in colors {
            let appearances = color["appearances"] as? [[String: Any]] ?? []
            if appearances.isEmpty {
                fallbackCount += 1
                continue
            }
            guard appearances.count == 1,
                  appearances[0]["appearance"] as? String == "luminosity",
                  let value = appearances[0]["value"] as? String else {
                throw ThemeCatalogError(description: "\(name): unexpected appearance entry")
            }
            let rgb = try Self.parseColor(color, name: name)
            switch value {
            case "light":
                guard light == nil else { throw ThemeCatalogError(description: "\(name): two light entries") }
                light = rgb
            case "dark":
                guard dark == nil else { throw ThemeCatalogError(description: "\(name): two dark entries") }
                dark = rgb
            default:
                throw ThemeCatalogError(description: "\(name): unexpected luminosity \(value)")
            }
        }
        guard fallbackCount == 1 else {
            throw ThemeCatalogError(description: "\(name): expected exactly one fallback entry, found \(fallbackCount)")
        }
        guard let light, let dark else {
            throw ThemeCatalogError(description: "\(name): missing light or dark entry")
        }
        return Entry(light: light, dark: dark)
    }

    func rgb(_ token: ThemeToken, _ mode: ThemeMode) throws -> ThemeRGB {
        let loaded = try entry(token.colorsetName)
        switch mode {
        case .light: return loaded.light
        case .dark: return loaded.dark
        }
    }

    // MARK: Parsing

    private static func parseColor(_ color: [String: Any], name: String) throws -> ThemeRGB {
        guard let body = color["color"] as? [String: Any] else {
            throw ThemeCatalogError(description: "\(name): entry has no color")
        }
        guard body["color-space"] as? String == "srgb" else {
            throw ThemeCatalogError(description: "\(name): color-space is not srgb")
        }
        guard let components = body["components"] as? [String: Any],
              let red = components["red"], let green = components["green"],
              let blue = components["blue"], let alpha = components["alpha"] else {
            throw ThemeCatalogError(description: "\(name): missing components")
        }
        guard try alphaValue(alpha, name: name) == 1.0 else {
            throw ThemeCatalogError(description: "\(name): alpha is not 1")
        }
        return ThemeRGB(
            red: try component(red, name: name),
            green: try component(green, name: name),
            blue: try component(blue, name: name)
        )
    }

    /// "0x4F" hex, "32" decimal integer, or a 0...1 float written with a decimal point ("0.31", 0.31).
    /// A bare JSON number with no fractional part is read as an integer.
    private static func component(_ raw: Any, name: String) throws -> Int {
        if let text = raw as? String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("0x") {
                guard let value = Int(trimmed.dropFirst(2), radix: 16), (0...255).contains(value) else {
                    throw ThemeCatalogError(description: "\(name): bad hex component \(text)")
                }
                return value
            }
            if trimmed.contains(".") {
                guard let value = Double(trimmed), value >= 0, value <= 1.0 else {
                    throw ThemeCatalogError(description: "\(name): bad float component \(text)")
                }
                return Int((value * 255).rounded())
            }
            guard let value = Int(trimmed), (0...255).contains(value) else {
                throw ThemeCatalogError(description: "\(name): bad integer component \(text)")
            }
            return value
        }
        if let number = raw as? NSNumber {
            let value = number.doubleValue
            if value != value.rounded() {
                guard value >= 0, value <= 1.0 else {
                    throw ThemeCatalogError(description: "\(name): bad float component \(value)")
                }
                return Int((value * 255).rounded())
            }
            guard (0...255).contains(Int(value)) else {
                throw ThemeCatalogError(description: "\(name): bad integer component \(value)")
            }
            return Int(value)
        }
        throw ThemeCatalogError(description: "\(name): unsupported component type")
    }

    private static func alphaValue(_ raw: Any, name: String) throws -> Double {
        if let text = raw as? String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("0x") {
                guard let value = Int(trimmed.dropFirst(2), radix: 16) else {
                    throw ThemeCatalogError(description: "\(name): bad alpha \(text)")
                }
                return Double(value) / 255.0
            }
            guard let value = Double(trimmed) else {
                throw ThemeCatalogError(description: "\(name): bad alpha \(text)")
            }
            return value
        }
        if let number = raw as? NSNumber { return number.doubleValue }
        throw ThemeCatalogError(description: "\(name): unsupported alpha type")
    }
}

// MARK: - Contrast pairs

nonisolated enum ThemePairKind: String, Sendable {
    case text
    case graphic
    case supplementary
}

nonisolated struct ThemePairMeasurement: Sendable {
    let mode: String
    let foreground: String
    let background: String
    let kind: ThemePairKind
    let ratio: Double

    var description: String {
        "\(foreground) on \(background) in \(mode) (\(kind.rawValue)): \(String(format: "%.2f", ratio))"
    }

    var tableLine: String {
        "CONTRAST|\(mode)|\(foreground)|\(background)|\(String(format: "%.2f", ratio))|\(kind.rawValue)"
    }
}

nonisolated enum ThemePairs {

    /// Number of pairs measured per mode: 18 text, 2 graphic, 18 supplementary.
    static let pairsPerMode = 38

    /// Every pair from the brief, measured from the colorset files (not from ThemeTokenTable).
    static func measureAll(_ catalog: ThemeCatalog) throws -> [ThemePairMeasurement] {
        var result: [ThemePairMeasurement] = []
        for mode in ThemeMode.allCases {
            let modeName = ThemeTestSupport.modeName(mode)

            func add(_ foreground: String, _ fg: ThemeRGB, _ background: ThemeToken, _ kind: ThemePairKind) throws {
                let bg = try catalog.rgb(background, mode)
                result.append(ThemePairMeasurement(
                    mode: modeName, foreground: foreground, background: background.rawValue,
                    kind: kind, ratio: ThemeContrast.ratio(fg, bg)))
            }

            // TEXT
            for foreground in [ThemeToken.textPrimary, .textMuted] {
                let fg = try catalog.rgb(foreground, mode)
                for background in [ThemeToken.backgroundPrimary, .backgroundSecondary, .surface] {
                    try add(foreground.rawValue, fg, background, .text)
                }
            }
            for foreground in [ThemeToken.accent, .primary, .budgetOver] {
                let fg = try catalog.rgb(foreground, mode)
                for background in [ThemeToken.backgroundPrimary, .surface] {
                    try add(foreground.rawValue, fg, background, .text)
                }
            }
            for fill in ThemeTestSupport.statusFills {
                let label = ThemeStatusLabelTable.label(onFill: fill, mode: mode)
                let labelRGB: ThemeRGB
                switch label {
                case .white: labelRGB = ThemeStatusLabelTable.rgb(.white, mode)
                case .token(let token): labelRGB = try catalog.rgb(token, mode)
                }
                try add(ThemeTestSupport.labelName(label), labelRGB, fill, .text)
            }

            // GRAPHIC
            let primary = try catalog.rgb(.primary, mode)
            for background in [ThemeToken.surface, .backgroundPrimary] {
                try add(ThemeToken.primary.rawValue, primary, background, .graphic)
            }

            // SUPPLEMENTARY GRAPHIC
            for fill in ThemeTestSupport.statusFills + ThemeTestSupport.budgetFills {
                let fg = try catalog.rgb(fill, mode)
                for background in [ThemeToken.surface, .backgroundPrimary] {
                    try add(fill.rawValue, fg, background, .supplementary)
                }
            }
        }
        return result
    }
}
