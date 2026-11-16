//
//  LinkPreviewImageFilter.swift
//  ChristmasTracker
//
//  Decision 6: a returned image value is accepted only if ThumbnailURL.validate accepts it (https,
//  host, at most 2048, no whitespace) and it has no userinfo; otherwise nil. The value is never
//  logged.
//

import Foundation

nonisolated enum LinkPreviewImageFilter {
    static func accepted(_ value: String?) -> String? {
        guard let value, let url = ThumbnailURL.validate(value) else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil
        else { return nil }
        return value
    }
}
