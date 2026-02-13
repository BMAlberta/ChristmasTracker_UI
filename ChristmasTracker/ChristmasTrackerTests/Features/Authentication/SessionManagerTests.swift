//
//  SessionManagerTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/12/26.
//

import Testing
@testable import ChristmasTracker
@Suite("SessionManager Tests")
struct SessionManagerTests {
    @Test("Session is valid after start")
    func testSessionValid() async {
        let mockRepo = await MockAuthenticationRepository()
        let manager = SessionManager(authRepository: mockRepo)
        await manager.startSession()
        let isValid = await manager.isSessionValid()
        #expect(isValid == true)
        await manager.stopSession()
    }
    @Test("Session records activity")
    func testRecordActivity() async {
        let mockRepo = await MockAuthenticationRepository()
        let manager = SessionManager(authRepository: mockRepo)
        await manager.startSession()
        await manager.recordActivity()
        let isValid = await manager.isSessionValid()
        #expect(isValid == true)
        await manager.stopSession()
    }
    @Test("Session becomes invalid after stop")
    func testSessionInvalidAfterStop() async {
        let mockRepo = await MockAuthenticationRepository()
        let manager = SessionManager(authRepository: mockRepo)
        await manager.startSession()
        await manager.stopSession()
        let isValid = await manager.isSessionValid()
        #expect(isValid == false)
    }
}
