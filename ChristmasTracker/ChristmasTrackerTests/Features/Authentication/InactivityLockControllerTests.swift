//
//  InactivityLockControllerTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1 / R1: InactivityLockController state machine.
//
//  Deleted (R1 rework — vacuous/redundant):
//    - sceneCycleExceedingTimeoutCausesLock       (only asserted .unlocked after stop(); never locked)
//    - unlockAfterLockRestoresUnlockedState        (called unlock() on an already-unlocked controller)
//    - recordActivityWhenLockedIsNoOp (first, line ~138) (only called recordActivity on unlocked; asserted .unlocked)
//    - sceneHandlersAttachedAfterStart             (redundant: R1 test 7 covers the same guard)
//    - controllerDoesNotLockWhenNotStarted         (redundant: R1 test 7 covers this directly)
//
//  Rewritten (locked-state injection via tracker.enteredBackground removed — won't compile after R1):
//    - backgroundReturnAfterTimeoutLocks           → sceneDidBecomeActiveAfterTimeoutLocks
//    - backgroundReturnBeforeTimeoutDoesNotLock    → sceneDidBecomeActiveBeforeTimeoutDoesNotLock
//    - unlockAfterTrackerInjectedLockRestoresUnlocked → unlockAfterSceneLockRestoresUnlocked
//    - recordActivityWhenLockedIsNoOpAndStaysLocked → same name, new body
//    - clearForSessionResetsLockedController       → same name, new body
//
//  Added (R1 — 11 new controller tests with fake clock + fake sleeper):
//    1. foregroundIdleFiresTimerAtDeadline
//    2. timerReleasedOneSecondEarlyReschedulesForSameDeadline
//    3. unlockAfterIdleLock_freshDeadlineAndNoRelockOnNewDeadlineMinusOne
//    4. cumulativeInactivity_9minIdle_2minBackground_locks
//    5. cumulativeInactivity_5minIdle_3minBackground_doesNotLock_deadlineUnchanged
//    6. becameActiveBoundary_exactDeadlineLocks
//    7. becameActiveBoundary_oneNanosecondBeforeDeadlineDoesNotLock
//    8. sceneEventsBeforeStartAndAfterStopNeverLock
//    9. startResetsDeadline_priorFakeClockAdvanceDoesNotCauseLock
//    10. recordActivityWhileRunningPushesDeadlineAndReschedules
//    11. clearForSession_resetsLockedRunningControllerToUnlockedAndNotRunning
//
//  Concurrency: all controller tests are @MainActor (controller is @MainActor).
//  Tests that use the timer/sleeper path use Task.yield() — no real Task.sleep.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Fakes

/// Minimal in-test fake policy with a configurable timeout.
private struct FakePolicy: LockTimeoutProviding {
    let timeoutMinutes: Int
}

/// Minimal SceneEventProviding fake that holds the closure references.
private final class FakeSceneEventProvider: SceneEventProviding {
    var willResignActiveHandler: (() -> Void)?
    var didBecomeActiveHandler: (() -> Void)?
}

// MARK: - Suite

@Suite("InactivityLockController Tests")
@MainActor
struct InactivityLockControllerTests {

    // MARK: - Factories

    /// Original factory (no clock injection) — still used for tests that do not
    /// exercise the timer path (usePasswordTeardown, clearForSession on unlocked, etc.)
    private func makeSUT(timeoutMinutes: Int = 10) -> (
        controller: InactivityLockController,
        sceneProvider: FakeSceneEventProvider
    ) {
        let policy = FakePolicy(timeoutMinutes: timeoutMinutes)
        let controller = InactivityLockController(policy: policy)
        let sceneProvider = FakeSceneEventProvider()
        controller.sceneEventProvider = sceneProvider
        return (controller, sceneProvider)
    }

    /// Factory with injected clock and sleeper seams — required for R1 timer tests.
    /// Will fail to compile until InactivityLockController gains clockNow: and sleepUntil: params.
    private func makeController(
        timeoutMinutes: Int = 10,
        clock: FakeClock,
        sleeper: FakeSleeper
    ) -> InactivityLockController {
        InactivityLockController(
            policy: FakePolicy(timeoutMinutes: timeoutMinutes),
            clockNow: { clock.now },
            sleepUntil: { deadline in try await sleeper.sleep(until: deadline) }
        )
    }

    // MARK: - Existing passing tests (retained as-is)

    @Test("Initial state is .unlocked")
    func initialStateIsUnlocked() {
        let (controller, _) = makeSUT()
        #expect(controller.lockState == .unlocked)
    }

    @Test("clearForSession() resets lockState to .unlocked (unlocked controller)")
    func clearForSessionResetsToUnlocked() async throws {
        let (controller, _) = makeSUT()
        controller.start()
        try await controller.clearForSession()
        #expect(controller.lockState == .unlocked)
    }

    @Test("sceneCycleBeforeTimeoutDoesNotLock — immediate return after resign")
    func sceneCycleBeforeTimeoutDoesNotLock() async throws {
        let (controller, _) = makeSUT(timeoutMinutes: 10)
        controller.start()
        controller.sceneWillResignActive()
        // Return immediately — elapsed << timeout
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked)
        controller.stop()
    }

    @Test("usePasswordTeardown() calls authService.logout with reason .lockFallback")
    @MainActor
    func usePasswordTeardownCallsAuthServiceLogout() async throws {
        let (controller, _) = makeSUT()
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: mockRepo)
        let authService = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true,
                "Precondition: must be authenticated before lockFallback")

        controller.authService = authService
        let teardownTask = controller.usePasswordTeardown()
        await teardownTask.value
        #expect(authService.isAuthenticated == false,
                "usePasswordTeardown must call logout(reason: .lockFallback), leaving authService signed out")
    }

    @Test(".lockFallback TeardownReason case exists and is distinct from other cases")
    func lockFallbackTeardownReasonCaseExists() {
        let reason: TeardownReason = .lockFallback
        switch reason {
        case .lockFallback:
            #expect(Bool(true))
        case .userLogout, .sessionExpired, .forcedUpdate:
            Issue.record("Expected .lockFallback but matched another case")
        }
    }

    // MARK: - Rewritten: locked-state injection (fake clock + scene events)
    //
    // These 5 tests previously used controller.tracker.enteredBackground(at:) to inject
    // locked state. That API is removed in R1. The tests now use the fake clock to advance
    // past the deadline, then call sceneDidBecomeActive() which checks isTimedOut(at: clock.now).
    //
    // All 5 will fail to compile until:
    //   - InactivityLockController gains clockNow: and sleepUntil: init params
    //   - InactivityLockController.isRunning exists
    //   - InactivityTracker.enteredBackground is removed

    @Test("sceneDidBecomeActive after timeout locks the controller")
    func sceneDidBecomeActiveAfterTimeoutLocks() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield() // let timer task reach sleeper.sleep()
        // Advance past the 10-minute deadline
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .locked,
                "sceneDidBecomeActive after timeout must lock the controller")
        controller.stop()
    }

    @Test("sceneDidBecomeActive before timeout does not lock the controller")
    func sceneDidBecomeActiveBeforeTimeoutDoesNotLock() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        // Advance to deadline - 10 seconds
        clock.advance(by: .seconds(10 * 60 - 10))
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked,
                "sceneDidBecomeActive before timeout must not lock the controller")
        controller.stop()
    }

    @Test("unlock() after scene-driven lock restores .unlocked")
    func unlockAfterSceneLockRestoresUnlocked() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked before testing unlock()")
        controller.unlock()
        #expect(controller.lockState == .unlocked,
                "unlock() must set lockState to .unlocked")
        controller.stop()
    }

    @Test("recordActivity() when locked is a no-op — lockState stays .locked")
    func recordActivityWhenLockedIsNoOpAndStaysLocked() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked")
        controller.recordActivity()
        #expect(controller.lockState == .locked,
                "recordActivity() while locked must not change lockState")
        controller.stop()
    }

    @Test("clearForSession() resets a locked controller to .unlocked")
    func clearForSessionResetsLockedController() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked")
        try await controller.clearForSession()
        #expect(controller.lockState == .unlocked,
                "clearForSession() must reset lockState to .unlocked")
    }

    // MARK: - New tests (R1) — 11 controller tests with fake clock + fake sleeper
    //
    // All 11 fail to compile until InactivityLockController gains clockNow: and sleepUntil: params.

    // R1-1: foreground idle timer fires at the deadline.
    @Test("Foreground idle timer fires at the deadline and locks the controller")
    func foregroundIdleFiresTimerAtDeadline() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield() // let timer task start and reach sleeper.sleep()
        // Advance clock to the deadline, then release the sleeper so checkTimeout runs.
        clock.advance(by: .seconds(10 * 60))
        sleeper.release()
        await Task.yield() // let timer task wake and run checkTimeout()
        #expect(controller.lockState == .locked,
                "Timer released at the deadline must lock the controller")
        controller.stop()
    }

    // R1-2: sleeper released early reschedules for the same original deadline.
    @Test("Timer released one second early reschedules for the same deadline")
    func timerReleasedOneSecondEarlyReschedulesForSameDeadline() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        let originalDeadline = sleeper.requestedDeadline
        try #require(originalDeadline != nil, "Precondition: timer must have requested a deadline")
        // Advance to deadline - 1 second (not yet timed out)
        clock.advance(by: .seconds(10 * 60 - 1))
        sleeper.release()
        await Task.yield() // checkTimeout() sees not-timed-out → reschedules
        #expect(controller.lockState == .unlocked,
                "Released one second early must not lock the controller")
        // The rescheduled deadline must be the same original deadline (not now + timeout).
        #expect(sleeper.requestedDeadline == originalDeadline,
                "Rescheduled deadline must equal the original deadline (same deadline, not reset)")
        controller.stop()
    }

    // R1-3: after idle lock, unlock() gives a fresh deadline and the new timer does
    // not relock one second before the new deadline.
    @Test("After idle lock, unlock() sets fresh deadline; timer does not relock before new deadline")
    func unlockAfterIdleLock_freshDeadlineAndNoRelockOnNewDeadlineMinusOne() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        // Fire the idle timer to lock.
        clock.advance(by: .seconds(10 * 60))
        sleeper.release()
        await Task.yield()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked after idle timeout")
        // Unlock — this must reset the deadline to now + timeout and reschedule the timer.
        controller.unlock()
        await Task.yield() // let new timer task start
        #expect(controller.lockState == .unlocked)
        let newDeadline = sleeper.requestedDeadline
        try #require(newDeadline != nil, "Precondition: new timer must have a requested deadline")
        // Advance to new deadline - 1 second; release early.
        // The clock is currently at original + 10m; advance to newDeadline - 1s.
        // new deadline = clock.now (at time of unlock) + 10 min; advance 10m - 1s more.
        clock.advance(by: .seconds(10 * 60 - 1))
        sleeper.release()
        await Task.yield()
        #expect(controller.lockState == .unlocked,
                "One second before new deadline must not relock the controller")
        controller.stop()
    }

    // R1-4: cumulative inactivity — 9 min foreground idle + 2 min background = lock.
    @Test("Cumulative inactivity: 9 min foreground idle + 2 min background → locked")
    func cumulativeInactivity_9minIdle_2minBackground_locks() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        // 9 minutes of foreground idle (deadline stays at start + 10m)
        clock.advance(by: .seconds(9 * 60))
        // Enter background — R1: sceneWillResignActive is a no-op; deadline unchanged
        controller.sceneWillResignActive()
        // 2 more minutes in background (total 11 minutes since last activity)
        clock.advance(by: .seconds(2 * 60))
        // Return to foreground — clock.now is 11m after last activity, deadline was at 10m
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .locked,
                "9m foreground idle + 2m background must lock (11m total > 10m timeout)")
        controller.stop()
    }

    // R1-5: cumulative inactivity — 5 min idle + 3 min background = no lock; deadline unchanged.
    @Test("Cumulative inactivity: 5 min idle + 3 min background → not locked, deadline unchanged")
    func cumulativeInactivity_5minIdle_3minBackground_doesNotLock_deadlineUnchanged() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        let originalDeadline = controller.tracker.deadline
        // 5 minutes of foreground idle
        clock.advance(by: .seconds(5 * 60))
        controller.sceneWillResignActive()
        // 3 more minutes in background (total 8 minutes since last activity)
        clock.advance(by: .seconds(3 * 60))
        // Return — clock.now is 8m after last activity, deadline was at 10m → not locked
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked,
                "5m + 3m = 8m < 10m timeout must not lock")
        // R1: becameActive is a no-op — deadline must be unchanged.
        #expect(controller.tracker.deadline == originalDeadline,
                "sceneDidBecomeActive when not locking must not reset the deadline")
        controller.stop()
    }

    // R1-6: boundary — exactly at deadline locks.
    @Test("becameActive boundary: exactly at deadline locks")
    func becameActiveBoundary_exactDeadlineLocks() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        // Advance exactly to the deadline.
        clock.advance(by: .seconds(10 * 60))
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .locked,
                "sceneDidBecomeActive at exactly the deadline must lock")
        controller.stop()
    }

    // R1-7: boundary — one nanosecond before deadline does NOT lock.
    @Test("becameActive boundary: one nanosecond before deadline does not lock")
    func becameActiveBoundary_oneNanosecondBeforeDeadlineDoesNotLock() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        // Advance to deadline - 1 nanosecond.
        clock.advance(by: .seconds(10 * 60) - .nanoseconds(1))
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked,
                "sceneDidBecomeActive one nanosecond before deadline must not lock")
        controller.stop()
    }

    // R1-8: scene events before start() and after stop() never lock.
    // Will fail to compile until isRunning exists (and sceneDidBecomeActive has the !isRunning guard).
    @Test("Scene events before start() and after stop() never lock the controller")
    func sceneEventsBeforeStartAndAfterStopNeverLock() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        // Advance far past the deadline BEFORE start() — should have no effect.
        clock.advance(by: .seconds(15 * 60))
        controller.sceneWillResignActive()
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked,
                "Scene events before start() must not lock")
        #expect(controller.isRunning == false,
                "isRunning must be false before start()")

        // Now start and stop, then try scene events again.
        controller.start()
        await Task.yield()
        controller.stop()
        clock.advance(by: .seconds(15 * 60))
        controller.sceneWillResignActive()
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked,
                "Scene events after stop() must not lock")
        #expect(controller.isRunning == false,
                "isRunning must be false after stop()")
    }

    // R1-9: advancing fake clock before start() does not cause immediate lock on start.
    // start() must reset the deadline to clockNow() + timeout.
    @Test("start() resets deadline — prior clock advance does not cause immediate lock")
    func startResetsDeadline_priorFakeClockAdvanceDoesNotCauseLock() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        // Advance clock 15 minutes before calling start().
        clock.advance(by: .seconds(15 * 60))
        // start() must reset the deadline to clock.now + timeout.
        controller.start()
        await Task.yield()
        // Immediately check: clock.now is at +15m; deadline is now +15m + 10m = +25m.
        // isTimedOut = clock.now (+15m) >= deadline (+25m) = false.
        controller.sceneDidBecomeActive()
        #expect(controller.lockState == .unlocked,
                "Immediately after start(), sceneDidBecomeActive must not lock (deadline was just reset)")
        controller.stop()
    }

    // R1-10: recordActivity() while running pushes the deadline and reschedules the timer.
    // While locked: recordActivity() is a no-op — deadline and sleeper unchanged.
    @Test("recordActivity() while running pushes deadline and reschedules; no-op while locked")
    func recordActivityWhileRunningPushesDeadlineAndReschedules() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        let initialDeadline = controller.tracker.deadline
        let initialSleeperDeadline = sleeper.requestedDeadline
        try #require(initialSleeperDeadline != nil, "Precondition: timer must have started")
        // Advance clock 5 minutes, then record activity.
        clock.advance(by: .seconds(5 * 60))
        controller.recordActivity()
        await Task.yield() // let rescheduled timer task reach sleeper.sleep()
        // Deadline must have been pushed: new deadline = clock.now + 10m = initial + 15m.
        #expect(controller.tracker.deadline > initialDeadline,
                "recordActivity() must push the deadline forward")
        #expect(sleeper.requestedDeadline != initialSleeperDeadline,
                "recordActivity() must reschedule the timer for the new deadline")
        let deadlineAfterActivity = controller.tracker.deadline
        let sleeperDeadlineAfterActivity = sleeper.requestedDeadline
        // Now lock the controller.
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked for the locked-path check")
        // While locked, recordActivity() must be a no-op.
        controller.recordActivity()
        await Task.yield()
        #expect(controller.tracker.deadline == deadlineAfterActivity,
                "recordActivity() while locked must not change the deadline")
        #expect(sleeper.requestedDeadline == sleeperDeadlineAfterActivity,
                "recordActivity() while locked must not reschedule the timer")
        controller.stop()
    }

    // R1-11: clearForSession() on a locked, running controller resets to unlocked + not running.
    // Will fail to compile until isRunning exists.
    @Test("clearForSession() resets locked running controller to unlocked and not running")
    func clearForSession_resetsLockedRunningControllerToUnlockedAndNotRunning() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(timeoutMinutes: 10, clock: clock, sleeper: sleeper)
        controller.start()
        await Task.yield()
        // Drive to locked.
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked")
        try #require(controller.isRunning == true,
                     "Precondition: controller must be running")
        try await controller.clearForSession()
        #expect(controller.lockState == .unlocked,
                "clearForSession() must reset lockState to .unlocked")
        #expect(controller.isRunning == false,
                "clearForSession() must set isRunning to false")
    }
}
