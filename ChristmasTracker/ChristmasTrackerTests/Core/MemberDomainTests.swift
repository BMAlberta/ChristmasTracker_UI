//
//  MemberDomainTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: MemberRole, AddMemberInput, CoOwnerChange and the co-owner field of
//  UpdateListInput. Pure value types; fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Member domain Tests")
struct MemberDomainTests {

    // MARK: - MemberRole

    @Test("MemberRole lists member then viewer")
    func allCases() {
        #expect(MemberRole.allCases == [.member, .viewer])
    }

    @Test("MemberRole is the existing ListMemberRole")
    func isListMemberRole() {
        let role: ListMemberRole = MemberRole.member
        #expect(role == .member)
    }

    @Test("MemberRole titles are Member and Viewer")
    func titles() {
        #expect(MemberRole.member.title == "Member")
        #expect(MemberRole.viewer.title == "Viewer")
    }

    // MARK: - AddMemberInput

    @Test("AddMemberInput carries the email and role and is Equatable")
    func addMemberInput() {
        let input = AddMemberInput(email: "casey@example.com", role: .viewer)
        #expect(input.email == "casey@example.com")
        #expect(input.role == .viewer)
        #expect(input == AddMemberInput(email: "casey@example.com", role: .viewer))
        #expect(input != AddMemberInput(email: "casey@example.com", role: .member))
        #expect(input != AddMemberInput(email: "other@example.com", role: .viewer))
    }

    // MARK: - CoOwnerChange

    @Test("CoOwnerChange cases are distinct and compare on the email")
    func coOwnerChangeEquality() {
        #expect(CoOwnerChange.unchanged == .unchanged)
        #expect(CoOwnerChange.clear == .clear)
        #expect(CoOwnerChange.set(email: "a@example.com") == .set(email: "a@example.com"))
        #expect(CoOwnerChange.set(email: "a@example.com") != .set(email: "b@example.com"))
        #expect(CoOwnerChange.unchanged != .clear)
        #expect(CoOwnerChange.unchanged != .set(email: "a@example.com"))
        #expect(CoOwnerChange.clear != .set(email: "a@example.com"))
    }

    // MARK: - UpdateListInput

    @Test("UpdateListInput without a co-owner argument leaves the co-owner unchanged")
    func updateInputDefaultCoOwner() {
        let input = UpdateListInput(name: "Fake List", theme: nil, visibility: nil)
        #expect(input.coOwner == .unchanged)
    }

    @Test("UpdateListInput carries an explicit co-owner change")
    func updateInputCarriesCoOwner() {
        let set = UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: "a@example.com"))
        #expect(set.coOwner == .set(email: "a@example.com"))
        let clear = UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .clear)
        #expect(clear.coOwner == .clear)
    }

    @Test("UpdateListInput equality includes the co-owner change")
    func updateInputEquality() {
        let base = UpdateListInput(name: "Fake", theme: nil, visibility: nil)
        #expect(base == UpdateListInput(name: "Fake", theme: nil, visibility: nil, coOwner: .unchanged))
        #expect(base != UpdateListInput(name: "Fake", theme: nil, visibility: nil, coOwner: .set(email: "a@example.com")))
    }
}
