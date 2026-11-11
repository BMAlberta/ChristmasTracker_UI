//
//  ListArchiveCompletionTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A fix pass: what the detail screen does after deleteList returns normally. It
//  dismisses only when the service holds no error; a failed reload after a successful archive is
//  shown in the banner and the screen stays.
//

import Testing
@testable import ChristmasTracker

@Suite("List archive completion")
struct ListArchiveCompletionTests {

    @Test("no service error: the screen dismisses")
    func noErrorDismisses() {
        #expect(ListArchiveCompletion.after(serviceError: nil) == .dismiss)
    }

    @Test("a service error: the screen stays and shows that error's presentation", arguments: [
        ListError.network, .server, .rateLimited(retryAfter: 3), .invalidResponse, .unauthorized, .notFound
    ])
    func errorShowsBanner(error: ListError) {
        #expect(ListArchiveCompletion.after(serviceError: error) == .showError(ListErrorPresentation(error)))
    }
}
