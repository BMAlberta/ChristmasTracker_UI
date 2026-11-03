//
//  PrivacyCoverCoordinator.swift
//  ChristmasTracker
//

import UIKit

// Coordinates show/hide of the privacy cover across scenes.
// MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
final class PrivacyCoverCoordinator {

    // Receives notification.object (AnyObject); returns nil if the object is not
    // a supported scene type. In production: casts to UIWindowScene and returns a
    // PrivacyCoverWindowAdapter. In tests: returns a fake for any supplied object.
    typealias PresenterFactory = @MainActor (AnyObject) -> (any PrivacyCoverPresenting)?

    private(set) var activePresenters: [ObjectIdentifier: any PrivacyCoverPresenting] = [:]
    private let presenterFactory: PresenterFactory
    private var observationTasks: [Task<Void, Never>] = []

    init(presenterFactory: @escaping PresenterFactory) {
        self.presenterFactory = presenterFactory
    }

    // Starts async observation of scene lifecycle notifications.
    // Idempotent: second call is a no-op.
    func start() {
        guard observationTasks.isEmpty else { return }

        let willDeactivate = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: UIScene.willDeactivateNotification
            )
            for await notification in notifications {
                guard let self, let object = notification.object as? AnyObject else { continue }
                self.handleWillDeactivate(for: object)
            }
        }

        let didActivate = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: UIScene.didActivateNotification
            )
            for await notification in notifications {
                guard let self, let object = notification.object as? AnyObject else { continue }
                self.handleDidActivate(for: object)
            }
        }

        observationTasks = [willDeactivate, didActivate]
    }

    // Shows a cover for the given scene object if one is not already shown.
    // Called by the notification tasks; also callable directly from unit tests.
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
}
