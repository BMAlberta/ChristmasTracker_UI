//
//  LinkPreviewInput.swift
//  ChristmasTracker
//
//  The rule for which page URLs may be sent to the link preview call (C19): http or https, a host,
//  no userinfo, at most 2048 characters and no whitespace anywhere (padding included). The value is
//  returned unchanged; it is never logged.
//

import Foundation

nonisolated enum LinkPreviewInput {
    static let maximumLength = 2048

    static func validated(_ value: String) -> String? {
        guard !value.isEmpty, value.count <= maximumLength else { return nil }
        let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard value.rangeOfCharacter(from: forbidden) == nil else { return nil }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil
        else { return nil }
        return value
    }
}
