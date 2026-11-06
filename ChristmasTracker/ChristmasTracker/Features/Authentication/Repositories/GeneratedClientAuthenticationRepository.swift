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
///
/// Role handling note: `Components.Schemas.User.RolePayload` only has `USER` and `ADMIN`.
/// Real API responses may include extended role values (`viewer`, `member`, `owner`,
/// `blind_viewer`). When the generated decoder fails on a 2xx response (DecodingError /
/// ClientError), we fall back to a JSONSerialization-based extractor that accepts any
/// role string and maps it to the domain `UserRole`.
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
                    expiresIn: 900
                )
            case .badRequest:
                throw AuthenticationError.validationFailed
            case .unauthorized(let r):
                if let code = try? r.body.json.error.errorCode,
                   code == "INVALID_CREDENTIALS" {
                    throw AuthenticationError.invalidCredentials
                }
                throw AuthenticationError.invalidCredentials
            case .upgradeRequired:
                throw AuthenticationError.updateRequired
            case .tooManyRequests:
                throw AuthenticationError.rateLimited
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented(let status, _):
                // 403 on login means ACCOUNT_DISABLED per error-codes.md; no body decode needed.
                if status == 403 {
                    throw AuthenticationError.accountDisabled
                }
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch {
            return try await reclassifyOrFallbackLogin(error)
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
                    expiresIn: 900
                )
            case .badRequest:
                throw AuthenticationError.validationFailed
            case .forbidden(let r):
                if let code = try? r.body.json.error.errorCode,
                   code == "REGISTRATION_CODE_INVALID" {
                    throw AuthenticationError.invalidRegistrationCode
                }
                throw AuthenticationError.invalidRegistrationCode
            case .conflict:
                throw AuthenticationError.emailAlreadyExists
            case .tooManyRequests:
                throw AuthenticationError.rateLimited
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch {
            return try await reclassifyOrFallbackRegister(error)
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
            case .upgradeRequired:
                throw AuthenticationError.updateRequired
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch {
            return try await reclassifyOrFallbackRefresh(error, originalRefreshToken: refreshToken)
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
            case .internalServerError:
                throw AuthenticationError.serverError
            case .undocumented:
                throw AuthenticationError.serverError
            }
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw reclassifyLogoutError(error)
        }
    }
}

// MARK: - User Mapping (strict, via generated schema)

/// Maps the generated API User schema to the domain User model.
/// Throws `AuthenticationError.invalidResponse` if the email field is nil.
private nonisolated func mapUser(_ schema: Components.Schemas.User) throws -> User {
    guard let email = schema.email else {
        throw AuthenticationError.invalidResponse
    }
    return User(
        id: schema.id,
        email: email,
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

// MARK: - JSONSerialization-based body parsing helpers

/// Collects the response body bytes from a `ClientError`, if available.
/// Returns empty Data if the body is nil or iteration fails.
private nonisolated func collectResponseBody(from clientError: ClientError) async -> Data {
    guard let body = clientError.responseBody else { return Data() }
    var data = Data()
    do { for try await chunk in body { data.append(contentsOf: chunk) } } catch {}
    return data
}

/// Extracts the `errorCode` string and optional `code` integer from a raw error response body.
/// Parses `{ "error": { "code": N, "errorCode": "..." } }` using JSONSerialization — no
/// Codable struct needed.
private nonisolated func extractErrorFields(from rawData: Data) -> (code: Int?, errorCode: String?) {
    guard !rawData.isEmpty,
          let root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
          let errorDict = root["error"] as? [String: Any]
    else { return (nil, nil) }
    let code = errorDict["code"] as? Int
    let errorCode = errorDict["errorCode"] as? String
    return (code, errorCode)
}

// MARK: - Lenient auth-session extractor (JSONSerialization-based)

/// Maps a raw role string from the wire (which may include extended values not in the
/// generated schema) to the domain `UserRole`.
private nonisolated func lenientRoleMap(_ raw: String) -> UserRole {
    switch raw {
    case "ADMIN": return .admin
    case "viewer": return .viewer
    case "member": return .member
    case "owner": return .owner
    case "blind_viewer": return .blindViewer
    default: return .user  // "USER" or unknown
    }
}

/// The result of a lenient auth-session decode attempt.
private nonisolated enum LenientDecodeResult {
    case session(AuthSession)
    case nilEmail
    case notAnAuthResponse
}

/// Attempts to build an `AuthSession` from raw response body bytes using `JSONSerialization`.
/// This avoids hand-written Codable structs that mirror the wire format; instead it navigates
/// the untyped dictionary directly.
/// - Returns `.session` if all required fields are present, `.nilEmail` if the user object
///   is present but email is null, or `.notAnAuthResponse` if the body doesn't look like a
///   successful auth envelope.
private nonisolated func lenientDecodeAuthSession(
    from rawData: Data,
    defaultExpiresIn: Int = 900
) -> LenientDecodeResult {
    guard !rawData.isEmpty,
          let root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
          let dataDict = root["data"] as? [String: Any],
          let userDict = dataDict["user"] as? [String: Any],
          let id = userDict["id"] as? String,
          let firstName = userDict["firstName"] as? String,
          let lastName = userDict["lastName"] as? String,
          let displayName = userDict["displayName"] as? String,
          let isActive = userDict["isActive"] as? Bool,
          let createdAtString = userDict["createdAt"] as? String,
          let updatedAtString = userDict["updatedAt"] as? String,
          let accessToken = dataDict["accessToken"] as? String
    else { return .notAnAuthResponse }

    // The user dict is structurally valid; check for nil email
    guard let email = userDict["email"] as? String else {
        return .nilEmail
    }

    guard let createdAt = try? TrackerDateTranscoder().decode(createdAtString),
          let updatedAt = try? TrackerDateTranscoder().decode(updatedAtString)
    else { return .notAnAuthResponse }

    let lastLoginAt: Date?
    if let lastLoginAtString = userDict["lastLoginAt"] as? String {
        lastLoginAt = try? TrackerDateTranscoder().decode(lastLoginAtString)
    } else {
        lastLoginAt = nil
    }

    let roleString = userDict["role"] as? String ?? "USER"
    let role = lenientRoleMap(roleString)

    let user = User(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        role: role,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastLoginAt: lastLoginAt
    )

    let refreshToken = dataDict["refreshToken"] as? String ?? ""
    let expiresIn = dataDict["expiresIn"] as? Int ?? defaultExpiresIn

    return .session(AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn
    ))
}

// MARK: - ClientError reclassification / lenient fallback

/// Handles errors that escape `client.login(...)`.
///
/// The `Components.Schemas._Error` schema requires a `meta` field that some API responses
/// omit. When the generated decoder fails (wrapping the DecodingError in ClientError),
/// this function classifies the error using:
/// 1. `TrackerAPIError.rateLimited` — thrown by RateLimitMiddleware before the switch
/// 2. The semantic `errorCode` string in the error response body (no HTTP status needed)
/// 3. If the body decodes as an auth session (2xx with extended role), returns it
private nonisolated func reclassifyOrFallbackLogin(_ error: Error) async throws -> AuthSession {
    if case TrackerAPIError.rateLimited = error { throw AuthenticationError.rateLimited }
    guard let clientError = error as? ClientError else { throw AuthenticationError.networkError }
    if case TrackerAPIError.rateLimited = clientError.underlyingError { throw AuthenticationError.rateLimited }

    let rawData = await collectResponseBody(from: clientError)

    // Try to interpret as a successful auth session (2xx with extended role, missing meta)
    switch lenientDecodeAuthSession(from: rawData) {
    case .session(let session): return session
    case .nilEmail: throw AuthenticationError.invalidResponse
    case .notAnAuthResponse: break
    }

    // Classify error response by semantic errorCode string — no HTTP status import needed
    let (numCode, errorCode) = extractErrorFields(from: rawData)
    switch errorCode {
    case "INVALID_CREDENTIALS":
        throw AuthenticationError.invalidCredentials
    case "ACCOUNT_DISABLED":
        throw AuthenticationError.accountDisabled
    case "VALIDATION_ERROR", "INVALID_INPUT":
        throw AuthenticationError.validationFailed
    case "VERSION_OUTDATED":
        throw AuthenticationError.updateRequired
    case "RATE_LIMIT_EXCEEDED":
        throw AuthenticationError.rateLimited
    case "INTERNAL_SERVER_ERROR":
        throw AuthenticationError.serverError
    default:
        // Fall back to classifying by error body `code` integer if present
        if let numCode = numCode {
            throw mapNumericErrorCode(numCode)
        }
        throw AuthenticationError.networkError
    }
}

/// Handles errors that escape `client.register(...)`.
private nonisolated func reclassifyOrFallbackRegister(_ error: Error) async throws -> AuthSession {
    if case TrackerAPIError.rateLimited = error { throw AuthenticationError.rateLimited }
    guard let clientError = error as? ClientError else { throw AuthenticationError.networkError }
    if case TrackerAPIError.rateLimited = clientError.underlyingError { throw AuthenticationError.rateLimited }

    let rawData = await collectResponseBody(from: clientError)

    switch lenientDecodeAuthSession(from: rawData) {
    case .session(let session): return session
    case .nilEmail: throw AuthenticationError.invalidResponse
    case .notAnAuthResponse: break
    }

    let (numCode, errorCode) = extractErrorFields(from: rawData)
    switch errorCode {
    case "REGISTRATION_CODE_INVALID":
        throw AuthenticationError.invalidRegistrationCode
    case "EMAIL_ALREADY_EXISTS":
        throw AuthenticationError.emailAlreadyExists
    case "VALIDATION_ERROR", "INVALID_INPUT":
        throw AuthenticationError.validationFailed
    case "VERSION_OUTDATED":
        throw AuthenticationError.updateRequired
    case "RATE_LIMIT_EXCEEDED":
        throw AuthenticationError.rateLimited
    case "INTERNAL_SERVER_ERROR":
        throw AuthenticationError.serverError
    default:
        if let numCode = numCode {
            throw mapNumericErrorCode(numCode)
        }
        throw AuthenticationError.networkError
    }
}

/// Handles errors that escape `client.refreshToken(...)`.
private nonisolated func reclassifyOrFallbackRefresh(_ error: Error, originalRefreshToken: String) async throws -> AuthSession {
    if case TrackerAPIError.rateLimited = error { throw AuthenticationError.rateLimited }
    guard let clientError = error as? ClientError else { throw AuthenticationError.networkError }
    if case TrackerAPIError.rateLimited = clientError.underlyingError { throw AuthenticationError.rateLimited }

    let rawData = await collectResponseBody(from: clientError)

    switch lenientDecodeAuthSession(from: rawData) {
    case .session(let session): return session
    case .nilEmail: throw AuthenticationError.invalidResponse
    case .notAnAuthResponse: break
    }

    let (numCode, errorCode) = extractErrorFields(from: rawData)
    switch errorCode {
    case "REFRESH_TOKEN_EXPIRED":
        throw AuthenticationError.credentialExpired
    case "REFRESH_TOKEN_INVALID", "REFRESH_TOKEN_MISSING":
        throw AuthenticationError.invalidRefreshToken
    case "VERSION_OUTDATED":
        throw AuthenticationError.updateRequired
    case "RATE_LIMIT_EXCEEDED":
        throw AuthenticationError.rateLimited
    case "INTERNAL_SERVER_ERROR":
        throw AuthenticationError.serverError
    default:
        if let numCode = numCode {
            throw mapNumericErrorCode(numCode)
        }
        throw AuthenticationError.invalidRefreshToken
    }
}

private nonisolated func reclassifyLogoutError(_ error: Error) -> AuthenticationError {
    if case TrackerAPIError.rateLimited = error { return .rateLimited }
    guard let clientError = error as? ClientError else { return .networkError }
    if case TrackerAPIError.rateLimited = clientError.underlyingError { return .rateLimited }
    return .networkError
}

/// Maps a numeric error code (from the `error.code` field) to an `AuthenticationError`.
/// Used as a last-resort fallback when the string `errorCode` is unrecognized.
private nonisolated func mapNumericErrorCode(_ code: Int) -> AuthenticationError {
    switch code {
    case 1001: return .invalidCredentials
    case 1005: return .credentialExpired
    case 1006, 1013: return .invalidRefreshToken
    case 1008: return .accountDisabled
    case 1009: return .emailAlreadyExists
    case 1017: return .invalidRegistrationCode
    case 1014: return .updateRequired
    case 8001, 8002, 9001, 9002: return .rateLimited
    case 9000, 9999: return .serverError
    default: return .networkError
    }
}
