//
//  PurchaseDetailModel.swift
//  ChristmasTracker
//
//  The controller behind the purchase detail screen. It loads one purchase through PurchaseService,
//  holds the two editable sections (shipping and notes) and the delete, and reports the end of the
//  screen through `finish`. After a delete it runs the follow-up refresh itself (see confirmDelete).
//
//  Errors are scoped. A load error, a shipping error, a notes error and a delete error are four
//  separate properties; each is cleared by its own dismiss, by its own success and by `disappear()`.
//  Nothing is read from a shared service error. Ownership is decided only by
//  PurchasePermissions.canManage on the purchaser id. Nothing is logged.
//

import Foundation
import Observation

nonisolated enum PurchaseDetailFinish: Equatable, Sendable {
    /// The purchase was deleted (or was already gone when the delete ran).
    case deleted
    /// The purchase cannot be shown any more (not found, or not the signed-in user's).
    case gone
}

nonisolated enum PurchaseDetailPhase: Equatable, Sendable {
    case loading
    case loaded(PurchaseDetailState)
    case failed
}

/// What the model needs to run the follow-up refresh after a delete. `run` executes the steps in
/// order and asks the continue-check before each one.
struct PurchaseDetailRefresh {
    var run: @MainActor ([PurchaseRefreshStep], @MainActor () -> Bool) async -> Void
    var currentItemsListId: @MainActor () -> String?

    static var doNothing: PurchaseDetailRefresh {
        PurchaseDetailRefresh(run: { _, _ in }, currentItemsListId: { nil })
    }
}

@MainActor
@Observable
final class PurchaseDetailModel {

    // MARK: - Dependencies

    let purchaseId: String
    let itemId: String
    let listId: String
    private let currentUserId: String?
    private let service: PurchaseService
    private let currencyCode: String
    private let locale: Locale
    private let refresh: PurchaseDetailRefresh

    // MARK: - State

    private(set) var phase: PurchaseDetailPhase = .loading
    private(set) var shipping: PurchaseShippingSectionState?
    private(set) var notes: PurchaseNotesSectionState?
    private(set) var finish: PurchaseDetailFinish?

    private(set) var loadBanner: InlineErrorBannerState?
    private(set) var shippingBanner: InlineErrorBannerState?
    private(set) var notesBanner: InlineErrorBannerState?
    private(set) var deleteBanner: InlineErrorBannerState?

    private(set) var isSavingShipping = false
    private(set) var isSavingNotes = false
    private(set) var isDeleting = false

    /// VoiceOver text for the last save or delete result. No purchase data.
    private(set) var announcement: String?
    /// True when the announcement is an error text (the error banner announces itself).
    private(set) var announcementIsError = false
    /// Counts the announcements, so the view can react to the same text twice.
    private(set) var announcementCount = 0

    // MARK: - Initialization

    init(
        purchaseId: String,
        itemId: String,
        listId: String,
        currentUserId: String?,
        service: PurchaseService,
        currencyCode: String? = nil,
        locale: Locale? = nil,
        refresh: PurchaseDetailRefresh? = nil
    ) {
        self.refresh = refresh ?? .doNothing
        self.purchaseId = purchaseId
        self.itemId = itemId
        self.listId = listId
        self.currentUserId = currentUserId
        self.service = service
        self.currencyCode = currencyCode ?? "USD"
        self.locale = locale ?? Locale.current
    }

    // MARK: - Load

    func load() async {
        if case .loaded = phase { return }
        loadBanner = nil
        phase = .loading
        do {
            let purchase = try await service.fetchPurchase(id: purchaseId)
            show(purchase)
        } catch is CancellationError {
            return
        } catch let error as PurchaseManagementError {
            phase = .failed
            switch error {
            case .notFound:
                finish = .gone
            case .unauthorized, .sessionEnded:
                break
            case .forbidden, .validation, .rateLimited, .network, .invalidResponse, .server:
                loadBanner = Self.banner(for: error)
            }
        } catch {
            phase = .failed
            loadBanner = Self.banner(for: .server)
        }
    }

    func retryLoad() async {
        loadBanner = nil
        await load()
    }

    func dismissLoadError() {
        loadBanner = nil
    }

    private func show(_ purchase: RecordedPurchase) {
        guard PurchasePermissions.canManage(purchasePurchaserId: purchase.purchaser.id, currentUserId: currentUserId) else {
            phase = .failed
            finish = .gone
            return
        }
        phase = .loaded(PurchaseDetailState(purchase: purchase, currencyCode: currencyCode, locale: locale))
        shipping = PurchaseShippingSectionState(purchase: purchase)
        notes = PurchaseNotesSectionState(purchase: purchase)
    }

    // MARK: - Editing

    func editShipping(status: PurchaseShippingStatus, tracking: String) {
        shipping = shipping?.editing(status: status, tracking: tracking)
    }

    func editNotes(text: String) {
        notes = notes?.editing(text: text)
    }

    // MARK: - Shipping

    func saveShipping() async {
        guard !isSavingShipping, let section = shipping, section.canSave, let update = section.update else { return }
        isSavingShipping = true
        defer { isSavingShipping = false }
        do {
            let returned = try await service.updateShipping(id: purchaseId, update: update)
            shipping = section.applying(returned)
            shippingBanner = nil
            announce(update.trackingChange == .clear ? "Tracking number cleared." : "Shipping saved.")
        } catch {
            shippingBanner = bannerAfterFailure(error)
            announceFailure(shippingBanner)
        }
    }

    func dismissShippingError() {
        shippingBanner = nil
    }

    // MARK: - Notes

    func saveNotes() async {
        guard !isSavingNotes, let section = notes, section.canSave, let update = section.update else { return }
        isSavingNotes = true
        defer { isSavingNotes = false }
        do {
            let returned = try await service.updateNotes(id: purchaseId, update: update)
            notes = section.applying(returned)
            notesBanner = nil
            announce("Notes saved.")
        } catch {
            notesBanner = bannerAfterFailure(error)
            announceFailure(notesBanner)
        }
    }

    func dismissNotesError() {
        notesBanner = nil
    }

    // MARK: - Delete

    /// Called by the confirmation dialog's destructive button. Success or not-found (already
    /// removed) both finish with `.deleted`; any other error keeps the purchase on screen.
    func confirmDelete() async {
        guard !isDeleting, case .loaded = phase else { return }
        isDeleting = true
        defer { isDeleting = false }
        let capturedGeneration = service.sessionGeneration
        var deleted = false
        do {
            _ = try await service.deletePurchase(id: purchaseId)
            deleted = true
        } catch PurchaseManagementError.notFound {
            deleted = true
        } catch {
            deleteBanner = bannerAfterFailure(error)
            announceFailure(deleteBanner)
        }
        guard deleted else { return }
        finishDeleted()
        // The follow-up refresh runs here, in the task that ran the delete, so leaving the screen
        // does not cancel it. It stops when the session ended or this task was cancelled, and it never
        // changes `finish` or shows an error.
        let steps = PurchaseRefreshPlan.stepsAfterDelete(
            itemId: itemId, listId: listId, currentItemsListId: refresh.currentItemsListId()
        )
        await refresh.run(steps) { [service] in
            service.sessionGeneration == capturedGeneration && !Task.isCancelled
        }
    }

    func dismissDeleteError() {
        deleteBanner = nil
    }

    private func finishDeleted() {
        deleteBanner = nil
        announce("Purchase deleted.")
        finish = .deleted
    }

    // MARK: - Leaving

    /// Clears every transient error when the screen goes away.
    func disappear() {
        loadBanner = nil
        shippingBanner = nil
        notesBanner = nil
        deleteBanner = nil
    }

    // MARK: - Private

    private static func banner(for error: PurchaseManagementError) -> InlineErrorBannerState {
        InlineErrorBannerState(message: error.userMessage, canRetry: error.isRetryable, isDismissible: true)
    }

    /// The banner for a failed save or delete; nil when nothing is shown (the sign-in flow takes
    /// over, the task was cancelled, or the purchase is gone, in which case the screen finishes).
    private func bannerAfterFailure(_ error: any Error) -> InlineErrorBannerState? {
        if error is CancellationError { return nil }
        guard let failure = error as? PurchaseManagementError else { return Self.banner(for: .server) }
        switch failure {
        case .unauthorized, .sessionEnded:
            return nil
        case .notFound:
            finish = .gone
            return nil
        case .forbidden, .validation, .rateLimited, .network, .invalidResponse, .server:
            return Self.banner(for: failure)
        }
    }

    private func announce(_ text: String, isError: Bool = false) {
        announcement = text
        announcementIsError = isError
        announcementCount += 1
    }

    private func announceFailure(_ banner: InlineErrorBannerState?) {
        guard let banner else { return }
        announce(banner.announcement, isError: true)
    }
}
