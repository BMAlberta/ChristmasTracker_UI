//
//  TypographyToken.swift
//  ChristmasTracker
//
//  The pure typography table: text style, weight and design per token. No point sizes,
//  so every token scales with Dynamic Type.
//

nonisolated enum TypographyTextStyle: String, CaseIterable, Sendable, Equatable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2
}

nonisolated enum TypographyWeight: String, CaseIterable, Sendable, Equatable {
    case regular
    case medium
    case semibold
    case bold
}

nonisolated enum TypographyDesign: String, CaseIterable, Sendable, Equatable {
    case standard
    case serif
}

nonisolated struct TypographySpec: Sendable, Equatable {
    let style: TypographyTextStyle
    let weight: TypographyWeight
    let design: TypographyDesign
}

nonisolated enum TypographyToken: String, CaseIterable, Sendable, Equatable, Hashable {
    case appLargeTitle
    case appTitle1
    case appTitle2
    case appTitle3
    case appHeadline
    case appBody
    case appCallout
    case appSubheadline
    case appFootnote
    case appCaption1
    case appCaption2
    case appBrand

    var spec: TypographySpec {
        switch self {
        case .appLargeTitle: TypographySpec(style: .largeTitle, weight: .bold, design: .standard)
        case .appTitle1: TypographySpec(style: .title, weight: .semibold, design: .standard)
        case .appTitle2: TypographySpec(style: .title2, weight: .semibold, design: .standard)
        case .appTitle3: TypographySpec(style: .title3, weight: .semibold, design: .standard)
        case .appHeadline: TypographySpec(style: .headline, weight: .semibold, design: .standard)
        case .appBody: TypographySpec(style: .body, weight: .regular, design: .standard)
        case .appCallout: TypographySpec(style: .callout, weight: .regular, design: .standard)
        case .appSubheadline: TypographySpec(style: .subheadline, weight: .regular, design: .standard)
        case .appFootnote: TypographySpec(style: .footnote, weight: .regular, design: .standard)
        case .appCaption1: TypographySpec(style: .caption, weight: .regular, design: .standard)
        case .appCaption2: TypographySpec(style: .caption2, weight: .regular, design: .standard)
        case .appBrand: TypographySpec(style: .title, weight: .semibold, design: .serif)
        }
    }
}
