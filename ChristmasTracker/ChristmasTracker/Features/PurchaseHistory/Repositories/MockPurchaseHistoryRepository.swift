//
//  MockPurchaseHistoryRepository.swift
//  ChristmasTracker
//
//  Deterministic in-memory purchase history for mock mode and previews: 30 rows, newest first, three
//  people, all four shipping statuses, spread over the current and the previous calendar year. It
//  honors the filter (the year is the calendar year of `purchasedAt`) and an opaque cursor it issued.
//  Intentionally uninstrumented (a mock).
//

import Foundation

nonisolated final class MockPurchaseHistoryRepository: PurchaseHistoryLoading, Sendable {

    private let pageSize: Int

    init(pageSize: Int = GeneratedClientPurchaseHistoryRepository.pageLimit) {
        self.pageSize = max(1, pageSize)
    }

    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage {
        let matching = Self.seedRows.filter { Self.matches($0, filter) }
        let start = try Self.offset(of: cursor)
        guard start < matching.count else {
            return PurchaseHistoryPage(rows: [], nextCursor: nil)
        }
        let end = min(start + pageSize, matching.count)
        return PurchaseHistoryPage(
            rows: Array(matching[start..<end]),
            nextCursor: end < matching.count ? Self.cursor(forOffset: end) : nil
        )
    }

    // MARK: - Cursor

    /// The cursor is opaque to callers: a base64 text of the offset into the filtered rows.
    private static func cursor(forOffset offset: Int) -> String {
        Data("offset-\(offset)".utf8).base64EncodedString()
    }

    private static func offset(of cursor: String?) throws -> Int {
        guard let cursor else { return 0 }
        guard let data = Data(base64Encoded: cursor),
              let text = String(data: data, encoding: .utf8),
              text.hasPrefix("offset-"),
              let offset = Int(text.dropFirst("offset-".count)),
              offset >= 0 else {
            throw PurchaseHistoryError.validation(message: "")
        }
        return offset
    }

    private static func matches(_ row: PurchaseHistoryRow, _ filter: PurchaseHistoryFilter) -> Bool {
        if let year = filter.year, Calendar.current.component(.year, from: row.purchasedAt) != year { return false }
        if let recipientId = filter.recipientId, row.recipientId != recipientId { return false }
        if let status = filter.shippingStatus, row.shippingStatus != status { return false }
        return true
    }

    // MARK: - Seed

    private static let people: [(id: String, name: String)] = [
        ("mock-person-1", "Alex Rivera"), ("mock-person-2", "Sam Okafor"),
        ("mock-person-3", "Jordan Lee")
    ]

    private static let items = [
        "Wool scarf", "Board game", "Lego set", "Coffee grinder", "Rain jacket", "Puzzle box",
        "Headphones", "Cookbook", "Garden gloves", "Desk lamp"
    ]

    /// The first 14 rows fall in the current calendar year, the rest in the previous one; each row
    /// is older than the one before it.
    static let seedRows: [PurchaseHistoryRow] = {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        let yearStart = calendar.date(from: DateComponents(year: thisYear, month: 1, day: 1, hour: 12)) ?? Date()
        let lastDecember = calendar.date(from: DateComponents(year: thisYear - 1, month: 12, day: 28, hour: 12)) ?? Date()
        let statuses = PurchaseShippingStatus.allCases
        return (0..<30).map { index in
            let person = people[index % people.count]
            let current = index < 14
            let date = current
                ? calendar.date(byAdding: .day, value: 14 - index, to: yearStart) ?? yearStart
                : calendar.date(byAdding: .day, value: -(index - 14) * 7, to: lastDecember) ?? lastDecember
            return PurchaseHistoryRow(
                id: "mock-purchase-\(index + 1)",
                itemId: "mock-item-\(index + 1)",
                itemName: items[index % items.count],
                listId: "mock-list-\(index % 3 + 1)",
                recipientId: person.id,
                recipientName: person.name,
                purchasedAt: date,
                quantity: index % 5 == 0 ? 2 : 1,
                totalCost: Decimal(1999 + index * 350) / 100,
                shippingStatus: statuses[index % statuses.count]
            )
        }
    }()
}
