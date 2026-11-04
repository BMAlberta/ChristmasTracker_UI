//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI
@preconcurrency import UIKit

// MARK: - LockCoordinator

/// Manages per-scene LockWindowAdapter instances and responds to lock state changes.
/// MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
private final class LockCoordinator {
    private let lockController: InactivityLockController
    private let biometricAuthenticator: any BiometricAuthenticating
    private var adapters: [ObjectIdentifier: LockWindowAdapter] = [:]
    private var touchRecognizers: [ObjectIdentifier: InactivityTouchRecognizer] = [:]

    init(lockController: InactivityLockController,
         biometricAuthenticator: any BiometricAuthenticating) {
        self.lockController = lockController
        self.biometricAuthenticator = biometricAuthenticator
    }

    /// Attaches a passive touch recognizer to the main window of the given scene so
    /// that any user interaction resets the inactivity timer.
    func attachTouchRecognizer(to windowScene: UIWindowScene) {
        let key = ObjectIdentifier(windowScene)
        guard touchRecognizers[key] == nil else { return }
        guard let window = windowScene.windows.first(where: { $0.windowLevel == .normal }) else { return }
        let recognizer = InactivityTouchRecognizer(target: nil, action: nil)
        recognizer.activityHandler = { [weak lockController] in
            lockController?.recordActivity()
        }
        window.addGestureRecognizer(recognizer)
        touchRecognizers[key] = recognizer
    }

    func handleLockStateChange(_ state: InactivityLockController.LockState) {
        guard let windowScene = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: {
                $0.activationState == .foregroundActive
                    || $0.activationState == .foregroundInactive
            })
        else { return }

        let key = ObjectIdentifier(windowScene)
        switch state {
        case .locked:
            if adapters[key] == nil {
                let adapter = LockWindowAdapter(scene: windowScene)
                adapters[key] = adapter
                adapter.showLock(
                    controller: lockController,
                    biometricAuthenticator: biometricAuthenticator
                )
            }
        case .unlocked:
            if let adapter = adapters.removeValue(forKey: key) {
                adapter.hideLock()
            }
        }
    }
}

// MARK: - ChristmasTrackerApp

@main
struct ChristmasTrackerApp: App {
    // MARK: - State
    @State private var authService: AuthenticationService
    @State private var apiClient: APIClient
    @State private var listService: ListService
    @State private var itemService: ItemService
    private let sessionManager: SessionManager
    private let privacyCoverCoordinator: PrivacyCoverCoordinator
    private let lockController: InactivityLockController
    private let lockCoordinator: LockCoordinator

    // nonisolated(unsafe): written exactly once during init on MainActor;
    // read in deinit where the app is exclusively owned — no concurrent access.
    nonisolated(unsafe) private var lockObservers: [any NSObjectProtocol] = []

    private struct AppDependencies {
        let apiClient: APIClient
        let authRepository: AuthenticationRepository
        let listRepository: ListRepository
        let itemRepository: ItemRepository

        static func make() -> AppDependencies {
            switch AppConfiguration.apiMode {
            case .mock:
                let apiClient = MockAPIClient.withMockData()
                return AppDependencies(
                    apiClient: apiClient,
                    authRepository: MockAuthenticationRepository(),
                    listRepository: MockListRepository(),
                    itemRepository: MockItemRepository()
                )
            case .real:
                let apiClient = NetworkAPIClient()
                return AppDependencies(
                    apiClient: apiClient,
                    authRepository: NetworkAuthenticationRepository(apiClient: apiClient),
                    listRepository: NetworkListRepository(apiClient: apiClient),
                    itemRepository: NetworkItemRepository(apiClient: apiClient)
                )
            }
        }
    }

    // MARK: - Initialization
    init() {
        // Start crash/performance reporting before anything else
        SentryBootstrap.startIfConfigured()
        // Wipe 4.4 legacy credentials/data on first launch — must run before store reads
        FirstLaunchWipe().performIfNeeded()

        // Start the privacy cover before any app data or session state is built.
        // The coordinator has no dependencies; it must be alive before the first scene event.
        let coordinator = PrivacyCoverCoordinator { object in
            guard let scene = object as? UIWindowScene else { return nil }
            return PrivacyCoverWindowAdapter(scene: scene)
        }
        coordinator.start()
        privacyCoverCoordinator = coordinator

        // Build the lock controller before wiring.
        let lockPolicy = LockPolicy()
        let lc = InactivityLockController(policy: lockPolicy)
        lockController = lc
        lockCoordinator = LockCoordinator(
            lockController: lc,
            biometricAuthenticator: LocalAuthenticationService()
        )

        let dependencies = AppDependencies.make()
        apiClient = dependencies.apiClient

        // List Service
        let listDataStore = ListDataStore()
        let ls = ListService(
            repository: dependencies.listRepository,
            dataStore: listDataStore
        )
        listService = ls

        let itemDataStore = ItemDataStore()
        let is_ = ItemService(
            repository: dependencies.itemRepository,
            dataStore: itemDataStore
        )
        itemService = is_

        // Create session manager with production clearables (6 total; lockController is #6)
        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: ls,
            itemService: is_,
            networkCache: NetworkCache.shared,
            lockController: lc
        )
        let sm = SessionManager(authRepository: dependencies.authRepository,
                                initialClearables: clearables)
        sessionManager = sm

        // Create services
        let auth = AuthenticationService(
            repository: dependencies.authRepository,
            sessionManager: sm
        )
        authService = auth

        // Wire the lock controller's authService reference.
        lc.authService = auth

        // Register scene lifecycle observers for the lock controller.
        // Using synchronous observers (queue: nil) so they run on the main thread inline
        // with the UIKit notification — same pattern as PrivacyCoverCoordinator.start().
        var observers: [any NSObjectProtocol] = []

        let willResign = NotificationCenter.default.addObserver(
            forName: UIScene.willDeactivateNotification,
            object: nil,
            queue: nil
        ) { [weak lc] _ in
            MainActor.assumeIsolated {
                lc?.sceneWillResignActive()
            }
        }
        observers.append(willResign)

        let lkCoordinator = lockCoordinator
        let didActivate = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: nil
        ) { [weak lc] notification in
            let windowScene = notification.object as? UIWindowScene
            MainActor.assumeIsolated {
                lc?.sceneDidBecomeActive()
                if let windowScene {
                    lkCoordinator.attachTouchRecognizer(to: windowScene)
                }
            }
        }
        observers.append(didActivate)

        lockObservers = observers

        LogInfo("App initialized", category: .business)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.authenticationService, authService)
                .environment(\.apiClient, apiClient)
                .environment(\.listService, listService)
                .environment(\.itemService, itemService)
                .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        lockController.authService = authService
                        lockController.start()
                    } else {
                        lockController.stop()
                    }
                }
                .onChange(of: lockController.lockState) { _, lockState in
                    lockCoordinator.handleLockStateChange(lockState)
                }
        }
    }
}
