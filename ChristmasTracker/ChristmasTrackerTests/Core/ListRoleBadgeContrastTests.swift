//
//  ListRoleBadgeContrastTests.swift
//  ChristmasTrackerTests
//
//  PAL1-P3: every role badge text pair reaches 4.5:1 in light and dark, measured from the real
//  colorset files. The badge sits on the card (surface) or the page (backgroundPrimary). The
//  edge pairs are decorative and only printed, not asserted.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListRoleBadge contrast")
struct ListRoleBadgeContrastTests {

    private static let textThreshold = 4.5

    private struct Pair {
        let tone: String
        let foreground: ThemeLabel
        let background: ThemeToken
    }

    private func pairs(mode: ThemeMode) -> [Pair] {
        var result: [Pair] = []
        let owner = ListRoleBadge.Tone.owner.look
        if let fill = owner.fill {
            result.append(Pair(tone: "owner", foreground: owner.label(for: mode), background: fill))
        }
        let coOwner = ListRoleBadge.Tone.coOwner.look
        let member = ListRoleBadge.Tone.member.look
        let viewer = ListRoleBadge.Tone.viewer.look
        for background in [ThemeToken.surface, .backgroundPrimary] {
            result.append(Pair(tone: "coOwner", foreground: coOwner.label(for: mode), background: background))
            result.append(Pair(tone: "viewer", foreground: viewer.label(for: mode), background: background))
        }
        if let fill = member.fill {
            result.append(Pair(tone: "member", foreground: member.label(for: mode), background: fill))
        }
        return result
    }

    private func rgb(_ label: ThemeLabel, _ mode: ThemeMode, _ catalog: ThemeCatalog) throws -> ThemeRGB {
        switch label {
        case .white: return ThemeStatusLabelTable.rgb(.white, mode)
        case .token(let token): return try catalog.rgb(token, mode)
        }
    }

    @Test func everyBadgeTextPairReachesFourPointFive() throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        var count = 0
        for mode in ThemeMode.allCases {
            for pair in pairs(mode: mode) {
                let foreground = try rgb(pair.foreground, mode, catalog)
                let background = try catalog.rgb(pair.background, mode)
                let ratio = ThemeContrast.ratio(foreground, background)
                let modeName = ThemeTestSupport.modeName(mode)
                let labelName = ThemeTestSupport.labelName(pair.foreground)
                let ratioText = String(format: "%.2f", ratio)
                print("BADGE|\(modeName)|\(pair.tone)|\(labelName)|\(pair.background.rawValue)|\(ratioText)")
                #expect(ratio >= Self.textThreshold,
                        "\(pair.tone) \(labelName) on \(pair.background) in \(mode): \(ratio)")
                count += 1
            }
        }
        #expect(count == 12, "expected 6 pairs per mode, measured \(count)")
    }

    @Test func decorativeEdgeRatiosArePrinted() throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        for mode in ThemeMode.allCases {
            for tone in [ListRoleBadge.Tone.coOwner, .member, .viewer] {
                guard let border = tone.look.border else {
                    Issue.record("\(tone) has no edge")
                    continue
                }
                let edge = try catalog.rgb(border, mode)
                for background in [ThemeToken.surface, .backgroundPrimary] {
                    let ratio = ThemeContrast.ratio(edge, try catalog.rgb(background, mode))
                    let modeName = ThemeTestSupport.modeName(mode)
                    let ratioText = String(format: "%.2f", ratio)
                    print("BADGEEDGE|\(modeName)|\(tone)|\(border.rawValue)|\(background.rawValue)|\(ratioText)")
                }
            }
        }
    }
}
