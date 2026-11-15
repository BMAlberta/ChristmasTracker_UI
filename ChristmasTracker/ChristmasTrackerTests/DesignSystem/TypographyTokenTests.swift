//
//  TypographyTokenTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T2: the pure TypographyToken table and the Font accessors built from it.
//

import SwiftUI
import Testing
@testable import ChristmasTracker

nonisolated enum TypographyTestSupport {

    /// The expected table from the T2 brief. No point sizes: text style, weight and design only.
    static let expected: [TypographyToken: TypographySpec] = [
        .appLargeTitle: TypographySpec(style: .largeTitle, weight: .bold, design: .standard),
        .appTitle1: TypographySpec(style: .title, weight: .semibold, design: .standard),
        .appTitle2: TypographySpec(style: .title2, weight: .semibold, design: .standard),
        .appTitle3: TypographySpec(style: .title3, weight: .semibold, design: .standard),
        .appHeadline: TypographySpec(style: .headline, weight: .semibold, design: .standard),
        .appBody: TypographySpec(style: .body, weight: .regular, design: .standard),
        .appCallout: TypographySpec(style: .callout, weight: .regular, design: .standard),
        .appSubheadline: TypographySpec(style: .subheadline, weight: .regular, design: .standard),
        .appFootnote: TypographySpec(style: .footnote, weight: .regular, design: .standard),
        .appCaption1: TypographySpec(style: .caption, weight: .regular, design: .standard),
        .appCaption2: TypographySpec(style: .caption2, weight: .regular, design: .standard),
        .appBrand: TypographySpec(style: .title, weight: .semibold, design: .serif)
    ]

    static func textStyle(_ style: TypographyTextStyle) -> Font.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }

    static func semanticFont(_ style: TypographyTextStyle) -> Font {
        switch style {
        case .largeTitle: return Font.largeTitle
        case .title: return Font.title
        case .title2: return Font.title2
        case .title3: return Font.title3
        case .headline: return Font.headline
        case .body: return Font.body
        case .callout: return Font.callout
        case .subheadline: return Font.subheadline
        case .footnote: return Font.footnote
        case .caption: return Font.caption
        case .caption2: return Font.caption2
        }
    }

    static func fontWeight(_ weight: TypographyWeight) -> Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    /// The SwiftUI Font a spec should produce: the semantic style font with a weight for the
    /// standard design, `.system(style, design: .serif, weight:)` for the serif accent.
    static func expectedFont(_ spec: TypographySpec) -> Font {
        let style = textStyle(spec.style)
        let weight = fontWeight(spec.weight)
        switch spec.design {
        case .standard:
            return semanticFont(spec.style).weight(weight)
        case .serif:
            return Font.system(style, design: .serif, weight: weight)
        }
    }

    /// The Font static each token names.
    static func accessor(_ token: TypographyToken) -> Font {
        switch token {
        case .appLargeTitle: return Font.appLargeTitle
        case .appTitle1: return Font.appTitle1
        case .appTitle2: return Font.appTitle2
        case .appTitle3: return Font.appTitle3
        case .appHeadline: return Font.appHeadline
        case .appBody: return Font.appBody
        case .appCallout: return Font.appCallout
        case .appSubheadline: return Font.appSubheadline
        case .appFootnote: return Font.appFootnote
        case .appCaption1: return Font.appCaption1
        case .appCaption2: return Font.appCaption2
        case .appBrand: return Font.appBrand
        }
    }
}

@Suite("TypographyToken table Tests")
struct TypographyTokenTests {

    @Test("There are 12 tokens")
    func tokenCount() {
        #expect(TypographyToken.allCases.count == 12)
    }

    @Test("Raw values are unique")
    func rawValuesUnique() {
        let names = TypographyToken.allCases.map(\.rawValue)
        #expect(Set(names).count == names.count)
    }

    @Test("Every token has an entry in the expected table")
    func tableCoversEveryToken() {
        #expect(Set(TypographyToken.allCases) == Set(TypographyTestSupport.expected.keys))
    }

    @Test("Each token's spec matches the brief", arguments: TypographyToken.allCases)
    func specMatchesBrief(token: TypographyToken) {
        #expect(token.spec == TypographyTestSupport.expected[token], "\(token.rawValue)")
    }

    @Test("The text style table covers all 11 styles")
    func textStyleCount() {
        #expect(TypographyTextStyle.allCases.count == 11)
    }

    @Test("Every token resolves to a text style in the style list", arguments: TypographyToken.allCases)
    func resolvesToTextStyle(token: TypographyToken) {
        #expect(TypographyTextStyle.allCases.contains(token.spec.style), "\(token.rawValue)")
    }

    @Test("A spec carries no point size: exactly style, weight and design")
    func specHasNoSize() {
        let spec = TypographyToken.appBody.spec
        let labels = Mirror(reflecting: spec).children.compactMap(\.label)
        #expect(labels == ["style", "weight", "design"])
    }

    @Test("Heading tokens are semibold or bold, body styles are regular")
    func weightsFollowTheTheme() {
        let headings: [TypographyToken] = [.appLargeTitle, .appTitle1, .appTitle2, .appTitle3, .appHeadline, .appBrand]
        for token in headings {
            #expect([TypographyWeight.semibold, .bold].contains(token.spec.weight), "\(token.rawValue)")
        }
        let bodies: [TypographyToken] = [.appBody, .appCallout, .appSubheadline, .appFootnote, .appCaption1, .appCaption2]
        for token in bodies {
            #expect(token.spec.weight == .regular, "\(token.rawValue)")
        }
    }

    @Test("Only appBrand uses the serif design")
    func onlyBrandIsSerif() {
        for token in TypographyToken.allCases {
            let expectedDesign: TypographyDesign = token == .appBrand ? .serif : .standard
            #expect(token.spec.design == expectedDesign, "\(token.rawValue)")
        }
    }
}

@Suite("Typography Font accessor Tests")
struct TypographyFontAccessorTests {

    @Test("Each Font static equals the Font built from its spec", arguments: TypographyToken.allCases)
    func accessorMatchesSpec(token: TypographyToken) {
        #expect(
            TypographyTestSupport.accessor(token) == TypographyTestSupport.expectedFont(token.spec),
            "\(token.rawValue)"
        )
    }

    @Test("Font.appBody is Font.body with a regular weight")
    func bodyLiteral() {
        #expect(Font.appBody == Font.body.weight(.regular))
    }

    @Test("Font.appBrand is the serif title, semibold")
    func brandLiteral() {
        #expect(Font.appBrand == Font.system(.title, design: .serif, weight: .semibold))
    }
}
