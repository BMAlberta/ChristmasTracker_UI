//
//  PrivacyCoverCoordinator.swift
//  ChristmasTracker
//

// @preconcurrency: suppresses strict-concurrency region-isolation errors on the
// addObserver callback parameters. The callbacks run synchronously on the main thread
// (UIKit guarantee); MainActor.assumeIsolated asserts this invariant at runtime.
@preconcurrency import UIKit

// Coordinates show/hide of the privacy cover across scenes.
// MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
final class PrivacyCoverCoordinator {

    // Receives notification.object (AnyObject); returns nil if the object is not
    // a supported scene type. In production: casts to UIWindowScene and returns a
    // PrivacyCoverWindowAdapter. In tests: returns a fake for any supplied object.
    typealias PresenterFactory = @MainActor (AnyObject) -> (any PrivacyCoverPresenting)?

    let notificationCenter: NotificationCenter
    private(set) var activePresenters: [ObjectIdentifier: any PrivacyCoverPresenting] = [:]
    private let presenterFactory: PresenterFactory
    // nonisolated(unsafe): written exactly once during start() on MainActor;
    // read in deinit where the coordinator is exclusively owned — no concurrent access.
    nonisolated(unsafe) private var observers: [any NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default,
         presenterFactory: @escaping PresenterFactory) {
        self.notificationCenter = notificationCenter
        self.presenterFactory = presenterFactory
    }

    // Registers synchronous observers for scene lifecycle notifications.
    // With queue: nil the handler runs on the posting thread (always main for UIKit scene events),
    // so the cover window is shown before the notification post call returns — guaranteeing the
    // app-switcher snapshot captures it. MainActor.assumeIsolated asserts the invariant at runtime.
    // Idempotent: second call is a no-op.
    func start() {
        guard observers.isEmpty else { return }

        let willDeactivate = notificationCenter.addObserver(
            forName: UIScene.willDeactivateNotification, object: nil, queue: nil
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let object = notification.object as? AnyObject else { return }
                self.handleWillDeactivate(for: object)
            }
        }

        let didActivate = notificationCenter.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: nil
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let object = notification.object as? AnyObject else { return }
                self.handleDidActivate(for: object)
            }
        }

        let didDisconnect = notificationCenter.addObserver(
            forName: UIScene.didDisconnectNotification, object: nil, queue: nil
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let object = notification.object as? AnyObject else { return }
                self.handleDidDisconnect(for: object)
            }
        }

        observers = [willDeactivate, didActivate, didDisconnect]
    }

    // Shows a cover for the given scene object if one is not already shown.
    // Called by the notification observers; also callable directly from unit tests.
    func handleWillDeactivate(for object: AnyObject) {
        let id = ObjectIdentifier(object)
        guard activePresenters[id] == nil else { return }
        guard let presenter = presenterFactory(object) else { return }
        activePresenters[id] = presenter
        presenter.showCover()
    }

    // Removes and releases the cover for the given scene object.
    // No-op if no cover is active for the object.
    func handleDidActivate(for object: AnyObject) {
        let id = ObjectIdentifier(object)
        guard let presenter = activePresenters.removeValue(forKey: id) else { return }
        presenter.hideCover()
    }

    // Hides and removes any cover for a disconnected scene.
    // Prevents a stale entry from suppressing a future will-deactivate for another scene.
    // No-op if no cover is active for the object.
    func handleDidDisconnect(for object: AnyObject) {
        let id = ObjectIdentifier(object)
        guard let presenter = activePresenters.removeValue(forKey: id) else { return }
        presenter.hideCover()
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }
}
