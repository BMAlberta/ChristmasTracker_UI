//
//  SessionManagerTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/12/26.
//
//  Updated for C2: isSessionValid() and stopSession() removed (dead code cleanup).
//

import Testing
@testable import ChristmasTracker
@Suite("SessionManager Tests")
struct SessionManagerTests {
    @Test("Session starts without error")
    func testSessionStart() async {
        let manager = SessionManager(initialClearables: [])
        await manager.startSession()
        // startSession() must run without throwing or crashing.
    }
    @Test("Session records activity without error")
    func testRecordActivity() async {
        let manager = SessionManager(initialClearables: [])
        await manager.startSession()
        await manager.recordActivity()
        // recordActivity() must run without throwing or crashing.
    }
}
