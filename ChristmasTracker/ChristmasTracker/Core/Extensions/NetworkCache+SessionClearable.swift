//
//  NetworkCache+SessionClearable.swift
//  ChristmasTracker

import Foundation

extension NetworkCache: SessionClearable {
    func clearForSession() async throws {
        clear()
    }
}
