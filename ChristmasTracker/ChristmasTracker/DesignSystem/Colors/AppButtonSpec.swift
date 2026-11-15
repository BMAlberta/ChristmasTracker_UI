//
//  AppButtonSpec.swift
//  ChristmasTracker
//
//  The pure button contract (no SwiftUI). Lives under DesignSystem/Colors because it names the
//  accent token, which the surface scans only allow in that folder.
//
//  Primary actions use PrimaryButtonStyle (capsule, primary fill, a contrast-tested label).
//  Secondary actions are `.bordered` and inherit the app tint. Destructive actions are `.bordered`
//  with the accent tint and the destructive role, never filled.
//

import CoreGraphics

nonisolated enum AppButtonKind: CaseIterable, Sendable {
    case primary, secondary, destructive
}

nonisolated enum AppButtonAppearance: Equatable, Sendable {
    case customPrimary
    case bordered
}

nonisolated struct AppButtonSpec: Equatable, Sendable {
    let appearance: AppButtonAppearance
    let tint: ThemeToken
    let isDestructiveRole: Bool
}

extension AppButtonKind {
    nonisolated var spec: AppButtonSpec {
        switch self {
        case .primary:
            return AppButtonSpec(appearance: .customPrimary, tint: .primary, isDestructiveRole: false)
        case .secondary:
            return AppButtonSpec(appearance: .bordered, tint: .primary, isDestructiveRole: false)
        case .destructive:
            return AppButtonSpec(appearance: .bordered, tint: .accent, isDestructiveRole: true)
        }
    }
}

/// The label color on the primary fill, per mode. Light: white on #1F4D3A (9.6:1).
/// Dark: the dark background token on #4FA58A (6.0:1), because white would fall under 4.5:1.
/// Taken from the status label table so the pair stays in one place.
nonisolated enum PrimaryButtonLabelTable {
    static let minimumHeight: CGFloat = 44

    static func label(mode: ThemeMode) -> ThemeLabel {
        ThemeStatusLabelTable.label(onFill: .primary, mode: mode)
    }
}
