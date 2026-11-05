//
//  RememberedEmailStoreTests.swift
//  ChristmasTrackerTests
//
//  R7: Tests for RememberedEmailStoring protocol and RememberedEmailStore struct.
//  These tests will fail to compile until RememberedEmailStore is implemented.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("RememberedEmailStore Tests")
struct RememberedEmailStoreTests {

    // MARK: - Helpers

    /// Returns a fresh isolated UserDefaults suite and a store backed by it.
    private func makeSUT() -> (store: RememberedEmailStore, defaults: UserDefaults) {
        let suiteName = "com.christmastracker.tests.rememberedemail.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = RememberedEmailStore(defaults: defaults)
        return (store, defaults)
    }

    // MARK: - Tests

    @Test("rememberedEmail is nil when nothing has been stored")
    func rememberedEmailIsNilWhenNotSet() {
        var (store, _) = makeSUT()
        #expect(store.rememberedEmail == nil)
    }

    @Test("rememberedEmail returns the value that was stored")
    func rememberedEmailReturnsStoredEmail() {
        var (store, _) = makeSUT()
        store.rememberedEmail = "test@example.com"
        #expect(store.rememberedEmail == "test@example.com")
    }

    @Test("rememberedEmail is nil after being set to nil")
    func rememberedEmailClearsWhenSetToNil() {
        var (store, _) = makeSUT()
        store.rememberedEmail = "test@example.com"
        store.rememberedEmail = nil
        #expect(store.rememberedEmail == nil)
    }

    @Test("RememberedEmailStore.key equals 'login.rememberedEmail'")
    func rememberedEmailStoreKeyIsCorrect() {
        #expect(RememberedEmailStore.key == "login.rememberedEmail")
    }

    // MARK: - R9: loginInitialState free function

    // AC6: loginInitialState with a non-nil remembered address returns it and rememberEmail true.
    @Test("loginInitialState with remembered email returns that email and rememberEmail true")
    func loginInitialStateWithRememberedEmailReturnsTrueAndEmail() {
        let result = loginInitialState(remembered: "a@b.com")
        #expect(result.email == "a@b.com")
        #expect(result.rememberEmail == true)
    }

    // AC6: loginInitialState with nil returns empty string and rememberEmail false.
    @Test("loginInitialState with nil remembered email returns empty string and rememberEmail false")
    func loginInitialStateWithNilReturnsFalseAndEmptyString() {
        let result = loginInitialState(remembered: nil)
        #expect(result.email == "")
        #expect(result.rememberEmail == false)
    }
}
