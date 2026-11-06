//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI
import TrackerAPI
@preconcurrency import UIKit

// MARK: - LockCoordinator

/// Manages per-scene LockWindowAdapter instances and responds to lock state changes.
/// MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
private final class LockCoordinator: InactivityLockPresenting {
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

    // MARK: - InactivityLockPresenting

    func presentLock() {
        handleLockStateChange(.locked)
    }

    func dismissLock() {
        handleLockStateChange(.unlocked)
    }
}

// MARK: - AuthServiceBox

/// A reference container that lets the AccessTokenSeam and SessionRefreshSeam closures
/// reach AuthenticationService after it is created, without creating a circular dependency.
/// @unchecked Sendable: written exactly once during app init on MainActor; never mutated
/// concurrently.
private final class AuthServiceBox: @unchecked Sendable {
    // nonisolated(unsafe): written exactly once during app init on MainActor;
    // read from async closures only after init completes — no concurrent mutation.
    nonisolated(unsafe) var value: AuthenticationService?
    init() { value = nil }
}

// MARK: - AppDependencies

/// Dependency container for the composition root.
struct AppDependencies: Sendable {
    let apiClient: APIClient
    let authRepository: any AuthenticationRepository
    let listRepository: ListRepository
    let itemRepository: ItemRepository
    // Stored as the APIProtocol existential to avoid a linker dependency on
    // OpenAPIRuntime.UniversalClient (@_spi) in the app binary; the generated
    // Client struct is only constructed in TrackerAPI-linked callers.
    // nonisolated(unsafe): Sendable value written once at construction; safe to
    // read from any isolation context since AppDependencies is Sendable.
    nonisolated(unsafe) let trackerClient: (any APIProtocol)?

    /// Build mock dependencies (used in .mock mode and when generatedClient is unavailable).
    static func makeMock() -> AppDependencies {
        let apiClient = MockAPIClient.withMockData()
        return AppDependencies(
            apiClient: apiClient,
            authRepository: MockAuthenticationRepository(),
            listRepository: MockListRepository(),
            itemRepository: MockItemRepository(),
            trackerClient: nil
        )
    }

    /// Build real dependencies using the already-constructed generated client for auth.
    static func makeReal(generatedClient: any APIProtocol) -> AppDependencies {
        let apiClient = NetworkAPIClient()
        return AppDependencies(
            apiClient: apiClient,
            authRepository: GeneratedClientAuthenticationRepository(client: generatedClient),
            listRepository: NetworkListRepository(apiClient: apiClient),
            itemRepository: NetworkItemRepository(apiClient: apiClient),
            trackerClient: generatedClient
        )
    }

    /// Legacy entry-point retained for call-sites that have not been updated.
    static func make() -> AppDependencies {
        switch AppConfiguration.apiMode {
        case .mock:
            return makeMock()
        case .real:
            // Real mode requires generatedClient; fall back to mock if unavailable at this call-site.
            // The composition root in ChristmasTrackerApp.init() builds the client first and calls
            // makeReal(generatedClient:) directly; this fallback path is only hit by legacy callers.
            let apiClient = NetworkAPIClient()
            return AppDependencies(
                apiClient: apiClient,
                authRepository: MockAuthenticationRepository(),
                listRepository: NetworkListRepository(apiClient: apiClient),
                itemRepository: NetworkItemRepository(apiClient: apiClient),
                trackerClient: nil
            )
        }
    }
}

// MARK: - buildGeneratedClient

/// Builds the optional generated TrackerAPI client for a given mode and base URL.
/// Returns nil in mock mode, when serverURL is nil, or when the factory throws (error is logged).
/// Used by ChristmasTrackerApp.init() and the composition-root tests.
nonisolated func buildGeneratedClient(
    mode: APIMode,
    serverURL: URL?,
    info: AppClientInfo,
    tokenProvider: some AccessTokenProviding,
    sessionRefresher: some SessionRefreshing,
    versionOutdatedHandler: some VersionOutdatedHandling,
    requestIDObserver: (any RequestIDObserving)? = nil
) -> (any APIProtocol)? {
    guard mode == .real, let url = serverURL else { return nil }
    do {
        return try TrackerClientFactory.make(
            serverURL: url,
            info: info,
            tokenProvider: tokenProvider,
            sessionRefresher: sessionRefresher,
            versionOutdatedHandler: versionOutdatedHandler,
            requestIDObserver: requestIDObserver
        )
    } catch {
        LogError("Failed to build TrackerAPI client: \(error)", category: .business)
        return nil
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
    @State private var showBiometricSetup = false
    @State private var versionGate: VersionGate
    @State private var versionService: VersionService
    private let sessionManager: SessionManager
    private let privacyCoverCoordinator: PrivacyCoverCoordinator
    private let lockController: InactivityLockController
    private let lockCoordinator: LockCoordinator
    private let sharedLocalAuth: LocalAuthenticationService

    // nonisolated(unsafe): written exactly once during init on MainActor;
    // read in deinit where the app is exclusively owned — no concurrent access.
    nonisolated(unsafe) private var lockObservers: [any NSObjectProtocol] = []

    // nonisolated(unsafe): written exactly once during init on MainActor;
    // accessed only after init completes — no concurrent mutation.
    // Stored as the protocol existential to avoid OpenAPIRuntime.UniversalClient (@_spi)
    // appearing in the app binary's link requirements.
    nonisolated(unsafe) private var generatedClient: (any APIProtocol)?


    // MARK: - Initialization
    init() {
        // Start crash/performance reporting before anything else
        SentryBootstrap.startIfConfigured()
        // Wipe 4.4 legacy credentials/data on first launch — must run before store reads
        FirstLaunchWipe().performIfNeeded()

        // Build versionGate before anything else so it can be passed into the client factory.
        let vg = VersionGate()
        _versionGate = State(initialValue: vg)

        // Start the privacy cover before any app data or session state is built.
        // The coordinator has no dependencies; it must be alive before the first scene event.
        let coordinator = PrivacyCoverCoordinator { object in
            guard let scene = object as? UIWindowScene else { return nil }
            return PrivacyCoverWindowAdapter(scene: scene)
        }
        coordinator.start()
        privacyCoverCoordinator = coordinator

        // Build the lock controller before wiring.
        let localAuth = LocalAuthenticationService()
        sharedLocalAuth = localAuth
        let lockPolicy = LockPolicy()
        let lc = InactivityLockController(policy: lockPolicy)
        lockController = lc
        let lkCoord = LockCoordinator(
            lockController: lc,
            biometricAuthenticator: localAuth
        )
        lc.lockPresenter = lkCoord
        lockCoordinator = lkCoord

        // Build the generated client FIRST so GeneratedClientAuthenticationRepository can be
        // constructed before AuthenticationService. The seams use an AuthServiceBox (an
        // @unchecked Sendable reference container) that is populated after auth is created.
        //
        // AuthServiceBox is nonisolated(unsafe): written exactly once during init on MainActor
        // and read only from async closures that execute after init completes — no concurrent
        // mutation occurs after the assignment in this init.
        let authBox = AuthServiceBox()
        let tokenSeam = AccessTokenSeam(tokenGetter: { [weak authBox] in
            await authBox?.value?.currentAccessToken
        })
        let refreshSeam = SessionRefreshSeam(forceRefresh: { [weak authBox] in
            guard let svc = authBox?.value else { throw AuthenticationError.invalidRefreshToken }
            try await svc.forceRefresh()
        })
        let requestIDSeam = RequestIDSeam(isSentryEnabled: AppConfiguration.sentryDSN != nil)
        let resolvedBaseURL: URL? = AppConfiguration.apiMode == .real ? AppConfiguration.apiBaseURL : nil
        let builtClient = buildGeneratedClient(
            mode: AppConfiguration.apiMode,
            serverURL: resolvedBaseURL,
            info: makeClientInfo(from: Bundle.main.infoDictionary),
            tokenProvider: tokenSeam,
            sessionRefresher: refreshSeam,
            versionOutdatedHandler: vg,
            requestIDObserver: requestIDSeam
        )
        generatedClient = builtClient

        // Build AppDependencies — real mode uses GeneratedClientAuthenticationRepository.
        let dependencies: AppDependencies
        if AppConfiguration.apiMode == .real, let client = builtClient {
            dependencies = AppDependencies.makeReal(generatedClient: client)
        } else {
            dependencies = AppDependencies.makeMock()
        }
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
        // Pass UserDefaultsEnrollmentHistory explicitly for persistence across app launches.
        // AuthenticationService's default enrollmentHistory is EphemeralEnrollmentHistory
        // (non-persistent) so that tests creating instances without an explicit history
        // get per-instance isolation and do not contaminate each other via UserDefaults.
        let auth = AuthenticationService(
            repository: dependencies.authRepository,
            sessionManager: sm,
            enrollmentHistory: UserDefaultsEnrollmentHistory()
        )
        authBox.value = auth  // seam closures can now reach auth
        authService = auth

        let vs = VersionService(repository: MockAppVersionRepository())
        _versionService = State(initialValue: vs)

        // In real mode, start the version-check launch task.
        if AppConfiguration.apiMode == .real, let client = builtClient {
            let realRepo = GeneratedClientAppVersionRepository(
                client: client,
                info: makeClientInfo(from: Bundle.main.infoDictionary)
            )
            let realVS = VersionService(repository: realRepo)
            _versionService = State(initialValue: realVS)
            Task { @MainActor [weak realVS] in
                await realVS?.check()
                if let policy = realVS?.lastPolicy {
                    LogInfo(
                        "Version check: state=\(policy.state) minBuild=\(policy.minimumBuild) latestBuild=\(policy.latestBuild)",
                        category: .business
                    )
                }
            }
        }

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
        ) { [weak lc, weak auth] notification in
            let windowScene = notification.object as? UIWindowScene
            MainActor.assumeIsolated {
                lc?.sceneDidBecomeActive()
                if let windowScene {
                    lkCoordinator.attachTouchRecognizer(to: windowScene)
                }
                auth?.refreshBiometricAvailability()
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
                        lockController.biometricEligibility = { [weak authService] in
                            authService?.enrolledUserMatchesSession ?? false
                        }
                        lockController.start()
                    } else {
                        lockController.stop()
                    }
                }
                .onChange(of: authService.biometricOfferAction) { _, action in
                    if case .showEnablementScreen = action {
                        showBiometricSetup = true
                    }
                }
                .sheet(isPresented: $showBiometricSetup) {
                    BiometricSetupView(
                        model: BiometricEnablementModel(
                            authenticator: sharedLocalAuth,
                            enrollAction: { [weak authService] in
                                try await authService?.enrollCurrentSession()
                            }
                        ),
                        onComplete: { _ in
                            showBiometricSetup = false
                            authService.clearBiometricOfferAction()
                        }
                    )
                    .environment(\.authenticationService, authService)
                }
        }
    }
}
