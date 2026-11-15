// MockVersionStateTests.swift
// ChristmasTrackerTests
//
// VER1 V2: the -mockVersionState launch value parser and the policies it stands for.

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Mock version state Tests")
struct MockVersionStateTests {

    @Test("parse maps the four names")
    func parseNames() {
        #expect(MockVersionState.parse("ok", environment: "development") == .ok)
        #expect(MockVersionState.parse("recommended", environment: "development") == .recommended)
        #expect(MockVersionState.parse("required", environment: "development") == .required)
        #expect(MockVersionState.parse("requiredNoLink", environment: "development") == .requiredNoLink)
    }

    @Test("parse is case-insensitive and trimmed")
    func parseLoose() {
        #expect(MockVersionState.parse("  REQUIRED \n", environment: "staging") == .required)
        #expect(MockVersionState.parse("requirednolink", environment: "staging") == .requiredNoLink)
        #expect(MockVersionState.parse("Recommended", environment: "staging") == .recommended)
    }

    @Test("parse returns nil for nil, empty and unknown")
    func parseNil() {
        #expect(MockVersionState.parse(nil, environment: "development") == nil)
        #expect(MockVersionState.parse("", environment: "development") == nil)
        #expect(MockVersionState.parse("   ", environment: "development") == nil)
        #expect(MockVersionState.parse("forceUpdate", environment: "development") == nil)
    }

    @Test("parse is always nil in production")
    func parseProduction() {
        for raw in ["ok", "recommended", "required", "requiredNoLink"] {
            #expect(MockVersionState.parse(raw, environment: "production") == nil)
            #expect(MockVersionState.parse(raw, environment: "  Production ") == nil)
            #expect(MockVersionState.parse(raw, environment: "PRODUCTION") == nil)
        }
    }

    @Test("ok policy")
    func okPolicy() {
        #expect(MockVersionState.ok.policy.state == .ok)
    }

    @Test("recommended policy has a link and short notes")
    func recommendedPolicy() throws {
        let policy = MockVersionState.recommended.policy
        #expect(policy.state == .updateRecommended)
        #expect(policy.manifestURL != nil)
        let notes = try #require(policy.releaseNotes)
        #expect(!notes.isEmpty)
        #expect(notes.count <= 200)
    }

    @Test("required policy has a link and notes")
    func requiredPolicy() throws {
        let policy = MockVersionState.required.policy
        #expect(policy.state == .forceUpdate)
        #expect(policy.manifestURL != nil)
        let notes = try #require(policy.releaseNotes)
        #expect(!notes.isEmpty)
    }

    @Test("requiredNoLink policy has no link")
    func requiredNoLinkPolicy() {
        let policy = MockVersionState.requiredNoLink.policy
        #expect(policy.state == .forceUpdate)
        #expect(policy.manifestURL == nil)
    }

    @Test("the mock links are accepted by the install link builder")
    func linksAreInstallable() {
        for state in [MockVersionState.recommended, .required] {
            #expect(UpdateInstallLink.url(from: state.policy.manifestURL?.absoluteString) != nil)
        }
    }
}
