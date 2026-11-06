// TrackerURLSessionConfiguration.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

public enum TrackerURLSessionConfiguration {
    public static func make() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default.copy() as? URLSessionConfiguration
            ?? URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpCookieAcceptPolicy = .never
        config.urlCredentialStorage = nil
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return config
    }
}
