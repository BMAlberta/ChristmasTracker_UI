//
//  BootstrapResolutionTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: no silent mock fallback. The pure bootstrap decision and the configuration-error
//  view state. Production does not exist yet; these tests do not compile until it does.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Bootstrap resolution Tests")
struct BootstrapResolutionTests {

    // MARK: - resolveBootstrap

    @Test("mock mode is ready whether or not a client is available")
    func mockIsAlwaysReady() {
        #expect(resolveBootstrap(mode: .mock, clientAvailable: true) == .ready)
        #expect(resolveBootstrap(mode: .mock, clientAvailable: false) == .ready)
    }

    @Test("real mode with a client is ready")
    func realWithClientIsReady() {
        #expect(resolveBootstrap(mode: .real, clientAvailable: true) == .ready)
    }

    @Test("real mode without a client has failed")
    func realWithoutClientFails() {
        #expect(resolveBootstrap(mode: .real, clientAvailable: false) == .failed)
    }

    // MARK: - ConfigurationErrorState

    @Test("the failed state shows the fixed message and no action")
    func failedStateContent() throws {
        let state = try #require(ConfigurationErrorState.state(for: .failed))
        #expect(ConfigurationErrorState.message == "This version can't connect to the server. Please reinstall the latest version.")
        #expect(state.showsSignIn == false)
        #expect(state.showsAnyAction == false)
        #expect(state.accessibilityLabel.contains(ConfigurationErrorState.message))
    }

    @Test("the ready state has no configuration error")
    func readyStateIsNil() {
        #expect(ConfigurationErrorState.state(for: .ready) == nil)
    }

    @Test("the message names no URL, host or value")
    func messageIsPlain() {
        let message = ConfigurationErrorState.message
        #expect(!message.contains("http"))
        #expect(!message.contains("://"))
        #expect(!message.contains("@"))
    }

    // MARK: - ConfigurationError

    @Test("ConfigurationError.clientUnavailable is Equatable")
    func configurationErrorEquatable() {
        #expect(ConfigurationError.clientUnavailable == ConfigurationError.clientUnavailable)
    }
}
