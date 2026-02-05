//
//  AppSpacing.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI
enum AppSpacing {
    /// Extra small: 4pt
    static let xs: CGFloat = 4
    /// Small: 8pt
    static let sm: CGFloat = 8
    /// Medium: 12pt
    static let md: CGFloat = 12
    /// Large: 16pt
    static let lg: CGFloat = 16
    /// Extra large: 24pt
    static let xl: CGFloat = 24
    /// 2X large: 32pt
    static let xxl: CGFloat = 32
    /// 3X large: 48pt
    static let xxxl: CGFloat = 48
}
extension EdgeInsets {
    /// Standard card padding (16pt all sides)
    static let appCardPadding = EdgeInsets(
        top: AppSpacing.lg,
        leading: AppSpacing.lg,
        bottom: AppSpacing.lg,
        trailing: AppSpacing.lg
    )
    /// Standard screen padding (24pt vertical, 16pt horizontal)
    static let appScreenPadding = EdgeInsets(
        top: AppSpacing.xl,
        leading: AppSpacing.lg,
        bottom: AppSpacing.xl,
        trailing: AppSpacing.lg
    )
}
