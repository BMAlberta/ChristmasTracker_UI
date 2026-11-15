//
//  StatusEdgeRuleTests.swift
//  ChristmasTrackerTests
//
//  PAL1-P2: which status styles get a graphic edge. The rule is computed from the token table
//  (`ThemeEdgeRule`), so these tests derive the expectation from the table and also pin today's answer.
//

import CoreGraphics
import Testing
@testable import ChristmasTracker

@Suite("Status edge rule")
struct StatusEdgeRuleTests {

    @Test func todayOnlyPartialAndGiftedGetAnEdge() {
        let withEdge = Set(StatusKind.allCases.filter { StatusStyle.style(for: $0).needsEdge })
        #expect(withEdge == [.partial, .gifted])
    }

    @Test func theOtherFourStatusesGetNoEdge() {
        for kind in [StatusKind.available, .purchased, .shipped, .wrapped] {
            let style = StatusStyle.style(for: kind)
            #expect(!style.needsEdge, "\(kind) should have no edge")
            #expect(style.edge == nil, "\(kind) should have no edge token")
        }
    }

    @Test func needsEdgeFollowsTheTokenTable() {
        let fills = ThemeEdgeRule.fillsNeedingEdge()
        for kind in StatusKind.allCases {
            let style = StatusStyle.style(for: kind)
            #expect(style.needsEdge == fills.contains(style.fill), "\(kind) disagrees with ThemeEdgeRule")
        }
    }

    @Test func theEdgeTokenIsHighlightStrong() {
        #expect(StatusStyle.edgeToken == .highlightStrong)
        for kind in StatusKind.allCases {
            let style = StatusStyle.style(for: kind)
            if style.needsEdge {
                #expect(style.edge == .highlightStrong)
            }
        }
    }

    @Test func theEdgeIsOnePoint() {
        #expect(StatusStyle.edgeWidth == 1)
    }

    @Test func theEdgeIsVisibleAgainstThePageAndCardInBothModes() {
        for kind in StatusKind.allCases {
            guard let edge = StatusStyle.style(for: kind).edge else { continue }
            for mode in [ThemeMode.light, .dark] {
                let edgeRGB = ThemeTokenTable.rgb(edge, mode)
                for background in [ThemeToken.backgroundPrimary, .surface] {
                    let ratio = ThemeContrast.ratio(edgeRGB, ThemeTokenTable.rgb(background, mode))
                    #expect(ratio >= ThemeEdgeRule.graphicThreshold, "\(kind) edge on \(background) in \(mode): \(ratio)")
                }
            }
        }
    }
}
