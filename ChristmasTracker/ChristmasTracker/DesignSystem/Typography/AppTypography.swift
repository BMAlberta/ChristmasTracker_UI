//
//  AppTypography.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI
extension Font {
    // MARK: - Text-style fonts
    // Every token is built from a text style, so all of them scale with Dynamic Type.
    // The table lives in TypographyToken.
    static let appLargeTitle = Font.largeTitle.weight(.bold)
    static let appTitle1 = Font.title.weight(.semibold)
    static let appTitle2 = Font.title2.weight(.semibold)
    static let appTitle3 = Font.title3.weight(.semibold)
    static let appHeadline = Font.headline.weight(.semibold)
    static let appBody = Font.body.weight(.regular)
    static let appCallout = Font.callout.weight(.regular)
    static let appSubheadline = Font.subheadline.weight(.regular)
    static let appFootnote = Font.footnote.weight(.regular)
    static let appCaption1 = Font.caption.weight(.regular)
    static let appCaption2 = Font.caption2.weight(.regular)

    // MARK: - Serif accent (app name and empty-state titles only); also scales with Dynamic Type
    static let appBrand = Font.system(.title, design: .serif, weight: .semibold)
}
extension Text {
    func appLargeTitle() -> Text {
        self.font(.appLargeTitle)
    }
    
    func appTitle1() -> Text {
        self.font(.appTitle1)
    }
    
    func appTitle2() -> Text {
        self.font(.appTitle2)
    }
    
    func appTitle3() -> Text {
        self.font(.appTitle3)
    }
    
    func appBody() -> Text {
        self.font(.appBody)
    }
    
    func appCaption() -> Text {
        self.font(.appCaption1).foregroundColor(.textMutedColor)
    }
}
