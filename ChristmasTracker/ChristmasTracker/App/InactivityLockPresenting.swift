//
//  InactivityLockPresenting.swift
//  ChristmasTracker
//
//  Protocol seam for the UI layer to receive synchronous lock/unlock signals
//  from InactivityLockController. The controller calls these methods on MainActor
//  before returning from the triggering method, ensuring no frame gap between
//  the privacy cover hiding and the lock window appearing.
//

/// Receives synchronous lock and unlock events from InactivityLockController.
/// Conforming types (e.g. LockCoordinator in ChristmasTrackerApp) show and hide
/// the lock window in response.
internal protocol InactivityLockPresenting: AnyObject {
    func presentLock()
    func dismissLock()
}
