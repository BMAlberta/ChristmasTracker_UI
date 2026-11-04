//
//  InactivityLockPresenterTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R2: InactivityLockPresenting protocol conformance.
//  Verifies that the controller calls presentLock() / dismissLock() SYNCHRONOUSLY —
//  no yield required after the triggering method returns.
//
//  Compile failures expected until the implementer:
//    - Creates App/InactivityLockPresenting.swift with the protocol
//    - Adds `var lockPresenter: (any InactivityLockPresenting)?` to InactivityLockController
//    - Calls lockPresenter?.presentLock() synchronously in sceneDidBecomeActive() and checkTimeout()
//    - Calls lockPresenter?.dismissLock() synchronously in unlock() and clearForSession()
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Fakes

/// FakeLockPresenter conforming to InactivityLockPresenting (does not exist yet — will
/// fail to compile until the implementer creates the protocol).
@MainActor
private final class FakeLockPresenter: InactivityLockPresenting {
    private(set) var presentCallCount = 0
    private(set) var dismissCallCount = 0
    func presentLock() { presentCallCount += 1 }
    func dismissLock() { dismissCallCount += 1 }
}

/// Minimal policy stub with configurable timeout.
private struct FakePolicy: LockTimeoutProviding {
    let timeoutMinutes: Int
}

// MARK: - Factory

/// Local factory mirroring InactivityLockControllerTests.makeController — the original
/// is private to that file so we duplicate it here.
@MainActor
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

// MARK: - Suite

@Suite("InactivityLockPresenter Tests")
@MainActor
struct InactivityLockPresenterTests {

    // R2-1: presentLock() is called synchronously when sceneDidBecomeActive detects a timeout.
    // The assertion is made immediately after sceneDidBecomeActive() returns — no yield needed.
    @Test("presentLock() called synchronously before sceneDidBecomeActive returns")
    func presentLockCalledBeforeSceneDidBecomeActiveReturns() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(clock: clock, sleeper: sleeper)
        let presenter = FakeLockPresenter()
        controller.lockPresenter = presenter
        controller.start()
        await Task.yield() // let timer task reach sleeper.sleep()

        // Advance past the 10-minute deadline then trigger the scene event.
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()

        // No yield — if the call is truly synchronous, presentCallCount is already 1.
        #expect(presenter.presentCallCount == 1,
                "presentLock() must be called synchronously within sceneDidBecomeActive()")
        #expect(controller.lockState == .locked,
                "lockState must be .locked immediately after sceneDidBecomeActive()")
        controller.stop()
    }

    // R2-2: dismissLock() is called synchronously when unlock() is called on a locked controller.
    @Test("dismissLock() called synchronously before unlock() returns")
    func dismissLockCalledBeforeUnlockReturns() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(clock: clock, sleeper: sleeper)
        let presenter = FakeLockPresenter()
        controller.lockPresenter = presenter
        controller.start()
        await Task.yield()

        // Drive to locked via scene event.
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked before testing unlock()")

        controller.unlock()

        // No yield — dismissLock() must have been called synchronously within unlock().
        #expect(presenter.dismissCallCount == 1,
                "dismissLock() must be called synchronously within unlock()")
        controller.stop()
    }

    // R2-3: presentLock() is NOT called a second time when the controller is already locked
    // and sceneDidBecomeActive() fires again.
    @Test("presentLock() not called twice when already locked — guard prevents double call")
    func presentLockNotCalledTwiceForRepeatedLockTriggers() async {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(clock: clock, sleeper: sleeper)
        let presenter = FakeLockPresenter()
        controller.lockPresenter = presenter
        controller.start()
        await Task.yield()

        // Lock via first sceneDidBecomeActive.
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        #expect(presenter.presentCallCount == 1,
                "First lock trigger must call presentLock() once")

        // Call sceneDidBecomeActive again — already locked, must NOT call presentLock() again.
        controller.sceneDidBecomeActive()
        #expect(presenter.presentCallCount == 1,
                "Second sceneDidBecomeActive() while already locked must not call presentLock() again")
        controller.stop()
    }

    // R2-4: clearForSession() calls dismissLock() synchronously when the controller is locked.
    @Test("clearForSession() calls dismissLock() synchronously when locked")
    func clearForSessionCallsDismissWhenLocked() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(clock: clock, sleeper: sleeper)
        let presenter = FakeLockPresenter()
        controller.lockPresenter = presenter
        controller.start()
        await Task.yield()

        // Drive to locked.
        clock.advance(by: .seconds(10 * 60 + 1))
        controller.sceneDidBecomeActive()
        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked before clearForSession()")

        try await controller.clearForSession()

        #expect(presenter.dismissCallCount == 1,
                "clearForSession() while locked must call dismissLock() synchronously")
        #expect(controller.lockState == .unlocked,
                "clearForSession() must reset lockState to .unlocked")
    }

    // R2-5: clearForSession() does NOT call dismissLock() when the controller was never locked.
    @Test("clearForSession() does not call dismissLock() when controller is unlocked")
    func clearForSessionDoesNotCallDismissWhenUnlocked() async throws {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = makeController(clock: clock, sleeper: sleeper)
        let presenter = FakeLockPresenter()
        controller.lockPresenter = presenter
        controller.start()
        await Task.yield()

        // Do not lock — call clearForSession() on an unlocked, running controller.
        try await controller.clearForSession()

        #expect(presenter.dismissCallCount == 0,
                "clearForSession() on an already-unlocked controller must NOT call dismissLock()")
    }
}
