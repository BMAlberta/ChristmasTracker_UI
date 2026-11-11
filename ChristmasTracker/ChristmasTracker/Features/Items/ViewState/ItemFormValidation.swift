//
//  ItemFormValidation.swift
//  ChristmasTracker
//
//  Pure validation and request-building for the add and edit item forms. The limits come from
//  the generated schema: name 1 to 200, description 1 to 2000 (required by the server),
//  url and imageUrl absolute http or https URLs, quantity 1 to 999, priority 1 to 10, and a
//  price from 0 to 999999.99 with at most two decimals.
//

import Foundation

nonisolated enum ItemFormCopy {
    static let offListSentence = "This item will be hidden from the recipient."
}

nonisolated struct ItemFormValidity: Equatable, Sendable {
    let nameInvalid: Bool
    let descriptionInvalid: Bool
    let urlInvalid: Bool
    let imageUrlInvalid: Bool
    let priceInvalid: Bool
    let quantityInvalid: Bool
    let priorityInvalid: Bool

    var isValid: Bool {
        !(nameInvalid || descriptionInvalid || urlInvalid || imageUrlInvalid
            || priceInvalid || quantityInvalid || priorityInvalid)
    }
}

nonisolated enum ItemFormValidation {

    private static let maxPrice = Decimal(string: "999999.99", locale: Locale(identifier: "en_US_POSIX"))

    // MARK: - Validate

    static func validate(
        name: String,
        description: String,
        url: String,
        imageUrl: String,
        priceText: String,
        quantity: Int,
        priority: Int
    ) -> ItemFormValidity {
        let trimmedPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ItemFormValidity(
            nameInvalid: !lengthIsValid(name, max: 200),
            descriptionInvalid: !lengthIsValid(description, max: 2000),
            urlInvalid: !optionalURLIsValid(url),
            imageUrlInvalid: !optionalURLIsValid(imageUrl),
            priceInvalid: !trimmedPrice.isEmpty && parsePrice(trimmedPrice) == nil,
            quantityInvalid: !(1...999).contains(quantity),
            priorityInvalid: !(1...10).contains(priority)
        )
    }

    // MARK: - Price

    /// The price as a Decimal, or nil when the text is empty or invalid. Strict pattern: digits,
    /// optionally a dot and one or two digits; no sign, grouping, exponent or symbol.
    static func parsePrice(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        guard isAsciiDigits(parts[0]) else { return nil }
        if parts.count == 2 {
            guard isAsciiDigits(parts[1]), parts[1].count <= 2 else { return nil }
        }
        guard let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")),
              let maxPrice, value >= 0, value <= maxPrice else { return nil }
        return value
    }

    // MARK: - Build inputs

    static func makeCreateInput(
        name: String,
        description: String,
        url: String,
        imageUrl: String,
        priceText: String,
        quantity: Int,
        priority: Int
    ) -> CreateItemInput? {
        let validity = validate(name: name, description: description, url: url, imageUrl: imageUrl,
                                priceText: priceText, quantity: quantity, priority: priority)
        guard validity.isValid else { return nil }
        return CreateItemInput(
            name: trimmed(name),
            description: trimmed(description),
            url: nilIfEmpty(url),
            imageUrl: nilIfEmpty(imageUrl),
            expectedUnitPrice: parsePrice(priceText),
            quantityRequested: quantity,
            priority: priority
        )
    }

    /// Only the fields that differ from `original` are set. Clearing an optional field is not a
    /// change: the generated update body cannot clear a field.
    static func makeUpdateInput(
        original: ListItem,
        name: String,
        description: String,
        url: String,
        imageUrl: String,
        priceText: String,
        quantity: Int,
        priority: Int
    ) -> UpdateItemInput? {
        let validity = validate(name: name, description: description, url: url, imageUrl: imageUrl,
                                priceText: priceText, quantity: quantity, priority: priority)
        guard validity.isValid else { return nil }

        let newName = trimmed(name)
        let newDescription = trimmed(description)
        let newUrl = nilIfEmpty(url)
        let newImageUrl = nilIfEmpty(imageUrl)
        let newPrice = parsePrice(priceText)

        let input = UpdateItemInput(
            name: newName != trimmed(original.name) ? newName : nil,
            description: newDescription != trimmed(original.description) ? newDescription : nil,
            url: newUrl != nil && newUrl != original.url.flatMap(nilIfEmpty) ? newUrl : nil,
            imageUrl: newImageUrl != nil && newImageUrl != original.imageUrl.flatMap(nilIfEmpty) ? newImageUrl : nil,
            expectedUnitPrice: newPrice != nil && newPrice != original.expectedUnitPrice ? newPrice : nil,
            quantityRequested: quantity != original.quantityRequested ? quantity : nil,
            priority: priority != original.priority ? priority : nil
        )
        return input.isEmpty ? nil : input
    }

    // MARK: - Helpers

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nilIfEmpty(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    private static func lengthIsValid(_ text: String, max: Int) -> Bool {
        (1...max).contains(trimmed(text).count)
    }

    private static func isAsciiDigits(_ text: Substring) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func optionalURLIsValid(_ text: String) -> Bool {
        let value = trimmed(text)
        if value.isEmpty { return true }
        guard value.count <= 2048,
              !value.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else { return false }
        return true
    }
}
