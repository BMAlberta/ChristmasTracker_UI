//
//  ChildrenRetryScanTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B5: OLD behavior: Try Again always continued without a new dialog (retryDeletion
//  passed requiresConfirmation: false to planReady). NEW: retryDeletion uses retryPlanReady and the
//  screen remembers the confirmed plan. Comments stripped first. Needs the checkout on disk.
//

import Foundation
import Testing

@Suite("Children retry scan Tests")
struct ChildrenRetryScanTests {

    private static let screen = "Features/Children/Views/ChildrenView.swift"

    private func code(file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let source = try #require(tree.source(Self.screen), "Could not read \(Self.screen)")
        return ItemSourceScan.codeOnly(source)
    }

    private func retryBody(_ code: String) throws -> String {
        try #require(ItemSourceScan.braceBody(after: "func retryDeletion", in: code),
                     "Could not find the retryDeletion body")
    }

    @Test("OLD: Try Again always continued without a new dialog; retryDeletion now calls retryPlanReady(")
    func retryCallsRetryPlanReady() throws {
        let body = try retryBody(try code())
        #expect(body.contains("retryPlanReady("), "retryDeletion must apply the plan through retryPlanReady(")
    }

    @Test("OLD: Try Again always continued without a new dialog; retryDeletion no longer passes requiresConfirmation: false")
    func retryDoesNotSkipConfirmation() throws {
        let body = try retryBody(try code())
        #expect(try ItemSourceScan.matchingLines(#"requiresConfirmation\s*:\s*false"#, in: body).isEmpty,
                "retryDeletion must not pass requiresConfirmation: false")
    }

    @Test("OLD: Try Again always continued without a new dialog; ChildrenView.swift has no requiresConfirmation: false at all")
    func noSkippedConfirmationAnywhere() throws {
        let code = try code()
        #expect(try ItemSourceScan.matchingLines(#"requiresConfirmation\s*:\s*false"#, in: code).isEmpty)
    }

    @Test("OLD: Try Again always continued without a new dialog; DeletionFailure carries the confirmedPlan")
    func failureCarriesConfirmedPlan() throws {
        let code = try code()
        let body = try #require(ItemSourceScan.braceBody(after: "struct DeletionFailure", in: code),
                                "Could not find the DeletionFailure struct")
        #expect(try !ItemSourceScan.matchingLines(#"\blet\s+confirmedPlan\s*:\s*ChildDeletionPlan\b"#, in: body).isEmpty,
                "DeletionFailure must declare confirmedPlan: ChildDeletionPlan")
    }

    @Test("OLD: Try Again always continued without a new dialog; retryDeletion passes the failure's confirmedPlan")
    func retryPassesConfirmedPlan() throws {
        let body = try retryBody(try code())
        #expect(try !ItemSourceScan.matchingLines(#"confirmedPlan\s*:"#, in: body).isEmpty,
                "retryDeletion must pass confirmedPlan: to retryPlanReady")
    }
}
