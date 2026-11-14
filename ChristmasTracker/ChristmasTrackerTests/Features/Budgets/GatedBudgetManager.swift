//
//  GatedBudgetManager.swift
//  ChristmasTrackerTests
//
//  I5a Story B: a scripted, optionally gated BudgetManaging fake for the BudgetService tests. It
//  follows GatedPurchaseManager exactly.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step (an empty script answers
//  BudgetError.server). A step marked `held` suspends the call on a gate until the test releases it,
//  and announces itself through `gate.nextHeldCall()` (a continuation handshake, see HeldCallGate).
//
//  A step carries what the call returns: a budget list, one budget, or "done" (deleteBudget). A call
//  that finds a step of another shape answers BudgetError.invalidResponse, which fails the test that
//  scripted it wrongly instead of hiding the mistake.
//
//  When `gate.honorsCancellation` is true a held call ends early with CancellationError if its task is
//  cancelled (and counts it in `cancelledCallCount`); otherwise it keeps waiting until released.
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class GatedBudgetManager: BudgetManaging, Sendable {

    /// What the service handed to the repository, for the pass-through assertions.
    enum Call: Equatable, Sendable {
        case list
        case get(year: Int)
        case create(CreateBudgetRequest)
        case update(UpdateBudgetRequest)
        case delete(year: Int)
        case duplicate(DuplicateBudgetRequest)
    }

    enum Payload: Sendable {
        case budgets([Budget])
        case budget(Budget)
        case done
    }

    struct Step: Sendable {
        var outcome: Result<Payload, any Error>
        var held: Bool
    }

    private struct State: Sendable {
        var steps: [Step] = []
        var calls: [Call] = []
        var cancelled = 0
    }

    let gate: HeldCallGate<Call>
    private let state = Mutex(State())

    @MainActor
    init() {
        gate = HeldCallGate<Call>()
    }

    // MARK: Script

    func enqueueList(_ budgets: [Budget], held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(.budgets(budgets)), held: held)) }
    }

    func enqueue(_ budget: Budget, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(.budget(budget)), held: held)) }
    }

    func enqueueDeleted(held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(.done), held: held)) }
    }

    func enqueueFailure(_ error: any Error, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .failure(error), held: held)) }
    }

    // MARK: Recorded calls

    var calls: [Call] { state.withLock { $0.calls } }
    var callCount: Int { state.withLock { $0.calls.count } }

    /// How many held calls ended early because their task was cancelled.
    var cancelledCallCount: Int { state.withLock { $0.cancelled } }

    // MARK: BudgetManaging

    func listBudgets() async throws -> [Budget] {
        guard case .budgets(let budgets) = try await run(.list) else { throw BudgetError.invalidResponse }
        return budgets
    }

    func budget(year: Int) async throws -> Budget {
        guard case .budget(let budget) = try await run(.get(year: year)) else { throw BudgetError.invalidResponse }
        return budget
    }

    func create(_ request: CreateBudgetRequest) async throws -> Budget {
        guard case .budget(let budget) = try await run(.create(request)) else { throw BudgetError.invalidResponse }
        return budget
    }

    func update(_ request: UpdateBudgetRequest) async throws -> Budget {
        guard case .budget(let budget) = try await run(.update(request)) else { throw BudgetError.invalidResponse }
        return budget
    }

    func delete(year: Int) async throws {
        guard case .done = try await run(.delete(year: year)) else { throw BudgetError.invalidResponse }
    }

    func duplicate(_ request: DuplicateBudgetRequest) async throws -> Budget {
        guard case .budget(let budget) = try await run(.duplicate(request)) else { throw BudgetError.invalidResponse }
        return budget
    }

    private func run(_ call: Call) async throws -> Payload {
        let step: Step = state.withLock { state in
            state.calls.append(call)
            if state.steps.isEmpty {
                return Step(outcome: .failure(BudgetError.server), held: false)
            }
            return state.steps.removeFirst()
        }
        if step.held {
            do {
                try await gate.hold(call)
            } catch {
                state.withLock { $0.cancelled += 1 }
                throw error
            }
        }
        return try step.outcome.get()
    }
}
