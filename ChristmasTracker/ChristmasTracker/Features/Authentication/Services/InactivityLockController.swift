//
//  InactivityLockController.swift
//  ChristmasTracker
//
//  Manages the inactivity lock state machine. Runs on @MainActor.
//  Scene event wiring is injected via SceneEventProviding for testability.
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

    // MARK: - Dependencies

    var sceneEventProvider: (any SceneEventProviding)?
    weak var authService: AuthenticationService?
    var preference: (any BiometricUnlockPreferring)?

    // MARK: - Private

    // internal for test injection of pre-expired tracker state
    internal var tracker: InactivityTracker
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    internal init(policy: any LockTimeoutProviding) {
        self.tracker = InactivityTracker(policy: policy)
    }

    // MARK: - Lifecycle

    /// Starts the foreground idle timer. Idempotent — only one timer runs at a time.
    internal func start() {
        scheduleTimer()
    }

    /// Cancels the timer. Does NOT change lockState.
    internal func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Activity

    /// Records user activity and reschedules the idle timer.
    /// No-op when the controller is locked.
    internal func recordActivity() {
        guard lockState == .unlocked else { return }
        tracker.recordActivity(at: ContinuousClock().now)
        scheduleTimer()
    }

    // MARK: - Scene Events

    /// Called when the scene will resign active (app backgrounds or is interrupted).
    internal func sceneWillResignActive() {
        tracker.enteredBackground(at: ContinuousClock().now)
    }

    /// Called when the scene becomes active again.
    internal func sceneDidBecomeActive() {
        let shouldLock = tracker.becameActive(at: ContinuousClock().now)
        if shouldLock {
            lockState = .locked
        }
    }

    // MARK: - Unlock

    /// Unlocks the controller and restarts the idle timer.
    internal func unlock() {
        lockState = .unlocked
        scheduleTimer()
    }

    // MARK: - Fallback

    /// Triggers a full logout via the auth service with reason `.lockFallback`.
    internal func usePasswordTeardown() {
        // Actor-isolated (@MainActor): manual dispatch to Task — @Instrumented not applicable here.
        let service = authService
        Task {
            await service?.logout(reason: .lockFallback)
        }
    }

    // MARK: - Private

    private func scheduleTimer() {
        timerTask?.cancel()
        let deadline = tracker.deadline
        timerTask = Task { [weak self] in
            let clock = ContinuousClock()
            do {
                try await clock.sleep(until: deadline)
            } catch {
                return // Task was cancelled
            }
            await self?.checkTimeout()
        }
    }

    private func checkTimeout() {
        guard lockState == .unlocked else { return }
        if tracker.isTimedOut(at: ContinuousClock().now) {
            lockState = .locked
        } else {
            scheduleTimer()
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
        timerTask?.cancel()
        timerTask = nil
        lockState = .unlocked
    }
}
