//
//  PrivacyCoverCoordinatorTests.swift
//  ChristmasTrackerTests
//

import Foundation
import UIKit
import Testing
@testable import ChristmasTracker

// MARK: - Fake

private final class FakePrivacyCoverPresenter: PrivacyCoverPresenting {
    private(set) var showCallCount = 0
    private(set) var hideCallCount = 0

    func showCover() { showCallCount += 1 }
    func hideCover() { hideCallCount += 1 }
}

// MARK: - Fake presenter collection

// Accumulates every presenter ever created (allCreated) and tracks the most recent
// per-object presenter for per-scene assertions.
// @unchecked Sendable: only accessed on MainActor in tests.
private final class FakePresenterCollection: @unchecked Sendable {
    private(set) var allCreated: [FakePrivacyCoverPresenter] = []
    private var latestByScene: [ObjectIdentifier: FakePrivacyCoverPresenter] = [:]

    func makePresenter(for object: AnyObject) -> any PrivacyCoverPresenting {
        let fake = FakePrivacyCoverPresenter()
        allCreated.append(fake)
        latestByScene[ObjectIdentifier(object)] = fake
        return fake
    }

    func latest(for object: AnyObject) -> FakePrivacyCoverPresenter? {
        latestByScene[ObjectIdentifier(object)]
    }
}

// MARK: - Tests

@Suite("PrivacyCoverCoordinator Tests")
@MainActor
struct PrivacyCoverCoordinatorTests {

    private func makeSUT(
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> (coordinator: PrivacyCoverCoordinator, collection: FakePresenterCollection) {
        let collection = FakePresenterCollection()
        let coordinator = PrivacyCoverCoordinator(
            notificationCenter: notificationCenter,
            presenterFactory: { [collection] object in collection.makePresenter(for: object) }
        )
        return (coordinator, collection)
    }

    @Test("will-deactivate calls showCover once for a scene")
    func willDeactivateShowsOneCoverForScene() {
        let (sut, collection) = makeSUT()
        let scene = NSObject()

        sut.handleWillDeactivate(for: scene)

        #expect(collection.latest(for: scene)?.showCallCount == 1)
        #expect(collection.latest(for: scene)?.hideCallCount == 0)
    }

    @Test("repeated will-deactivate for the same scene does not show a second cover")
    func repeatedWillDeactivateForSameSceneIsIdempotent() {
        let (sut, collection) = makeSUT()
        let scene = NSObject()

        sut.handleWillDeactivate(for: scene)
        sut.handleWillDeactivate(for: scene)

        // Only one presenter ever created; show called once.
        #expect(collection.allCreated.count == 1)
        #expect(collection.allCreated.first?.showCallCount == 1)
    }

    @Test("did-activate calls hideCover for the scene that was deactivated")
    func didActivateHidesCoverForScene() {
        let (sut, collection) = makeSUT()
        let scene = NSObject()

        sut.handleWillDeactivate(for: scene)
        sut.handleDidActivate(for: scene)

        #expect(collection.latest(for: scene)?.hideCallCount == 1)
        #expect(sut.activePresenters[ObjectIdentifier(scene)] == nil)
    }

    @Test("did-activate with no active cover is a no-op and does not crash")
    func didActivateWithNoCoverIsNoOp() {
        let (sut, collection) = makeSUT()
        let scene = NSObject()

        // No prior will-deactivate; no presenter was ever created.
        sut.handleDidActivate(for: scene)

        #expect(collection.allCreated.isEmpty)
    }

    @Test("two scenes are tracked independently — deactivating A does not affect B")
    func twoScenesTrackedIndependently() {
        let (sut, collection) = makeSUT()
        let sceneA = NSObject()
        let sceneB = NSObject()

        sut.handleWillDeactivate(for: sceneA)
        sut.handleWillDeactivate(for: sceneB)
        sut.handleDidActivate(for: sceneA)

        // sceneA cover dismissed
        #expect(collection.latest(for: sceneA)?.hideCallCount == 1)
        #expect(sut.activePresenters[ObjectIdentifier(sceneA)] == nil)
        // sceneB cover still active
        #expect(collection.latest(for: sceneB)?.hideCallCount == 0)
        #expect(sut.activePresenters[ObjectIdentifier(sceneB)] != nil)
    }

    @Test("show, hide, show sequence presents twice in total and leaves one cover active")
    func showHideShowSequencePresentsTwiceAndLeavesOneCoverActive() {
        let (sut, collection) = makeSUT()
        let scene = NSObject()

        sut.handleWillDeactivate(for: scene)   // show #1 → allCreated[0]
        sut.handleDidActivate(for: scene)       // hide #1
        sut.handleWillDeactivate(for: scene)   // show #2 → allCreated[1]

        // Two distinct presenters created.
        #expect(collection.allCreated.count == 2)
        // First presenter was shown then hidden.
        #expect(collection.allCreated[0].showCallCount == 1)
        #expect(collection.allCreated[0].hideCallCount == 1)
        // Second presenter is shown and still active.
        #expect(collection.allCreated[1].showCallCount == 1)
        #expect(collection.allCreated[1].hideCallCount == 0)
        #expect(sut.activePresenters[ObjectIdentifier(scene)] != nil)
    }

    // MARK: - Rework R1: synchronous observer tests

    // Synchronous delivery proof: showCover is called before post() returns.
    // There is intentionally no await between post() and the assertion.
    // If the observer were async (e.g. a Task or DispatchQueue.async), showCallCount
    // would still be 0 here. The fact that it is 1 proves synchronous delivery.
    @Test("will-deactivate notification shows cover synchronously — no await required")
    func willDeactivateNotificationShowsCoverSynchronously() {
        let center = NotificationCenter()
        let (sut, collection) = makeSUT(notificationCenter: center)
        sut.start()
        let scene = NSObject()

        center.post(name: UIScene.willDeactivateNotification, object: scene)

        #expect(collection.latest(for: scene)?.showCallCount == 1)
    }

    @Test("did-activate notification hides cover for the deactivated scene")
    func didActivateNotificationHidesCoverForScene() {
        let center = NotificationCenter()
        let (sut, collection) = makeSUT(notificationCenter: center)
        sut.start()
        let scene = NSObject()

        center.post(name: UIScene.willDeactivateNotification, object: scene)
        center.post(name: UIScene.didActivateNotification, object: scene)

        #expect(collection.latest(for: scene)?.hideCallCount == 1)
        #expect(sut.activePresenters[ObjectIdentifier(scene)] == nil)
    }

    @Test("posting will-deactivate twice for the same scene shows cover only once")
    func willDeactivateTwiceForSameSceneShowsOnce() {
        let center = NotificationCenter()
        let (sut, collection) = makeSUT(notificationCenter: center)
        sut.start()
        let scene = NSObject()

        center.post(name: UIScene.willDeactivateNotification, object: scene)
        center.post(name: UIScene.willDeactivateNotification, object: scene)

        #expect(collection.allCreated.count == 1)
        #expect(collection.allCreated.first?.showCallCount == 1)
    }

    @Test("calling start() twice and posting once still shows cover once")
    func startTwicePostOnceShowsOnce() {
        let center = NotificationCenter()
        let (sut, collection) = makeSUT(notificationCenter: center)
        sut.start()
        sut.start()
        let scene = NSObject()

        center.post(name: UIScene.willDeactivateNotification, object: scene)

        #expect(collection.allCreated.count == 1)
        #expect(collection.allCreated.first?.showCallCount == 1)
    }

    @Test("did-disconnect hides active cover and removes it; with no cover it is a no-op")
    func didDisconnectHidesActiveCoverAndIsNoOpWhenNoCover() {
        let center = NotificationCenter()
        let (sut, collection) = makeSUT(notificationCenter: center)
        sut.start()
        let sceneA = NSObject()
        let sceneB = NSObject()

        // Show cover for sceneA then disconnect it.
        center.post(name: UIScene.willDeactivateNotification, object: sceneA)
        center.post(name: UIScene.didDisconnectNotification, object: sceneA)

        #expect(collection.latest(for: sceneA)?.hideCallCount == 1)
        #expect(sut.activePresenters[ObjectIdentifier(sceneA)] == nil)

        // Disconnect sceneB which never had a cover — must be a no-op, no crash.
        center.post(name: UIScene.didDisconnectNotification, object: sceneB)
        #expect(collection.allCreated.count == 1)
    }

    @Test("after a disconnect, will-deactivate for a different scene still shows a cover")
    func afterDisconnect_willDeactivateForDifferentSceneShowsCover() {
        let center = NotificationCenter()
        let (sut, collection) = makeSUT(notificationCenter: center)
        sut.start()
        let sceneA = NSObject()
        let sceneB = NSObject()

        center.post(name: UIScene.willDeactivateNotification, object: sceneA)
        center.post(name: UIScene.didDisconnectNotification, object: sceneA)
        center.post(name: UIScene.willDeactivateNotification, object: sceneB)

        #expect(collection.latest(for: sceneB)?.showCallCount == 1)
        #expect(sut.activePresenters[ObjectIdentifier(sceneB)] != nil)
    }
}
