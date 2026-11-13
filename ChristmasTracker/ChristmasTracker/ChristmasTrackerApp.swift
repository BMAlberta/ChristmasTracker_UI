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

// MARK: - AppDependencies

/// Dependency container for the composition root.
struct AppDependencies: Sendable {
    let authRepository: any AuthenticationRepository
    let listRepository: ListRepository
    let memberRepository: any MemberRepository
    let childRepository: any ChildRepository
    let itemRepository: ItemRepository
    let purchaseRecorder: any PurchaseRecording
    let purchaseManager: any PurchaseManaging
    let statsLoader: any StatsLoading
    let budgetManager: any BudgetManaging
    let appVersionRepository: any AppVersionChecking
    // Stored as the APIProtocol existential to avoid a linker dependency on
    // OpenAPIRuntime.UniversalClient (@_spi) in the app binary; the generated
    // Client struct is only constructed in TrackerAPI-linked callers.
    // nonisolated(unsafe): Sendable value written once at construction; safe to
    // read from any isolation context since AppDependencies is Sendable.
    nonisolated(unsafe) let trackerClient: (any APIProtocol)?

    /// Build mock dependencies (used in .mock mode and when generatedClient is unavailable).
    static func makeMock() -> AppDependencies {
        // One list mock is shared, so members and children act on the lists the app shows.
        let lists = MockListRepository()
        // The recorder and the manager share one store, seeded with the mock user's own purchases
        // so their summary rows can be opened. The mock never moves item counts or statuses.
        let purchaseStore = MockPurchaseStore(
            seed: MockPurchaseStore.seedPurchases(from: MockItemSeed.items, for: MockItemRepository.defaultUser)
        )
        // The stats and budget mocks share one store seeded with the current year, so a budget
        // created through one shows in the other. The mock never moves purchase or item data.
        let budgetStore = MockBudgetStore(currentYear: Calendar.current.component(.year, from: Date()))
        return AppDependencies(
            authRepository: MockAuthenticationRepository(),
            listRepository: lists,
            memberRepository: MockMemberRepository(listRepository: lists),
            childRepository: MockChildRepository(listRepository: lists),
            itemRepository: MockItemRepository(
                capabilities: { MockListRepository.capabilities(forListId: $0) ?? MockItemRepository.ownerCapabilities }
            ),
            purchaseRecorder: MockPurchaseRecorder(
                access: { MockPurchaseAccess.fromMockSeed(itemId: $0) },
                store: purchaseStore
            ),
            purchaseManager: MockPurchaseManager(store: purchaseStore, currentUserId: { MockItemRepository.defaultUser.id }),
            statsLoader: MockStatsRepository(store: budgetStore),
            budgetManager: MockBudgetRepository(store: budgetStore),
            appVersionRepository: MockAppVersionRepository(),
            trackerClient: nil
        )
    }

    /// Build real dependencies using the already-constructed generated client for auth.
    static func makeReal(generatedClient: any APIProtocol) -> AppDependencies {
        AppDependencies(
            authRepository: GeneratedClientAuthenticationRepository(client: generatedClient),
            listRepository: GeneratedClientListRepository(client: generatedClient),
            memberRepository: GeneratedClientMemberRepository(client: generatedClient),
            childRepository: GeneratedClientChildRepository(client: generatedClient),
            itemRepository: GeneratedClientItemRepository(client: generatedClient),
            purchaseRecorder: GeneratedClientPurchaseRepository(client: generatedClient),
            purchaseManager: GeneratedClientPurchaseManagementRepository(client: generatedClient),
            statsLoader: GeneratedClientStatsRepository(client: generatedClient),
            budgetManager: GeneratedClientBudgetRepository(client: generatedClient),
            appVersionRepository: GeneratedClientAppVersionRepository(
                client: generatedClient,
                info: makeClientInfo(from: Bundle.main.infoDictionary)
            ),
            trackerClient: generatedClient
        )
    }

    /// Build inert dependencies for the failed bootstrap: every repository call throws
    /// ConfigurationError.clientUnavailable and returns nothing. No mock is constructed.
    static func makeInert() -> AppDependencies {
        AppDependencies(
            authRepository: InertAuthenticationRepository(),
            listRepository: InertListRepository(),
            memberRepository: InertMemberRepository(),
            childRepository: InertChildRepository(),
            itemRepository: InertItemRepository(),
            purchaseRecorder: InertPurchaseRecorder(),
            purchaseManager: InertPurchaseManager(),
            statsLoader: InertStatsLoader(),
            budgetManager: InertBudgetManager(),
            appVersionRepository: InertAppVersionRepository(),
            trackerClient: nil
        )
    }

    /// Resolves the dependencies for the composition root. Real mode without a generated client
    /// never falls back to mock data: the state is `.failed`, one category-only report is made,
    /// and the dependencies are inert. Mock mode is unchanged.
    static func resolve(
        mode: APIMode,
        generatedClient: (any APIProtocol)?,
        reporter: any BootstrapFailureReporting
    ) -> (state: BootstrapState, dependencies: AppDependencies) {
        let state = resolveBootstrap(mode: mode, clientAvailable: generatedClient != nil)
        switch state {
        case .failed:
            reporter.reportClientUnavailable(category: "client_unavailable")
            return (state, makeInert())
        case .ready:
            if mode == .real, let client = generatedClient {
                return (state, makeReal(generatedClient: client))
            }
            return (state, makeMock())
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
    requestIDObserver: (any RequestIDObserving)? = nil,
    sessionEndingHandler: (any SessionEnding)? = nil
) -> (any APIProtocol)? {
    guard mode == .real, let url = serverURL else { return nil }
    do {
        return try TrackerClientFactory.make(
            serverURL: url,
            info: info,
            tokenProvider: tokenProvider,
            sessionRefresher: sessionRefresher,
            versionOutdatedHandler: versionOutdatedHandler,
            requestIDObserver: requestIDObserver,
            sessionEndingHandler: sessionEndingHandler
        )
    } catch {
        // Constant category only: the thrown error can carry the URL.
        LogError("Failed to build TrackerAPI client", category: .business)
        return nil
    }
}

// MARK: - ChristmasTrackerApp

@main
struct ChristmasTrackerApp: App {
    // MARK: - State
    @State private var authService: AuthenticationService
    @State private var listService: ListService
    @State private var itemService: ItemService
    @State private var childService: ChildService
    @State private var purchaseService: PurchaseService
    @State private var statsService: StatsService
    @State private var budgetService: BudgetService
    @State private var spendingCacheInvalidator: SpendingCacheInvalidator
    @State private var showBiometricSetup = false
    @State private var versionGate: VersionGate
    @State private var versionService: VersionService
    private let sessionManager: SessionManager
    private let bootstrapState: BootstrapState
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
        // constructed before AuthenticationService. makeClientSeams() (Core/API/ClientSeams.swift)
        // builds the seams around an AuthServiceBox that the seam closures hold strongly; the box
        // holds the service weakly and is populated after auth is created.
        let seams = makeClientSeams()
        let requestIDSeam = RequestIDSeam(isSentryEnabled: AppConfiguration.sentryDSN != nil)
        let resolvedBaseURL: URL? = AppConfiguration.apiMode == .real ? AppConfiguration.apiBaseURL : nil
        let builtClient = buildGeneratedClient(
            mode: AppConfiguration.apiMode,
            serverURL: resolvedBaseURL,
            info: makeClientInfo(from: Bundle.main.infoDictionary),
            tokenProvider: seams.tokenProvider,
            sessionRefresher: seams.sessionRefresher,
            versionOutdatedHandler: vg,
            requestIDObserver: requestIDSeam,
            sessionEndingHandler: seams.sessionEnding
        )
        generatedClient = builtClient

        // Build AppDependencies. Real mode without a client NEVER falls back to mock data: the
        // state is .failed and the dependencies are inert (the body shows only the error screen).
        let resolved = AppDependencies.resolve(
            mode: AppConfiguration.apiMode,
            generatedClient: builtClient,
            reporter: SentryBootstrapFailureReporter()
        )
        let dependencies = resolved.dependencies
        bootstrapState = resolved.state

        // List Service
        let listDataStore = ListDataStore()
        let ls = ListService(
            repository: dependencies.listRepository,
            memberRepository: dependencies.memberRepository,
            dataStore: listDataStore
        )
        listService = ls

        let cs = ChildService(repository: dependencies.childRepository)
        childService = cs

        let itemDataStore = ItemDataStore()
        let is_ = ItemService(
            repository: dependencies.itemRepository,
            dataStore: itemDataStore
        )
        itemService = is_

        let ps = PurchaseService(
            repository: dependencies.purchaseRecorder,
            management: dependencies.purchaseManager
        )
        purchaseService = ps

        let stats = StatsService(repository: dependencies.statsLoader)
        statsService = stats
        let budgets = BudgetService(repository: dependencies.budgetManager)
        budgetService = budgets
        spendingCacheInvalidator = SpendingCacheInvalidator(statsService: stats, budgetService: budgets)

        // Create session manager with production clearables (10 total; statsService and
        // budgetService are appended last, after purchaseService)
        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: ls,
            itemService: is_,
            networkCache: NetworkCache.shared,
            lockController: lc,
            childService: cs,
            purchaseService: ps,
            statsService: stats,
            budgetService: budgets
        )
        let sm = SessionManager(initialClearables: clearables)
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
        seams.box.value = auth  // seam closures can now reach auth
        authService = auth

        let vs = VersionService(repository: dependencies.appVersionRepository)
        _versionService = State(initialValue: vs)

        // In real mode with a client, start the version-check launch task.
        if AppConfiguration.apiMode == .real, builtClient != nil {
            let realVS = vs
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
            // A failed bootstrap shows ONLY the configuration error: no login, no tabs.
            if let configurationError = ConfigurationErrorState.state(for: bootstrapState) {
                ConfigurationErrorView(state: configurationError)
            } else {
                appContent
            }
        }
    }

    private var appContent: some View {
        ContentView()
                .environment(\.authenticationService, authService)
                .environment(\.listService, listService)
                .environment(\.itemService, itemService)
                .environment(\.childService, childService)
                .environment(\.purchaseService, purchaseService)
                .environment(\.statsService, statsService)
                .environment(\.budgetService, budgetService)
                .environment(\.spendingCacheInvalidator, spendingCacheInvalidator)
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
                .sheet(isPresented: Binding(
                    get: { showBiometricSetup },
                    set: { newValue in
                        showBiometricSetup = newValue
                        if !newValue {
                            authService.clearBiometricOfferAction()
                        }
                    }
                )) {
                    BiometricSetupView(
                        model: BiometricEnablementModel(
                            authenticator: sharedLocalAuth,
                            enrollAction: { [weak authService] in
                                try await authService?.enrollCurrentSession()
                            }
                        ),
                        onComplete: { _ in
                            showBiometricSetup = false
                            // clearBiometricOfferAction() now handled by the binding setter
                        }
                    )
                    .environment(\.authenticationService, authService)
                }
    }
}
