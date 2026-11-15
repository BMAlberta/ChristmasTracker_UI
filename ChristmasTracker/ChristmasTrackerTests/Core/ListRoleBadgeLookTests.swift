//
//  ListRoleBadgeLookTests.swift
//  ChristmasTrackerTests
//
//  PAL1-P3: the pure look of each role badge tone (fill, edge, text), by token. No gold, no
//  cranberry. The look reads only the tone, never a role.
//

import CoreGraphics
import Testing
@testable import ChristmasTracker

@Suite("ListRoleBadge look")
struct ListRoleBadgeLookTests {

    @Test func ownerIsAPrimaryFillWithNoEdge() {
        let look = ListRoleBadge.Tone.owner.look
        #expect(look.fill == .primary)
        #expect(look.border == nil)
        #expect(look.text == .onFill)
    }

    @Test func ownerLabelIsTheStatusLabelOnTheSameGreen() {
        let look = ListRoleBadge.Tone.owner.look
        for mode in ThemeMode.allCases {
            #expect(look.label(for: mode) == ThemeStatusLabelTable.label(onFill: .primary, mode: mode))
        }
    }

    @Test func coOwnerIsAPrimaryEdgeWithPrimaryTextAndNoFill() {
        let look = ListRoleBadge.Tone.coOwner.look
        #expect(look.fill == nil)
        #expect(look.border == .primary)
        #expect(look.text == .token(.primary))
        for mode in ThemeMode.allCases {
            #expect(look.label(for: mode) == .token(.primary))
        }
    }

    @Test func memberIsASecondaryFillWithABorderEdgeAndPrimaryText() {
        let look = ListRoleBadge.Tone.member.look
        #expect(look.fill == .backgroundSecondary)
        #expect(look.border == .border)
        #expect(look.text == .token(.textPrimary))
    }

    @Test func viewerIsAnEdgeOnlyWithMutedText() {
        let look = ListRoleBadge.Tone.viewer.look
        #expect(look.fill == nil)
        #expect(look.border == .border)
        #expect(look.text == .token(.textMuted))
    }

    @Test func theEdgeIsOnePoint() {
        #expect(RoleBadgeLook.borderWidth == 1)
    }

    @Test func noToneUsesGoldOrCranberry() {
        let banned: Set<ThemeToken> = [.accent, .highlight, .highlightStrong, .statusWrapped, .statusGifted,
                                       .statusPartial, .budgetOver, .budgetWarning, .budgetWarningBar]
        for tone in [ListRoleBadge.Tone.owner, .coOwner, .member, .viewer] {
            let look = tone.look
            var used: [ThemeToken] = []
            if let fill = look.fill { used.append(fill) }
            if let border = look.border { used.append(border) }
            if case .token(let token) = look.text { used.append(token) }
            for token in used {
                #expect(!banned.contains(token), "\(tone) uses \(token)")
            }
        }
    }
}
