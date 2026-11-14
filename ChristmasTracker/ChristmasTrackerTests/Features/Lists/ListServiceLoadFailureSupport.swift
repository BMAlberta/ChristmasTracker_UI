//
//  ListServiceLoadFailureSupport.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2 test support. ListService no longer has a shared `error`; it has two scoped load
//  failures. Tests that used `service.error == nil` to mean "nothing was published" now assert
//  this combined view, so a mutation, a cancelled call or a stale result must leave BOTH empty.
//  UX1b B0: the detail failures are keyed by list id, so the combined view covers every key.
//

import Foundation
@testable import ChristmasTracker

extension ListService {
    /// Whichever load failure is set (lists first, then any detail entry). nil means nothing is published.
    var anyLoadFailure: ListError? {
        if let listsLoadFailure { return listsLoadFailure }
        return detailLoadFailures.values.first
    }
}
