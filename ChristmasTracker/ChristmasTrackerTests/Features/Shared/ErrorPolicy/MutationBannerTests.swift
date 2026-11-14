//
//  MutationBannerTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: MutationBanner.state(for:) is the banner an initiating view holds in its own local
//  state after a THROWN mutation error (add member, remove, leave, archive, create and edit list, add
//  child ...). nil for sessionEnded (the sign-in flow takes over); the message equals the typed
//  error's userMessage, so a validation error keeps its server text; a blank validation message falls
//  back to the fixed text. Fake data only.
//
//  ASSUMPTION (reported): the interface does not name the actions. The tests assume Dismiss is always
//  offered and Try Again exactly when ListErrorPresentation / ChildErrorPresentation say the error is
//  retryable (the rule of every existing banner). They are kept in two tests so that rule is easy to
//  adjust.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MutationBanner Tests")
struct MutationBannerTests {

    /// Every ListError except the ones the sign-in flow handles (covered separately).
    nonisolated static let listErrors: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "Fake validation"), .rateLimited(retryAfter: 30), .network,
        .invalidResponse, .server, .memberEmailNotFound, .alreadyMember, .membershipNotFound
    ]

    nonisolated static let childErrors: [ChildError] = [
        .childNotFound, .childHasLists, .validation(message: "Fake validation"),
        .rateLimited(retryAfter: 30), .network, .invalidResponse, .server, .forbidden
    ]

    private func makeSUT(_ error: ListError) -> InlineErrorBannerState? {
        MutationBanner.state(for: error)
    }

    private func makeSUT(_ error: ChildError) -> InlineErrorBannerState? {
        MutationBanner.state(for: error)
    }

    // MARK: ListError

    @Test("an ended session shows no mutation banner (the sign-in flow takes over)")
    func listSessionEndedIsNil() {
        #expect(makeSUT(ListError.sessionEnded) == nil)
    }

    @Test("the message is the error's user message", arguments: MutationBannerTests.listErrors)
    func listMessage(error: ListError) throws {
        let banner = try #require(makeSUT(error))

        #expect(banner.message == error.userMessage)
    }

    @Test("the server's validation text is kept")
    func listValidationKeepsServerText() throws {
        let banner = try #require(makeSUT(ListError.validation(message: "Name is too long.")))

        #expect(banner.message == "Name is too long.")
    }

    @Test("a blank validation message falls back to the fixed text", arguments: ["", "   ", "\n"])
    func listBlankValidationFallsBack(message: String) throws {
        let banner = try #require(makeSUT(ListError.validation(message: message)))

        #expect(banner.message == "The information you provided is invalid.")
        #expect(banner.message == ListError.validation(message: message).userMessage)
    }

    @Test("the rate limit keeps its retry hint")
    func listRateLimitKeepsHint() throws {
        let banner = try #require(makeSUT(ListError.rateLimited(retryAfter: 30)))

        #expect(banner.message.contains("30 seconds"))
    }

    @Test("a mutation banner can always be dismissed", arguments: MutationBannerTests.listErrors)
    func listDismissAlwaysOffered(error: ListError) throws {
        let banner = try #require(makeSUT(error))

        #expect(banner.actions.contains(.dismiss))
    }

    @Test("Try Again is offered exactly for the retryable errors", arguments: MutationBannerTests.listErrors)
    func listTryAgainOnlyWhenRetryable(error: ListError) throws {
        let banner = try #require(makeSUT(error))

        #expect(banner.actions.contains(.tryAgain) == ListErrorPresentation(error).isRetryable)
    }

    @Test("the message is never blank", arguments: MutationBannerTests.listErrors)
    func listMessageNeverBlank(error: ListError) throws {
        let banner = try #require(makeSUT(error))

        #expect(!banner.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: ChildError

    @Test("an ended session shows no child mutation banner")
    func childSessionEndedIsNil() {
        #expect(makeSUT(ChildError.sessionEnded) == nil)
    }

    @Test("the child message is the error's user message", arguments: MutationBannerTests.childErrors)
    func childMessage(error: ChildError) throws {
        let banner = try #require(makeSUT(error))

        #expect(banner.message == error.userMessage)
    }

    @Test("the server's validation text is kept for a child")
    func childValidationKeepsServerText() throws {
        let banner = try #require(makeSUT(ChildError.validation(message: "First name is required.")))

        #expect(banner.message == "First name is required.")
    }

    @Test("a blank child validation message falls back to the fixed text", arguments: ["", "   "])
    func childBlankValidationFallsBack(message: String) throws {
        let banner = try #require(makeSUT(ChildError.validation(message: message)))

        #expect(banner.message == "The information you provided is invalid.")
    }

    @Test("a child mutation banner can always be dismissed", arguments: MutationBannerTests.childErrors)
    func childDismissAlwaysOffered(error: ChildError) throws {
        let banner = try #require(makeSUT(error))

        #expect(banner.actions.contains(.dismiss))
    }

    @Test("Try Again is offered for a child exactly for the retryable errors", arguments: MutationBannerTests.childErrors)
    func childTryAgainOnlyWhenRetryable(error: ChildError) throws {
        let banner = try #require(makeSUT(error))

        #expect(banner.actions.contains(.tryAgain) == ChildErrorPresentation(error).isRetryable)
    }
}
