//
//  DestructiveAction.swift
//  ChristmasTracker
//
//  Shared mapping for destructive controls: every kind of destructive action uses the one
//  destructive colour token, so a view never picks accent or nothing for a red control.
//

import SwiftUI

nonisolated enum DestructiveActionKind: CaseIterable, Sendable {
    case archive, delete, remove, leave, clear
}

extension DestructiveActionKind {
    var color: Color { Color.destructiveColor }
}

extension View {
    /// Tints a destructive control (button, swipe action, dialog button) with the destructive token.
    func destructiveTint() -> some View {
        tint(Color.destructiveColor)
    }
}
