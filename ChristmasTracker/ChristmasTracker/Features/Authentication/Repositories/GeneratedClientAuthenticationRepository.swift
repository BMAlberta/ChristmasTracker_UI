// GeneratedClientAuthenticationRepository.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

// MARK: - GeneratedClientAuthenticationRepository

/// Repository that calls the generated TrackerAPI client for all authentication operations.
/// Implemented as a final class (not actor) since the only stored property is an immutable
/// `let`; `@Instrumented` handles tracing on each async method.
/// `AuthenticationRepository` is `Sendable`; this type is safe to use from any isolation
/// context because it holds only a `let` reference.
final class GeneratedClientAuthenticationRepository: AuthenticationRepository, @unchecked Sendable {

    private let client: any APIProtocol

    nonisolated init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: - Login

    @Instrumented
    func login(email: String, password: String) async throws -> AuthSession {
        do {
            let input = Operations.Login.Input(
                headers: .init(),
                body: .json(.init(email: email, password: password))
            )
            let output = try await client.login(input)
            switch output {
            case .ok(let r):
                let body = try r.body.json
                let data = body.data
                let user = try mapUser(data.user)
                return AuthSession(
                    user: user,
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken ?? "",
                    expiresIn: data.expiresIn
                )
            case .badRequest(let r):
                let body = try r.body.json
                throw AuthenticationError.validation(message: body.error.message ?? "The information you provided is invalid.")
            case .unauthorized(let r):
                if let code = try? r.body.json.error.errorCode,
                   code == "INVALID_CREDENTIALS" {
                    throw AuthenticationError.invalidCredentials
                }
                throw AuthenticationError.invalidCredentials
            case .forbidden:
                // 403 on login is ACCOUNT_DISABLED (client guide 3.2; documented since C15).
                throw AuthenticationError.accountDisabled
            case .upgradeRequired:
                throw AuthenticationError.updateRequired
            case .tooManyRequests:
                // The generated RateLimitError exposes no typed Retry-After; RateLimitMiddleware
                // normally throws first and its retryAfter flows through classifyClientError.
                throw AuthenticationError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch let clientError as ClientError {
            throw classifyClientError(clientError)
        } catch {
            throw AuthenticationError.networkError
        }
    }

    // MARK: - Register

    @Instrumented
    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        do {
            let input = Operations.Register.Input(
                headers: .init(),
                body: .json(.init(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    registrationCode: registrationCode
                ))
            )
            let output = try await client.register(input)
            switch output {
            case .created(let r):
                let body = try r.body.json
                let data = body.data
                let user = try mapUser(data.user)
                return AuthSession(
                    user: user,
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken ?? "",
                    expiresIn: data.expiresIn
                )
            case .badRequest(let r):
                let body = try r.body.json
                throw AuthenticationError.validation(message: body.error.message ?? "The information you provided is invalid.")
            case .forbidden(let r):
                if let code = try? r.body.json.error.errorCode,
                   code == "REGISTRATION_CODE_INVALID" {
                    throw AuthenticationError.invalidRegistrationCode
                }
                throw AuthenticationError.invalidRegistrationCode
            case .conflict:
                throw AuthenticationError.emailAlreadyExists
            case .tooManyRequests:
                throw AuthenticationError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch let clientError as ClientError {
            throw classifyClientError(clientError)
        } catch {
            throw AuthenticationError.networkError
        }
    }

    // MARK: - Refresh

    @Instrumented
    func refresh(refreshToken: String) async throws -> AuthSession {
        do {
            let input = Operations.RefreshToken.Input(
                headers: .init(),
                body: .json(.init(refreshToken: refreshToken))
            )
            let output = try await client.refreshToken(input)
            switch output {
            case .ok(let r):
                let body = try r.body.json
                let data = body.data
                let user = try mapUser(data.user)
                return AuthSession(
                    user: user,
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken ?? refreshToken,
                    expiresIn: data.expiresIn
                )
            case .unauthorized(let r):
                if let code = try? r.body.json.error.errorCode,
                   code == "REFRESH_TOKEN_EXPIRED" {
                    throw AuthenticationError.credentialExpired
                }
                throw AuthenticationError.invalidRefreshToken
            case .badRequest(let r):
                let body = try r.body.json
                throw AuthenticationError.validation(message: body.error.message ?? "The information you provided is invalid.")
            case .forbidden:
                // 403 on refresh is ACCOUNT_DISABLED (client guide 3.3; documented since C15).
                throw AuthenticationError.accountDisabled
            case .upgradeRequired:
                throw AuthenticationError.updateRequired
            case .tooManyRequests:
                // The generated RateLimitError exposes no typed Retry-After; RateLimitMiddleware
                // normally throws first and its retryAfter flows through classifyClientError.
                throw AuthenticationError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch let clientError as ClientError {
            throw classifyClientError(clientError)
        } catch {
            throw AuthenticationError.networkError
        }
    }

    // MARK: - Logout

    @Instrumented
    func logout() async throws {
        do {
            let input = Operations.Logout.Input(headers: .init())
            let output = try await client.logout(input)
            switch output {
            case .ok:
                return
            case .unauthorized:
                throw AuthenticationError.invalidRefreshToken
            case .forbidden, .notFound:
                // 403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND: the session cannot continue.
                throw AuthenticationError.sessionExpired
            case .tooManyRequests:
                // The generated RateLimitError exposes no typed Retry-After; RateLimitMiddleware
                // normally throws first and its retryAfter flows through classifyClientError.
                throw AuthenticationError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch let clientError as ClientError {
            throw classifyClientError(clientError)
        } catch {
            throw AuthenticationError.networkError
        }
    }
}

// MARK: - User Mapping (strict, via generated schema)

/// Maps the generated API User schema to the domain User model.
/// `email` is required and non-null in the contract (C16), so the mapping cannot fail today.
/// The signature keeps `throws` to avoid churn at the call sites.
private nonisolated func mapUser(_ schema: Components.Schemas.User) throws -> User {
    return User(
        id: schema.id,
        email: schema.email,
        firstName: schema.firstName,
        lastName: schema.lastName,
        displayName: schema.displayName,
        role: mapRole(schema.role),
        isActive: schema.isActive,
        createdAt: schema.createdAt,
        updatedAt: schema.updatedAt,
        lastLoginAt: schema.lastLoginAt
    )
}

private nonisolated func mapRole(_ role: Components.Schemas.User.RolePayload) -> UserRole {
    switch role {
    case .user:
        return .user
    case .admin:
        return .admin
    }
}

// MARK: - ClientError Classification

/// Inspects a `ClientError` from the OpenAPI runtime to classify it as an `AuthenticationError`.
///
/// The OpenAPI runtime wraps all errors (transport, middleware, decoding) in `ClientError`.
/// The `underlyingError` is set to the root cause:
/// - Middleware errors: `underlyingError` is the original error thrown by the middleware
///   (e.g. `TrackerAPIError.rateLimited`)
/// - Transport errors: `underlyingError` is the original transport error (e.g. `URLError`)
/// - Decoding errors: `underlyingError` is a `DecodingError` or `RuntimeError`
private nonisolated func classifyClientError(_ clientError: ClientError) -> AuthenticationError {
    if let apiError = clientError.underlyingError as? TrackerAPIError,
       case .rateLimited(let retryAfter) = apiError {
        return .rateLimited(retryAfter: retryAfter)
    }
    if clientError.underlyingError is URLError {
        return .networkError
    }
    return .invalidResponse
}
