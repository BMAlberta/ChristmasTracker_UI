//
//  ListServiceLoadFailureSupport.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2 test support. ListService no longer has a shared `error`; it has two scoped load
//  failures. Tests that used `service.error == nil` to mean "nothing was published" now assert
//  this combined view, so a mutation, a cancelled call or a stale result must leave BOTH empty.
//

import Foundation
@testable import ChristmasTracker

extension ListService {
    /// Whichever load failure is set (lists first, then detail). nil means nothing is published.
    var anyLoadFailure: ListError? {
        if let listsLoadFailure { return listsLoadFailure }
        return detailLoadFailure
    }
}
