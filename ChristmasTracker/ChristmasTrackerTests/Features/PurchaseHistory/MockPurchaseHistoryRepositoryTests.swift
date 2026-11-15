//
//  MockPurchaseHistoryRepositoryTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1: the mock repository behind previews and mock mode. At least 25 seeded rows with mixed
//  shipping statuses and at least 3 recipients, newest first. It honors the filter (year = the year of
//  purchasedAt in the current Calendar, recipientId, shippingStatus) and an opaque cursor it issued;
//  the first page has pageSize rows and a cursor; following the cursors yields every matching row
//  exactly once; nextCursor is nil on the last page; an unknown filter yields an empty page.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockPurchaseHistoryRepository", .timeLimit(.minutes(1)))
struct MockPurchaseHistoryRepositoryTests {

    private let seed = MockPurchaseHistoryRepository.seedRows

    private func year(_ row: PurchaseHistoryRow) -> Int {
        Calendar.current.component(.year, from: row.purchasedAt)
    }

    private func matching(_ filter: PurchaseHistoryFilter) -> [PurchaseHistoryRow] {
        seed.filter { row in
            (filter.year == nil || year(row) == filter.year)
                && (filter.recipientId == nil || row.recipientId == filter.recipientId)
                && (filter.shippingStatus == nil || row.shippingStatus == filter.shippingStatus)
        }
    }

    /// Follows the cursors from the first page and returns every page. Stops (and fails) after 200 pages.
    private func allPages(
        _ repo: MockPurchaseHistoryRepository, filter: PurchaseHistoryFilter = PurchaseHistoryFilter()
    ) async throws -> [PurchaseHistoryPage] {
        var pages: [PurchaseHistoryPage] = []
        var cursor: String?
        repeat {
            let page = try await repo.loadPage(filter: filter, cursor: cursor)
            pages.append(page)
            cursor = page.nextCursor
        } while cursor != nil && pages.count < 200
        #expect(pages.count < 200, "the cursors never ended")
        return pages
    }

    // MARK: Seed

    @Test("the seed has at least 25 rows with unique ids")
    func seedSize() {
        #expect(seed.count >= 25)
        #expect(Set(seed.map(\.id)).count == seed.count)
    }

    @Test("the seed has at least 3 recipients and mixed shipping statuses")
    func seedIsMixed() {
        #expect(Set(seed.map(\.recipientId)).count >= 3)
        #expect(Set(seed.map(\.shippingStatus)).count >= 3)
    }

    @Test("a recipient id always goes with the same name")
    func recipientsAreConsistent() {
        var names: [String: String] = [:]
        for row in seed {
            if let known = names[row.recipientId] {
                #expect(known == row.recipientName)
            }
            names[row.recipientId] = row.recipientName
        }
    }

    @Test("the seed is newest first")
    func seedIsNewestFirst() {
        for (newer, older) in zip(seed, seed.dropFirst()) {
            #expect(newer.purchasedAt >= older.purchasedAt)
        }
    }

    @Test("every seed row has a quantity of at least 1 and a non-negative total")
    func seedValuesAreSane() {
        for row in seed {
            #expect(row.quantity >= 1)
            #expect(row.totalCost >= 0)
            #expect(row.itemName.isEmpty == false)
        }
    }

    // MARK: Paging

    @Test("the default page size is the repository page limit")
    func defaultPageSize() async throws {
        let repo = MockPurchaseHistoryRepository()

        let page = try await repo.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(page.rows.count == GeneratedClientPurchaseHistoryRepository.pageLimit)
        #expect(page.nextCursor != nil)
        #expect(page.rows == Array(seed.prefix(20)))
    }

    @Test("the first page has pageSize rows and a cursor", arguments: [1, 5, 7, 10])
    func firstPage(pageSize: Int) async throws {
        let repo = MockPurchaseHistoryRepository(pageSize: pageSize)

        let page = try await repo.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(page.rows.count == pageSize)
        #expect(page.nextCursor?.isEmpty == false)
        #expect(page.rows == Array(seed.prefix(pageSize)))
    }

    @Test("following the cursors yields every row exactly once, in order, and the last cursor is nil",
          arguments: [1, 7, 10, 20, 24])
    func followingCursorsYieldsAll(pageSize: Int) async throws {
        let repo = MockPurchaseHistoryRepository(pageSize: pageSize)

        let pages = try await allPages(repo)

        #expect(pages.flatMap(\.rows) == seed)
        #expect(pages.last?.nextCursor == nil)
        #expect(pages.dropLast().allSatisfy { $0.nextCursor != nil })
        #expect(pages.count >= (seed.count + pageSize - 1) / pageSize)
        #expect(pages.dropLast().allSatisfy { $0.rows.count == pageSize })
    }

    @Test("the default repository pages the seed in at least two pages")
    func defaultPagesInTwo() async throws {
        let pages = try await allPages(MockPurchaseHistoryRepository())

        #expect(pages.count >= 2)
        #expect(pages.flatMap(\.rows) == seed)
    }

    @Test("a page size larger than the seed returns everything with no cursor")
    func oneBigPage() async throws {
        let repo = MockPurchaseHistoryRepository(pageSize: 1000)

        let page = try await repo.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(page.rows == seed)
        #expect(page.nextCursor == nil)
    }

    @Test("every cursor is different")
    func cursorsAreDistinct() async throws {
        let pages = try await allPages(MockPurchaseHistoryRepository(pageSize: 3))

        let cursors = pages.compactMap(\.nextCursor)
        #expect(Set(cursors).count == cursors.count)
    }

    @Test("the same cursor gives the same page again")
    func cursorIsRepeatable() async throws {
        let repo = MockPurchaseHistoryRepository(pageSize: 6)
        let first = try await repo.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        let cursor = try #require(first.nextCursor)

        let one = try await repo.loadPage(filter: PurchaseHistoryFilter(), cursor: cursor)
        let two = try await repo.loadPage(filter: PurchaseHistoryFilter(), cursor: cursor)

        #expect(one == two)
        #expect(one.rows == Array(seed[6..<12]))
    }

    // MARK: Filters

    @Test("the shipping filter narrows the rows to that status", arguments: PurchaseShippingStatus.allCases)
    func shippingFilter(status: PurchaseShippingStatus) async throws {
        let filter = PurchaseHistoryFilter(shippingStatus: status)

        let pages = try await allPages(MockPurchaseHistoryRepository(pageSize: 4), filter: filter)

        let rows = pages.flatMap(\.rows)
        #expect(rows == matching(filter))
        #expect(rows.allSatisfy { $0.shippingStatus == status })
        #expect(rows.count < seed.count || Set(seed.map(\.shippingStatus)).count == 1)
        #expect(pages.last?.nextCursor == nil)
    }

    @Test("the recipient filter narrows the rows to that person")
    func recipientFilter() async throws {
        for recipientId in Set(seed.map(\.recipientId)) {
            let filter = PurchaseHistoryFilter(recipientId: recipientId)

            let pages = try await allPages(MockPurchaseHistoryRepository(pageSize: 4), filter: filter)

            let rows = pages.flatMap(\.rows)
            #expect(rows == matching(filter))
            #expect(rows.isEmpty == false)
            #expect(rows.count < seed.count, "a recipient filter must narrow the list")
            #expect(rows.allSatisfy { $0.recipientId == recipientId })
        }
    }

    @Test("the year filter uses the year of purchasedAt in the current Calendar")
    func yearFilter() async throws {
        for seedYear in Set(seed.map(year)) {
            let filter = PurchaseHistoryFilter(year: seedYear)

            let pages = try await allPages(MockPurchaseHistoryRepository(pageSize: 4), filter: filter)

            let rows = pages.flatMap(\.rows)
            #expect(rows == matching(filter))
            #expect(rows.isEmpty == false)
            #expect(rows.allSatisfy { year($0) == seedYear })
        }
    }

    @Test("filters combine: year, recipient and shipping together")
    func combinedFilters() async throws {
        let recipients = Set(seed.map(\.recipientId))
        let years = Set(seed.map(year))
        for recipientId in recipients {
            for status in PurchaseShippingStatus.allCases {
                for seedYear in years {
                    let filter = PurchaseHistoryFilter(year: seedYear, recipientId: recipientId, shippingStatus: status)

                    let pages = try await allPages(MockPurchaseHistoryRepository(pageSize: 2), filter: filter)

                    #expect(pages.flatMap(\.rows) == matching(filter))
                    #expect(pages.last?.nextCursor == nil)
                }
            }
        }
    }

    @Test("an unknown recipient yields an empty page with no cursor")
    func unknownRecipient() async throws {
        let repo = MockPurchaseHistoryRepository()

        let page = try await repo.loadPage(filter: PurchaseHistoryFilter(recipientId: "nobody-here"), cursor: nil)

        #expect(page.rows.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("a year with no purchases yields an empty page with no cursor")
    func unknownYear() async throws {
        let repo = MockPurchaseHistoryRepository()

        let page = try await repo.loadPage(filter: PurchaseHistoryFilter(year: 1901), cursor: nil)

        #expect(page.rows.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("a filter that matches nothing in combination yields an empty page")
    func emptyCombination() async throws {
        let repo = MockPurchaseHistoryRepository()

        let page = try await repo.loadPage(
            filter: PurchaseHistoryFilter(year: 1901, recipientId: "nobody-here", shippingStatus: .delivered), cursor: nil
        )

        #expect(page.rows.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("filtered paging gives a cursor only while rows remain")
    func filteredCursorEndsOnTheLastPage() async throws {
        let repo = MockPurchaseHistoryRepository(pageSize: 3)
        let filter = PurchaseHistoryFilter(shippingStatus: .shipped)
        let expected = matching(filter)

        let pages = try await allPages(repo, filter: filter)

        #expect(pages.count >= max(1, (expected.count + 2) / 3))
        #expect(pages.last?.nextCursor == nil)
    }
}
