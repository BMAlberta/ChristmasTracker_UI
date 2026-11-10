//
//  InertRepositories.swift
//  ChristmasTracker
//
//  Repositories built when real mode has no generated client. Every call throws
//  ConfigurationError.clientUnavailable and nothing returns data, so nothing fake can ever be
//  shown. They exist only to keep the services constructible; the app shows no screen that
//  could call them.
//

import Foundation
import TrackerInstrumentation

nonisolated final class InertAuthenticationRepository: AuthenticationRepository {
    @Instrumented
    func login(email: String, password: String) async throws -> AuthSession {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        registrationCode: String
    ) async throws -> AuthSession {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func refresh(refreshToken: String) async throws -> AuthSession {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func logout() async throws {
        throw ConfigurationError.clientUnavailable
    }
}

nonisolated final class InertListRepository: ListRepository {
    @Instrumented
    func fetchLists() async throws -> [GiftList] {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func fetchListDetail(id: String) async throws -> ListDetail {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func createList(_ input: CreateListInput) async throws -> ListDetail {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func deleteList(id: String) async throws {
        throw ConfigurationError.clientUnavailable
    }
}

nonisolated final class InertItemRepository: ItemRepository {
    @Instrumented
    func fetchItems(listId: String) async throws -> [GiftItem] {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func createItem(listId: String, _ request: CreateItemRequest) async throws -> GiftItem {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func updateItem(id: String, _ request: UpdateItemRequest) async throws -> GiftItem {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func deleteItem(id: String) async throws {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func fetchItemDetail(id: String) async throws -> GiftItem {
        throw ConfigurationError.clientUnavailable
    }
}

/// The API client of the failed state: no request is ever sent.
nonisolated final class InertAPIClient: APIClient {
    func request<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable & Sendable)?,
        forceRefresh: Bool,
        cacheScope: CacheScope
    ) async throws -> T {
        throw ConfigurationError.clientUnavailable
    }
}

/// The version repository of the failed state: no check is ever made.
nonisolated final class InertAppVersionRepository: AppVersionChecking {
    @Instrumented
    func checkVersion() async throws -> VersionPolicy {
        throw ConfigurationError.clientUnavailable
    }
}
