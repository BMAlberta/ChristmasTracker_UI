//
//  PurchaseDetailModelDeleteRefreshTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-C: the model owns the follow-up refresh of a delete.
//
//   (a) a delete that succeeds while the view is gone (confirmDelete() driven from a task that never
//       reads or observes `finish`) still gives the refresh dependency exactly the three steps of
//       PurchaseRefreshPlan.stepsAfterDelete, in order, once;
//   (b) a not-found delete also refreshes;
//   (c) a failed delete runs no refresh and sets the delete banner;
//   (d) a teardown mid-delete throws away the result: no refresh, nothing written;
//   (e) a session end between two refresh steps stops the remaining steps (the continue-check);
//   (f) a user switch mid-delete runs nothing;
//   (g) finish is .deleted and "Purchase deleted." is announced; a failing refresh step never changes
//       finish or sets a banner;
//   (h) the plan uses the item service's list id at refresh time.
//
//  Determinism: the delete is held by GatedPurchaseManager (nextHeldCall handshake); the refresh
//  dependency is a scripted RefreshProbe whose hooks run at fixed points. No sleeps, no yield loops.
//  All ids are fake.
//
//  These tests pin the model's refresh dependency and the service's sessionGeneration guard.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail model delete refresh Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseDetailModelDeleteRefreshTests {

    // EDITED (I5a-B): both arrays gain the final `.invalidateSpending` step appended by the plan (the names
    // keep "three" for the three refresh steps; the fourth marks the spending caches stale).
    private static let threeStepsLoad: [PurchaseRefreshStep] = [
        .itemDetail(id: PurchaseDetailTest.itemId), .itemsLoad(listId: PurchaseDetailTest.listId),
        .listDetail(id: PurchaseDetailTest.listId), .invalidateSpending
    ]
    private static let threeStepsRefresh: [PurchaseRefreshStep] = [
        .itemDetail(id: PurchaseDetailTest.itemId), .itemsRefresh,
        .listDetail(id: PurchaseDetailTest.listId), .invalidateSpending
    ]

    private func makeSUT(probe: RefreshProbe) async -> PurchaseDetailSUT {
        await makeLoadedPurchaseDetailSUT(refresh: probe.dependency)
    }

    // MARK: (a) the view is gone

    @Test("A delete that succeeds while the view is gone still refreshes: the three plan steps, in order, once")
    func deleteWhileViewGone() async throws {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        // The swipe-back case: only the task that runs confirmDelete() exists; nothing reads `finish`.
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()
        #expect(probe.requested.isEmpty, "nothing refreshes before the delete answered")

        sut.management.gate.releaseAll()
        await task.value

        #expect(probe.requested == [Self.threeStepsLoad])
        #expect(probe.requested == [PurchaseRefreshPlan.stepsAfterDelete(
            itemId: PurchaseDetailTest.itemId, listId: PurchaseDetailTest.listId, currentItemsListId: nil
        )])
        #expect(probe.executed == Self.threeStepsLoad)
        #expect(sut.callsAfterLoad == [.delete(id: PurchaseDetailTest.purchaseId)])
    }

    @Test("The refresh runs after the banner is cleared, the result is announced and finish is .deleted")
    func refreshRunsAfterFinish() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueueFailure(PurchaseManagementError.network)
        await sut.model.confirmDelete()
        #expect(sut.model.deleteBanner != nil)
        #expect(probe.requested.isEmpty)

        sut.management.enqueue(PurchaseDetailTest.own())
        var finishSeen: PurchaseDetailFinish?
        var bannerSeen: InlineErrorBannerState?
        var announcementSeen: String?
        probe.onRun = {
            finishSeen = sut.model.finish
            bannerSeen = sut.model.deleteBanner
            announcementSeen = sut.model.announcement
        }
        await sut.model.confirmDelete()

        #expect(finishSeen == .deleted)
        #expect(bannerSeen == nil)
        #expect(announcementSeen == "Purchase deleted.")
        #expect(probe.requested.count == 1)
    }

    // MARK: (b) not found

    @Test("A not-found answer to the delete also refreshes")
    func notFoundRefreshes() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueueFailure(PurchaseManagementError.notFound)

        await sut.model.confirmDelete()

        #expect(sut.model.finish == .deleted)
        #expect(probe.requested == [Self.threeStepsLoad])
        #expect(probe.executed == Self.threeStepsLoad)
        #expect(sut.hasNoBanner)
    }

    // MARK: (c) failures

    @Test("A failed delete runs no refresh and sets the delete banner",
          arguments: PurchaseDetailTest.retryableErrors)
    func failedDeleteDoesNotRefresh(error: PurchaseManagementError) async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueueFailure(error)

        await sut.model.confirmDelete()

        #expect(probe.requested.isEmpty)
        #expect(sut.model.deleteBanner == PurchaseDetailTest.retryableBanner(error))
        #expect(sut.model.finish == nil)
    }

    @Test("Unauthorized, an ended session and a cancellation run no refresh and show nothing",
          arguments: [PurchaseManagementError.unauthorized, .sessionEnded])
    func signedOutDoesNotRefresh(error: PurchaseManagementError) async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueueFailure(error)

        await sut.model.confirmDelete()

        #expect(probe.requested.isEmpty)
        #expect(sut.hasNoBanner)
        #expect(sut.model.finish == nil)
    }

    @Test("A cancellation thrown by the delete runs no refresh and shows nothing")
    func cancellationDoesNotRefresh() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueueFailure(CancellationError())

        await sut.model.confirmDelete()

        #expect(probe.requested.isEmpty)
        #expect(sut.hasNoBanner)
        #expect(sut.model.finish == nil)
        #expect(sut.model.announcement != "Purchase deleted.")
    }

    @Test("A delete whose task is cancelled while in flight runs no refresh and does not finish")
    func cancelledTaskDoesNotRefresh() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()

        task.cancel()
        sut.management.gate.releaseAll()
        await task.value

        #expect(probe.requested.isEmpty)
        #expect(sut.model.finish == nil)
        #expect(sut.hasNoBanner)
    }

    // MARK: (d) teardown mid-delete

    @Test("A teardown mid-delete throws away the result: no refresh, no finish, no announcement, no banner")
    func teardownMidDelete() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let generationBefore = sut.service.sessionGeneration
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        await task.value

        #expect(sut.service.sessionGeneration != generationBefore)
        #expect(probe.requested.isEmpty)
        #expect(probe.executed.isEmpty)
        #expect(sut.model.finish == nil)
        #expect(sut.model.announcement != "Purchase deleted.")
        #expect(sut.hasNoBanner)
        #expect(sut.model.isDeleting == false)
    }

    // MARK: (e) session ends between two refresh steps

    @Test("A session end between two refresh steps stops the remaining steps")
    func sessionEndBetweenSteps() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own())
        probe.afterStep = { _ in
            if probe.executed.count == 1 {
                await sut.manager.teardown(reason: .userLogout)
            }
        }

        await sut.model.confirmDelete()

        #expect(probe.requested == [Self.threeStepsLoad], "the model asked for the whole plan")
        #expect(probe.executed == [.itemDetail(id: PurchaseDetailTest.itemId)], "only the first step ran")
        #expect(probe.checkAnswers == [true, false], "the check is asked before each step and turned false")
        #expect(sut.model.finish == .deleted, "a session end during the refresh never undoes the delete")
        #expect(sut.hasNoBanner)
    }

    @Test("The continue-check is false once the refresh task is cancelled")
    func cancellationBetweenSteps() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        probe.afterStep = { _ in
            if probe.executed.count == 1 { probe.runningTask?.cancel() }
        }
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        probe.runningTask = task
        _ = await sut.management.gate.nextHeldCall()

        sut.management.gate.releaseAll()
        await task.value

        #expect(probe.executed == [.itemDetail(id: PurchaseDetailTest.itemId)])
        #expect(probe.checkAnswers == [true, false])
        #expect(sut.model.finish == .deleted)
        #expect(sut.hasNoBanner)
    }

    @Test("The continue-check is true for every step while the session stays the same")
    func checkStaysTrueInSameSession() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.confirmDelete()

        // EDITED (I5a-B): four answers, one per step, because the plan gained the final .invalidateSpending step.
        #expect(probe.checkAnswers == [true, true, true, true])
    }

    // MARK: (f) user switch

    @Test("A user switch mid-delete (session cleared, a new session started) runs nothing")
    func userSwitchMidDelete() async throws {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        // The new user's session: the same service answers a new call.
        sut.management.enqueue(PurchaseDetailTest.own())
        _ = try await sut.service.fetchPurchase(id: PurchaseDetailTest.purchaseId)
        sut.management.gate.releaseAll()
        await task.value

        #expect(probe.requested.isEmpty)
        #expect(probe.executed.isEmpty)
        #expect(sut.model.finish == nil)
        #expect(sut.model.announcement != "Purchase deleted.")
        #expect(sut.hasNoBanner)
    }

    // MARK: (g) finish, announcement, failing refresh

    @Test("On success finish is .deleted and Purchase deleted. is announced once; the refresh adds neither a banner nor a second announcement")
    func finishAndAnnouncement() async {
        let probe = RefreshProbe()
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own())
        let countBefore = sut.model.announcementCount

        await sut.model.confirmDelete()

        #expect(sut.model.finish == .deleted)
        #expect(sut.model.announcement == "Purchase deleted.")
        #expect(sut.model.announcementCount == countBefore + 1)
        #expect(sut.model.announcementIsError == false)
        #expect(sut.hasNoBanner)
        #expect(sut.model.isDeleting == false)
    }

    @Test("A failing refresh step never changes finish, never sets a banner and the later steps still run")
    func failingRefreshStep() async {
        let itemRepo = GatedItemRepository()
        let listRepo = GatedListRepository()
        let itemService = ItemService(repository: itemRepo, dataStore: ItemDataStore())
        let listService = ListService(repository: listRepo, dataStore: ListDataStore())
        let runner = PurchaseRefreshRunner(itemService: itemService, listService: listService)
        itemRepo.enqueueFetchItemDetail(.failure(ItemError.server))
        itemRepo.enqueueFetchItems(.failure(ItemError.network))
        listRepo.enqueueFetchListDetail(.failure(ListError.server))
        let refresh = makeRefreshDependency(
            run: { steps, shouldContinue in await runner.run(steps, while: shouldContinue) },
            currentItemsListId: { itemService.currentListId }
        )
        let sut = await makeLoadedPurchaseDetailSUT(refresh: refresh)
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.confirmDelete()

        #expect(sut.model.finish == .deleted)
        #expect(sut.model.announcement == "Purchase deleted.")
        #expect(sut.hasNoBanner)
        #expect(itemRepo.fetchItemDetailCount == 1)
        #expect(itemRepo.fetchItemsCount == 1, "a failed first step did not stop the items step")
        #expect(listRepo.fetchListDetailCount == 1, "a failed second step did not stop the list detail step")
    }

    @Test("An item refetch 404 after the delete drops the item and sets goneItemId; the delete stays a success")
    func itemRefetchNotFound() async {
        let itemRepo = GatedItemRepository()
        let listRepo = GatedListRepository()
        let itemService = ItemService(repository: itemRepo, dataStore: ItemDataStore())
        let listService = ListService(repository: listRepo, dataStore: ListDataStore())
        let runner = PurchaseRefreshRunner(itemService: itemService, listService: listService)
        let item = ItemServiceFix.item(PurchaseDetailTest.itemId)
        itemRepo.enqueueFetchItems(.success([item]))
        await itemService.loadItems(listId: PurchaseDetailTest.listId)
        itemRepo.enqueueFetchItemDetail(.failure(ItemError.notFound))
        itemRepo.enqueueFetchItems(.success([]))
        listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))
        let refresh = makeRefreshDependency(
            run: { steps, shouldContinue in await runner.run(steps, while: shouldContinue) },
            currentItemsListId: { itemService.currentListId }
        )
        let sut = await makeLoadedPurchaseDetailSUT(refresh: refresh)
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.confirmDelete()

        #expect(itemService.goneItemId == PurchaseDetailTest.itemId)
        #expect(itemService.items.isEmpty)
        #expect(sut.model.finish == .deleted)
        #expect(sut.hasNoBanner)
        #expect(listRepo.fetchListDetailCount == 1, "the later steps still ran")
    }

    // MARK: (h) the list id at refresh time

    @Test("The plan uses the item service's list id at refresh time, not at creation time")
    func listIdReadAtRefreshTime() async {
        let probe = RefreshProbe()
        probe.itemsListId = nil
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()

        // The item service loaded this purchase's list while the delete was in flight.
        probe.itemsListId = PurchaseDetailTest.listId
        sut.management.gate.releaseAll()
        await task.value

        #expect(probe.requested == [Self.threeStepsRefresh])
    }

    @Test("Another list in the item service gives an items load of the purchase's list",
          arguments: [nil, "list-OTHER"] as [String?])
    func otherListLoads(current: String?) async {
        let probe = RefreshProbe()
        probe.itemsListId = current
        let sut = await makeSUT(probe: probe)
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.confirmDelete()

        #expect(probe.requested == [Self.threeStepsLoad])
    }

    // MARK: Defaults

    @Test("A model built without a refresh dependency deletes normally and does nothing more")
    func noDependency() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.confirmDelete()

        #expect(sut.model.finish == .deleted)
        #expect(sut.model.announcement == "Purchase deleted.")
        #expect(sut.hasNoBanner)
    }
}
