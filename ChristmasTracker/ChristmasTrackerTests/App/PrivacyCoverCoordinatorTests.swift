//
//  PrivacyCoverCoordinatorTests.swift
//  ChristmasTrackerTests
//

import Foundation
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

    private func makeSUT() -> (coordinator: PrivacyCoverCoordinator, collection: FakePresenterCollection) {
        let collection = FakePresenterCollection()
        let coordinator = PrivacyCoverCoordinator { [collection] object in
            collection.makePresenter(for: object)
        }
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
}
