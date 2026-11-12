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
    func removeCoOwner(listId: String) async throws -> ListDetail {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func deleteList(id: String) async throws {
        throw ConfigurationError.clientUnavailable
    }
}

/// A struct so it can be a default argument value of a MainActor initializer.
nonisolated struct InertMemberRepository: MemberRepository {
    @Instrumented
    func addMember(listId: String, _ input: AddMemberInput) async throws -> ListMember {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func removeMember(listId: String, userId: String) async throws {
        throw ConfigurationError.clientUnavailable
    }
}

nonisolated struct InertChildRepository: ChildRepository {
    @Instrumented
    func fetchChildren() async throws -> [Child] {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func createChild(_ input: CreateChildInput) async throws -> Child {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func deleteChild(id: String) async throws {
        throw ConfigurationError.clientUnavailable
    }
}

nonisolated final class InertItemRepository: ItemRepository {
    @Instrumented
    func fetchItems(listId: String) async throws -> [ListItem] {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func createItem(listId: String, _ input: CreateItemInput) async throws -> ListItem {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func updateItem(id: String, _ input: UpdateItemInput) async throws -> ListItem {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func deleteItem(id: String) async throws {
        throw ConfigurationError.clientUnavailable
    }

    @Instrumented
    func fetchItemDetail(id: String) async throws -> ListItem {
        throw ConfigurationError.clientUnavailable
    }
}

nonisolated final class InertPurchaseRecorder: PurchaseRecording {
    @Instrumented
    func createPurchase(
        itemId: String,
        draft: PurchaseDraft,
        confirmationToken: String?
    ) async throws -> PurchaseOutcome {
        throw ConfigurationError.clientUnavailable
    }
}

/// Typed itself (not ConfigurationError) because PurchaseManaging throws PurchaseManagementError only.
nonisolated final class InertPurchaseManager: PurchaseManaging {
    @Instrumented
    func fetchPurchase(id: String) async throws -> RecordedPurchase {
        throw PurchaseManagementError.server
    }

    @Instrumented
    func updateNotes(id: String, update: PurchaseNotesUpdate) async throws -> RecordedPurchase {
        throw PurchaseManagementError.server
    }

    @Instrumented
    func updateShipping(id: String, update: PurchaseShippingUpdate) async throws -> RecordedPurchase {
        throw PurchaseManagementError.server
    }

    @Instrumented
    func deletePurchase(id: String) async throws -> RecordedPurchase {
        throw PurchaseManagementError.server
    }
}

/// The version repository of the failed state: no check is ever made.
nonisolated final class InertAppVersionRepository: AppVersionChecking {
    @Instrumented
    func checkVersion() async throws -> VersionPolicy {
        throw ConfigurationError.clientUnavailable
    }
}
