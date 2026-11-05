//
//  InactivityLockController.swift
//  ChristmasTracker
//
//  Manages the inactivity lock state machine. Runs on @MainActor.
//  Scene event wiring is injected via SceneEventProviding for testability.
//  Clock and sleep seams are injected via closures for deterministic unit tests.
//

import Foundation
import TrackerInstrumentation

// MARK: - SceneEventProviding

/// Provides hooks for UIScene lifecycle events so the controller can be
/// tested without a live UISceneDelegate.
internal protocol SceneEventProviding: AnyObject {
    var willResignActiveHandler: (() -> Void)? { get set }
    var didBecomeActiveHandler: (() -> Void)? { get set }
}

// MARK: - InactivityLockController

@MainActor
@Observable
internal final class InactivityLockController {

    // MARK: - Lock State

    internal enum LockState: Equatable {
        case unlocked
        case locked
    }

    private(set) var lockState: LockState = .unlocked
    private(set) var isRunning: Bool = false

    // MARK: - Dependencies

    var sceneEventProvider: (any SceneEventProviding)?
    weak var authService: AuthenticationService?
    var biometricEligibility: (() -> Bool)?
    var lockPresenter: (any InactivityLockPresenting)?

    // MARK: - Private

    // internal for test inspection of deadline state
    internal var tracker: InactivityTracker
    private var timerTask: Task<Void, Never>?

    private let clockNow: @MainActor () -> ContinuousClock.Instant
    private let sleepUntil: @MainActor (ContinuousClock.Instant) async throws -> Void

    // MARK: - Init

    internal init(
        policy: any LockTimeoutProviding,
        clockNow: @escaping @MainActor () -> ContinuousClock.Instant = { ContinuousClock().now },
        sleepUntil: @escaping @MainActor (ContinuousClock.Instant) async throws -> Void = { deadline in
            try await Task.sleep(until: deadline, clock: .continuous)
        }
    ) {
        self.tracker = InactivityTracker(policy: policy)
        self.clockNow = clockNow
        self.sleepUntil = sleepUntil
    }

    // MARK: - Lifecycle

    /// Starts the foreground idle timer and resets the deadline to now + timeout.
    internal func start() {
        isRunning = true
        tracker.recordActivity(at: clockNow())
        scheduleTimerTask()
    }

    /// Cancels the timer and marks the controller as not running. Does NOT change lockState.
    internal func stop() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Activity

    /// Records user activity and reschedules the idle timer.
    /// No-op when the controller is not running or is locked.
    internal func recordActivity() {
        guard isRunning, lockState == .unlocked else { return }
        tracker.recordActivity(at: clockNow())
        scheduleTimerTask()
    }

    // MARK: - Scene Events

    /// Called when the scene will resign active (app backgrounds or is interrupted).
    /// R1: no-op when running — deadline is unchanged; cumulative time is measured from
    /// last recordActivity(). The guard prevents spurious calls when not started.
    internal func sceneWillResignActive() {
        guard isRunning else { return }
        // Intentional no-op: deadline accumulates naturally; no backgroundEntryInstant tracking.
    }

    /// Called when the scene becomes active again.
    /// Checks whether the cumulative elapsed time since last activity meets or exceeds
    /// the timeout, and locks if so.
    internal func sceneDidBecomeActive() {
        guard isRunning else { return }
        if tracker.becameActive(at: clockNow()) {
            guard lockState == .unlocked else { return }
            lockState = .locked
            timerTask?.cancel()
            timerTask = nil
            lockPresenter?.presentLock()
        }
    }

    // MARK: - Unlock

    /// Unlocks the controller, resets the inactivity deadline, and restarts the idle timer.
    internal func unlock() {
        guard lockState == .locked else { return }
        tracker.recordActivity(at: clockNow())
        lockState = .unlocked
        lockPresenter?.dismissLock()
        scheduleTimerTask()
    }

    // MARK: - Fallback

    /// Triggers a full logout via the auth service with reason `.lockFallback`.
    @discardableResult
    internal func usePasswordTeardown() -> Task<Void, Never> {
        // Actor-isolated (@MainActor): manual dispatch to Task — @Instrumented not applicable here.
        let service = authService
        return Task {
            await service?.logout(reason: .lockFallback)
        }
    }

    // MARK: - Private

    private func scheduleTimerTask() {
        timerTask?.cancel()
        let deadline = tracker.deadline
        timerTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sleepUntil(deadline)
            } catch {
                return // Task was cancelled or CancellationError thrown
            }
            self.checkTimeout()
        }
    }

    private func checkTimeout() {
        guard isRunning, lockState == .unlocked else { return }
        if tracker.isTimedOut(at: clockNow()) {
            lockState = .locked
            timerTask = nil
            lockPresenter?.presentLock()
        } else {
            // Not yet timed out — reschedule for the same deadline (no reset)
            scheduleTimerTask()
        }
    }
}

// MARK: - SessionClearable

extension InactivityLockController: SessionClearable {
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    internal func clearForSession() async throws {
        let transaction = SentrySDK.startTransaction(
            name: "service.lockController.clearForSession",
            operation: "service.lockController.clearForSession"
        )
        defer { transaction.finish() }
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
        if lockState == .locked {
            lockPresenter?.dismissLock()
        }
        lockState = .unlocked
    }
}
