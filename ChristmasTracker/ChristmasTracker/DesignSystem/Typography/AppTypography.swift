//
//  AppTypography.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI
extension Font {
    // MARK: - System Fonts (Inter/SF Pro)
    static let appLargeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let appTitle1 = Font.system(size: 28, weight: .semibold, design: .default)
    static let appTitle2 = Font.system(size: 22, weight: .semibold, design: .default)
    static let appTitle3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let appHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let appBody = Font.system(size: 17, weight: .regular, design: .default)
    static let appCallout = Font.system(size: 16, weight: .regular, design: .default)
    static let appSubheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let appFootnote = Font.system(size: 13, weight: .regular, design: .default)
    static let appCaption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let appCaption2 = Font.system(size: 11, weight: .regular, design: .default)
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
