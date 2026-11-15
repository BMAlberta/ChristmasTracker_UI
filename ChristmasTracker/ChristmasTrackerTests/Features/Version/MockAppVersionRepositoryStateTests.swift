// MockAppVersionRepositoryStateTests.swift
// ChristmasTrackerTests
//
// VER1 V2: MockAppVersionRepository returns the policy of the state it was built with.

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Mock app version repository state Tests")
@MainActor
struct MockAppVersionRepositoryStateTests {

    private func makeSUT(_ state: MockVersionState) -> MockAppVersionRepository {
        MockAppVersionRepository(state: state)
    }

    @Test("checkVersion returns the policy of each state")
    func returnsStatePolicy() async throws {
        for state in [MockVersionState.ok, .recommended, .required, .requiredNoLink] {
            let policy = try await makeSUT(state).checkVersion()
            #expect(policy == state.policy)
        }
    }

    @Test("requiredNoLink yields a force update with no manifest")
    func requiredNoLink() async throws {
        let policy = try await makeSUT(.requiredNoLink).checkVersion()
        #expect(policy.state == .forceUpdate)
        #expect(policy.manifestURL == nil)
    }

    @Test("the no-argument initializer still returns ok")
    func defaultInitIsOk() async throws {
        let policy = try await MockAppVersionRepository().checkVersion()
        #expect(policy.state == .ok)
    }
}
