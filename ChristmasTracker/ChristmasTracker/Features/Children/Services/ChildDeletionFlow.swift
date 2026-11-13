//
//  ChildDeletionFlow.swift
//  ChristmasTracker
//
//  Deletes a child after archiving the child's active lists (decision L17: the server refuses
//  while any list of the child is ACTIVE or DRAFT). Steps: fresh lists, plan, archive the planned
//  lists in one batch, delete the child. Nothing is published in a shared property by the flow;
//  the typed outcome is returned. A cancelled caller or a cleared session (either service) stops
//  the flow between steps with a nil result, and the child is never deleted afterwards. Nothing
//  here logs names or ids.
//

import Foundation
import Sentry

/// The outcome of a finished deletion flow. nil (from `run` and `execute`) means the flow was
/// cancelled or the session ended: show nothing.
nonisolated enum ChildDeletionResult: Equatable, Sendable {
    case deleted
    case archivedThenDeleted(count: Int)
    /// An archive failed: the child was NOT deleted. Counts only.
    case partialFailure(archivedCount: Int, totalCount: Int, error: ChildError)
    case blocked
    case failed(error: ChildError)
}

@MainActor
final class ChildDeletionFlow {
    private let childService: ChildService
    private let listService: ListService

    init(childService: ChildService, listService: ListService) {
        self.childService = childService
        self.listService = listService
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No child or list data goes into the span.
    /// Fetches the lists afresh (never the cache) and plans the deletion. Throws the mapped
    /// ChildError when the fetch fails, CancellationError when cancelled or the session ended.
    func plan(childId: String) async throws -> ChildDeletionPlan {
        let span = SentrySDK.startTransaction(
            name: "service.children.deletionFlow.plan",
            operation: "service.children.deletionFlow.plan"
        )
        defer { span.finish() }
        return try await plan(childId: childId, childGeneration: childService.sessionGeneration)
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see plan.
    /// Plans, then executes. Returns nil when cancelled or the session ended.
    func run(childId: String) async -> ChildDeletionResult? {
        let span = SentrySDK.startTransaction(
            name: "service.children.deletionFlow.run",
            operation: "service.children.deletionFlow.run"
        )
        defer { span.finish() }

        let childGeneration = childService.sessionGeneration
        let listGeneration = listService.sessionGeneration
        let planned: ChildDeletionPlan
        do {
            planned = try await plan(childId: childId, childGeneration: childGeneration)
        } catch is CancellationError {
            return nil
        } catch let error as ChildError {
            return .failed(error: error)
        } catch {
            return .failed(error: .server)
        }
        return await execute(
            childId: childId, plan: planned, childGeneration: childGeneration, listGeneration: listGeneration
        )
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see plan.
    /// Carries out a plan. Returns nil when cancelled or the session ended; the child is never
    /// deleted after that.
    func execute(childId: String, plan: ChildDeletionPlan) async -> ChildDeletionResult? {
        let span = SentrySDK.startTransaction(
            name: "service.children.deletionFlow.execute",
            operation: "service.children.deletionFlow.execute"
        )
        defer { span.finish() }
        return await execute(
            childId: childId,
            plan: plan,
            childGeneration: childService.sessionGeneration,
            listGeneration: listService.sessionGeneration
        )
    }

    // MARK: - Private

    // Covered by the manual spans of its public callers.
    private func plan(childId: String, childGeneration: Int) async throws -> ChildDeletionPlan {
        let listGeneration = listService.sessionGeneration
        guard isCurrent(childGeneration: childGeneration, listGeneration: listGeneration) else {
            throw CancellationError()
        }
        let lists: [GiftList]
        do {
            lists = try await listService.freshLists()
        } catch let error as ListError {
            throw Self.childError(for: error)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ChildError.server
        }
        guard isCurrent(childGeneration: childGeneration, listGeneration: listGeneration) else {
            throw CancellationError()
        }
        return ChildDeletionPlan.plan(childId: childId, lists: lists)
    }

    // Covered by the manual spans of its public callers.
    private func execute(
        childId: String,
        plan: ChildDeletionPlan,
        childGeneration: Int,
        listGeneration: Int
    ) async -> ChildDeletionResult? {
        guard isCurrent(childGeneration: childGeneration, listGeneration: listGeneration) else { return nil }

        switch plan {
        case .blocked:
            return .blocked
        case .deleteNow:
            return await deleteChild(childId: childId, archivedCount: 0)
        case .archiveThenDelete(let listIds):
            let batch = await listService.archiveLists(ids: listIds)
            guard isCurrent(childGeneration: childGeneration, listGeneration: listGeneration) else { return nil }
            if let failure = batch.failure {
                return .partialFailure(
                    archivedCount: batch.archivedCount,
                    totalCount: batch.totalCount,
                    error: Self.childError(for: failure)
                )
            }
            // Stopped without a failure: the session ended or the caller was cancelled.
            guard batch.archivedCount == batch.totalCount else { return nil }
            return await deleteChild(childId: childId, archivedCount: batch.archivedCount)
        }
    }

    // Covered by the manual spans of its public callers.
    private func deleteChild(childId: String, archivedCount: Int) async -> ChildDeletionResult? {
        func success() -> ChildDeletionResult {
            archivedCount > 0 ? .archivedThenDeleted(count: archivedCount) : .deleted
        }
        do {
            try await childService.deleteChild(id: childId)
            return success()
        } catch is CancellationError {
            return nil
        } catch ChildError.childNotFound {
            // Already gone on the server.
            return success()
        } catch let error as ChildError {
            return .failed(error: error)
        } catch {
            return .failed(error: .server)
        }
    }

    private func isCurrent(childGeneration: Int, listGeneration: Int) -> Bool {
        !Task.isCancelled
            && childService.sessionGeneration == childGeneration
            && listService.sessionGeneration == listGeneration
    }

    private static func childError(for error: ListError) -> ChildError {
        switch error {
        case .forbidden: return .forbidden
        case .unauthorized: return .unauthorized
        case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
        case .network: return .network
        case .invalidResponse: return .invalidResponse
        case .server: return .server
        case .sessionEnded: return .sessionEnded
        default: return .server
        }
    }
}
