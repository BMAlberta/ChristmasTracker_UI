//
//  DestructiveActionKindTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B2: destructive controls had no shared token mapping (each view picked accent or
//  nothing). Covers DestructiveActionKind (five kinds) and its mapping to the destructive colour token.
//

import Testing
import SwiftUI
@testable import ChristmasTracker

@Suite("DestructiveActionKind Tests")
struct DestructiveActionKindTests {

    @Test("There are exactly five destructive action kinds")
    func fiveKinds() {
        #expect(DestructiveActionKind.allCases.count == 5)
    }

    @Test("The kinds are archive, delete, remove, leave and clear")
    func kindNames() {
        let names = Set(DestructiveActionKind.allCases.map { "\($0)" })
        #expect(names == ["archive", "delete", "remove", "leave", "clear"])
    }

    @Test("Every kind maps to the destructive colour token", arguments: DestructiveActionKind.allCases)
    func everyKindUsesTheToken(kind: DestructiveActionKind) {
        #expect(kind.color == Color.destructiveColor, "\(kind) does not map to Color.destructiveColor")
    }

    @Test("destructiveTint() is available on any View (compile-level use)")
    func destructiveTintExists() {
        let tinted = tintedButton()
        #expect(String(describing: type(of: tinted)).isEmpty == false)
    }

    private func tintedButton() -> some View {
        Button(role: .destructive) { } label: { Text("Delete") }
            .destructiveTint()
    }
}
