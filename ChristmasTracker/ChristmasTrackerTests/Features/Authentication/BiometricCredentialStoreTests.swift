//
//  BiometricCredentialStoreTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (S1): InMemoryBiometricCredentialStore and
//  the BiometricCredentialStoring protocol.
//
//  Contract (from Gate 1 spec, S1):
//
//    protocol BiometricCredentialStoring: Sendable {
//        func enrolledUser() -> (userId: String, firstName: String)?
//        func enroll(refreshToken: String, userId: String, firstName: String) throws
//        func readRefreshToken(reason: String) async throws(BiometricCredentialError) -> String
//        func updateRefreshToken(_ newToken: String) throws
//        func delete() throws
//    }
//
//    class/actor InMemoryBiometricCredentialStore: BiometricCredentialStoring {
//        var stubbedReadError: BiometricCredentialError?
//    }
//
//  Will fail to compile until:
//    - BiometricCredentialError enum is defined
//    - BiometricCredentialStoring protocol is defined
//    - InMemoryBiometricCredentialStore is added with stubbedReadError
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Suite

@Suite("InMemoryBiometricCredentialStore")
struct BiometricCredentialStoreTests {

    // MARK: - Factory

    private func makeSUT() -> InMemoryBiometricCredentialStore {
        InMemoryBiometricCredentialStore()
    }

    // MARK: - enrolledUser before enrollment

    @Test("enrolledUser() returns nil before any enrollment")
    func enrolledUserReturnsNilBeforeEnrollment() {
        let sut = makeSUT()
        let user = sut.enrolledUser()
        #expect(user == nil)
    }

    // MARK: - enroll then read back

    @Test("enroll then enrolledUser returns the enrolled userId and firstName")
    func enrollThenEnrolledUserReturnsCorrectAttributes() throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok-1", userId: "user-123", firstName: "Alice")
        let user = try #require(sut.enrolledUser())
        #expect(user.userId == "user-123")
        #expect(user.firstName == "Alice")
    }

    @Test("second enroll replaces the first enrollment")
    func secondEnrollReplacesFirst() throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok-1", userId: "user-aaa", firstName: "Alice")
        try sut.enroll(refreshToken: "tok-2", userId: "user-bbb", firstName: "Bob")
        let user = try #require(sut.enrolledUser())
        #expect(user.userId == "user-bbb")
        #expect(user.firstName == "Bob")
    }

    // MARK: - readRefreshToken

    @Test("readRefreshToken returns the stored refresh token after enrollment")
    func readRefreshTokenReturnsStoredToken() async throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "my-refresh-token", userId: "user-123", firstName: "Alice")
        let token = try await sut.readRefreshToken(reason: "Sign in")
        #expect(token == "my-refresh-token")
    }

    @Test("readRefreshToken throws .itemNotFound if nothing is enrolled")
    func readRefreshTokenThrowsItemNotFoundWhenNotEnrolled() async throws {
        let sut = makeSUT()
        await #expect(throws: BiometricCredentialError.itemNotFound) {
            _ = try await sut.readRefreshToken(reason: "Sign in")
        }
    }

    @Test("stubbedReadError causes readRefreshToken to throw that error")
    func stubbedReadErrorCausesThrow() async throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok", userId: "u", firstName: "F")
        sut.stubbedReadError = .biometricFailed
        await #expect(throws: BiometricCredentialError.biometricFailed) {
            _ = try await sut.readRefreshToken(reason: "Sign in")
        }
    }

    @Test("stubbedReadError=.lockedOut causes readRefreshToken to throw .lockedOut")
    func stubbedReadErrorLockedOut() async throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok", userId: "u", firstName: "F")
        sut.stubbedReadError = .lockedOut
        await #expect(throws: BiometricCredentialError.lockedOut) {
            _ = try await sut.readRefreshToken(reason: "Sign in")
        }
    }

    @Test("stubbedReadError=.userCancelled causes readRefreshToken to throw .userCancelled")
    func stubbedReadErrorUserCancelled() async throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok", userId: "u", firstName: "F")
        sut.stubbedReadError = .userCancelled
        await #expect(throws: BiometricCredentialError.userCancelled) {
            _ = try await sut.readRefreshToken(reason: "Sign in")
        }
    }

    // MARK: - updateRefreshToken

    @Test("updateRefreshToken replaces the stored token")
    func updateRefreshTokenReplacesToken() async throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok-1", userId: "user-123", firstName: "Alice")
        try sut.updateRefreshToken("tok-2")
        let token = try await sut.readRefreshToken(reason: "Sign in")
        #expect(token == "tok-2")
    }

    @Test("updateRefreshToken leaves enrolledUser attributes unchanged")
    func updateRefreshTokenDoesNotChangeEnrolledUser() throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok-1", userId: "user-123", firstName: "Alice")
        try sut.updateRefreshToken("tok-2")
        let user = try #require(sut.enrolledUser())
        #expect(user.userId == "user-123")
        #expect(user.firstName == "Alice")
    }

    @Test("updateRefreshToken throws .itemNotFound if not enrolled")
    func updateRefreshTokenThrowsWhenNotEnrolled() throws {
        let sut = makeSUT()
        #expect(throws: BiometricCredentialError.itemNotFound) {
            try sut.updateRefreshToken("tok-new")
        }
    }

    // MARK: - delete

    @Test("delete clears enrollment; enrolledUser returns nil after delete")
    func deleteClearsEnrollment() throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok-1", userId: "user-123", firstName: "Alice")
        try sut.delete()
        #expect(sut.enrolledUser() == nil)
    }

    @Test("readRefreshToken throws .itemNotFound after delete")
    func readRefreshTokenThrowsAfterDelete() async throws {
        let sut = makeSUT()
        try sut.enroll(refreshToken: "tok-1", userId: "user-123", firstName: "Alice")
        try sut.delete()
        await #expect(throws: BiometricCredentialError.itemNotFound) {
            _ = try await sut.readRefreshToken(reason: "Sign in")
        }
    }

    // MARK: - Isolation between store instances

    @Test("enrolling in one store does not affect a separate store instance")
    func separateStoreInstancesAreIsolated() throws {
        let store1 = makeSUT()
        let store2 = makeSUT()
        try store1.enroll(refreshToken: "tok-1", userId: "user-aaa", firstName: "Alice")
        // Simulates "clearing legacy keys from another source" — a separate store is unaffected
        try store2.delete() // deleting on an empty store should not throw or corrupt store1
        let user = try #require(store1.enrolledUser())
        #expect(user.userId == "user-aaa",
                "Enrollment in store1 must survive a delete() call on a separate store2 instance")
    }
}
