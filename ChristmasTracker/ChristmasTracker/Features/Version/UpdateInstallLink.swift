// UpdateInstallLink.swift
// ChristmasTracker
//
// Pure builder: an optional manifest string becomes an optional itms-services install URL.
// Nothing here logs or records the manifest or the link.

import Foundation

nonisolated enum UpdateInstallLink {
    private static let maxLength = 2048
    private static let prefix = "itms-services://?action=download-manifest&url="

    /// Returns the install URL, or nil when there is no acceptable link.
    static func url(from manifest: String?) -> URL? {
        guard let manifest else { return nil }
        let trimmed = manifest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("itms-services:") {
            return validatedBuiltLink(trimmed)
        }
        guard isAcceptableHTTPS(trimmed), let value = encode(trimmed) else { return nil }
        return URL(string: prefix + value)
    }

    // MARK: private

    /// Accepts only the exact, canonically encoded form this type builds.
    private static func validatedBuiltLink(_ input: String) -> URL? {
        guard input.hasPrefix(prefix) else { return nil }
        let value = String(input.dropFirst(prefix.count))
        guard !value.isEmpty,
              let inner = value.removingPercentEncoding,
              isAcceptableHTTPS(inner),
              encode(inner) == value else { return nil }
        return URL(string: input)
    }

    /// https only, within the length cap, with a host and no userinfo.
    private static func isAcceptableHTTPS(_ string: String) -> Bool {
        guard string.count <= maxLength else { return false }
        let schemePrefix = "https://"
        guard string.lowercased().hasPrefix(schemePrefix) else { return false }
        let rest = string.dropFirst(schemePrefix.count)
        let authority = rest.prefix(while: { $0 != "/" && $0 != "?" && $0 != "#" })
        guard !authority.isEmpty, !authority.contains("@") else { return false }
        return true
    }

    /// Percent-encodes every character except RFC 3986 unreserved characters.
    private static func encode(_ string: String) -> String? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
