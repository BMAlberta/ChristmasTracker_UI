// SessionRefreshSeam.swift — SessionRefreshing implementation.
// Maps AuthenticationError credential failures to SessionRefreshError.credentialFailure.
// TODO(I2b-2b, 2026-11-05): generated auth mapping replaces this error mapping.
import Foundation
import TrackerAPI

final class SessionRefreshSeam: SessionRefreshing {
    private let forceRefresh: @Sendable () async throws -> Void

    init(forceRefresh: @escaping @Sendable () async throws -> Void) {
        self.forceRefresh = forceRefresh
    }

    func refresh() async throws {
        do {
            try await forceRefresh()
        } catch let authError as AuthenticationError {
            if isCredentialFailure(authError, context: .refresh) {
                throw SessionRefreshError.credentialFailure
            }
            throw SessionRefreshError.other(authError)
        } catch {
            throw SessionRefreshError.other(error)
        }
    }
}
