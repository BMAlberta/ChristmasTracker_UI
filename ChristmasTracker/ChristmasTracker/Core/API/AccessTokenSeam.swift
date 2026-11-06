// AccessTokenSeam.swift — AccessTokenProviding implementation.
// Closure-injected for testability; production closure captures AuthenticationService weakly.
import Foundation
import TrackerAPI

final class AccessTokenSeam: AccessTokenProviding {
    private let tokenGetter: @Sendable () async -> String?

    init(tokenGetter: @escaping @Sendable () async -> String?) {
        self.tokenGetter = tokenGetter
    }

    func accessToken() async -> String? {
        await tokenGetter()
    }
}
