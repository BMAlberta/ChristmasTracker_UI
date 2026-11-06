# I1a-11 — Generated Surface Report

**Date:** 2026-11-05  
**Story:** H3 — Document the generated API client surface for I1-b integration  
**Source:** `LocalPackages/TrackerAPI/.build/plugins/outputs/trackerapi/TrackerAPI/destination/OpenAPIGenerator/GeneratedSources/`

Swift signatures are verbatim from the generated files. `Components.Schemas.Money` is a type alias for `Swift.Double` in the generated code; use `doubleToDecimal(_:)` at the repository boundary.

---

## Operations (12 representative)

All operations are on `Client` and have the signature `func <name>(_ input: Operations.<Name>.Input) async throws -> Operations.<Name>.Output`.

### Public (no bearer token)

| # | Operation | HTTP | Path |
|---|-----------|------|------|
| 1 | `checkAppVersion` | GET | `/tracker/v2/app/version-check` |
| 2 | `register` | POST | `/tracker/v2/auth/register` |
| 3 | `login` | POST | `/tracker/v2/auth/login` |
| 4 | `refreshToken` | POST | `/tracker/v2/auth/refresh` |

### Authenticated

| # | Operation | HTTP | Path |
|---|-----------|------|------|
| 5 | `getCurrentUser` | GET | `/tracker/v2/auth/me` |
| 6 | `logout` | POST | `/tracker/v2/auth/logout` |
| 7 | `listLists` | GET | `/tracker/v2/lists` |
| 8 | `createList` | POST | `/tracker/v2/lists` |
| 9 | `listItems` | GET | `/tracker/v2/lists/{listId}/items` |
| 10 | `createItem` | POST | `/tracker/v2/lists/{listId}/items` |
| 11 | `createPurchase` | POST | `/tracker/v2/lists/{listId}/items/{itemId}/purchases` |
| 12 | `getStats` | GET | `/tracker/v2/stats` |

### Full method signatures (selected)

```swift
// Public
public func checkAppVersion(_ input: Operations.CheckAppVersion.Input) async throws -> Operations.CheckAppVersion.Output
public func login(_ input: Operations.Login.Input) async throws -> Operations.Login.Output
public func refreshToken(_ input: Operations.RefreshToken.Input) async throws -> Operations.RefreshToken.Output

// Authenticated
public func getCurrentUser(_ input: Operations.GetCurrentUser.Input) async throws -> Operations.GetCurrentUser.Output
public func listLists(_ input: Operations.ListLists.Input) async throws -> Operations.ListLists.Output
public func createItem(_ input: Operations.CreateItem.Input) async throws -> Operations.CreateItem.Output
public func createPurchase(_ input: Operations.CreatePurchase.Input) async throws -> Operations.CreatePurchase.Output
```

Convenience wrappers (no-argument) are available for operations with no required input fields:
```swift
public func getCurrentUser() async throws -> Operations.GetCurrentUser.Output
public func listLists() async throws -> Operations.ListLists.Output
public func checkAppVersion(query: Operations.CheckAppVersion.Input.Query) async throws -> Operations.CheckAppVersion.Output
```

---

## Types (9 key schemas)

### 1. `Components.Schemas.Meta`

```swift
public struct Meta: Codable, Hashable, Sendable {
    public var timestamp: Foundation.Date
    public var requestId: Swift.String
    public var sessionId: Swift.String
}
```

### 2. `Components.Schemas.PersonRef`

```swift
public struct PersonRef: Codable, Hashable, Sendable {
    public var id: Swift.String
    public var displayName: Swift.String
}
```

### 3. `Components.Schemas.VersionOutdatedDetails`

```swift
public struct VersionOutdatedDetails: Codable, Hashable, Sendable {
    public var minimumVersion: Swift.String
    public var minimumBuild: Swift.Int?
    public var latestVersion: Swift.String?
    public var latestBuild: Swift.Int?
    public var manifestUrl: Swift.String?
    public var ipaUrl: Swift.String?
}
```

### 4. `Components.Schemas.CapabilityFlags`

The six capability flags drive ALL UI visibility decisions. Never use role.

```swift
public struct CapabilityFlags: Codable, Hashable, Sendable {
    public var isRecipient: Swift.Bool
    public var canSeeGiftActivity: Swift.Bool
    public var canPurchase: Swift.Bool
    public var canAddOffList: Swift.Bool
    public var canSeeOffList: Swift.Bool
    public var canCreateItem: Swift.Bool
}
```

### 5. `Components.Schemas.ListSummary` (allOf — access via `.value1`)

Generated as an allOf wrapper; payload fields live on `.value1`:

```swift
public struct ListSummary: Codable, Hashable, Sendable {
    public struct Value1Payload: Codable, Hashable, Sendable {
        public var id: Swift.String
        public var name: Swift.String
        public var theme: Swift.String?
        public var year: Swift.Int
        public var visibility: Components.Schemas.ListVisibility
        public var status: Components.Schemas.ListStatus
        public var recipient: Components.Schemas.PersonRef
        public var owner: Components.Schemas.PersonRef
        public var coOwner: Components.Schemas.PersonRef?   // nullable — derived spec fix
        public var myRole: Components.Schemas.ListRole
        public var itemCount: Swift.Int?                     // omitted for blind viewers
        public var purchasedCount: Swift.Int?                // omitted for blind viewers / Viewers
        public var memberCount: Swift.Int
        public var createdAt: Foundation.Date
        public var updatedAt: Foundation.Date
    }
    public var value1: Value1Payload
    // capabilities come from the list-detail or list-response wrapper
}
```

Access: `listSummary.value1.name`, `listSummary.value1.coOwner`.

### 6. `Components.Schemas.Item`

```swift
public struct Item: Codable, Hashable, Sendable {
    public var id: Swift.String
    public var listId: Swift.String
    public var name: Swift.String
    public var description: Swift.String
    public var url: Swift.String?
    public var imageUrl: Swift.String?
    public var expectedUnitPrice: Components.Schemas.Money?  // Double? — use doubleToDecimal
    public var quantityRequested: Swift.Int
    public var priority: Swift.Int
    public var status: Components.Schemas.ItemStatus
    public var offList: Swift.Bool
    public var createdBy: Components.Schemas.PersonRef
    public var createdAt: Foundation.Date
    public var updatedAt: Foundation.Date?                   // omitted when canSeeGiftActivity false
}
```

### 7. `Components.Schemas.Purchase`

```swift
public struct Purchase: Codable, Hashable, Sendable {
    public var id: Swift.String
    public var itemId: Swift.String
    public var quantity: Swift.Int
    public var totalCost: Components.Schemas.Money           // Double — use doubleToDecimal
    public var storeName: Swift.String?
    public var notes: Swift.String?
    public var confirmationNumber: Swift.String?
    public var trackingNumber: Swift.String?
    public var shippingStatus: Components.Schemas.ShippingStatus
    public var shippedAt: Foundation.Date?
    // ... additional fields (purchasedBy, createdAt, updatedAt)
}
```

### 8. `Components.Schemas.Budget`

```swift
public struct Budget: Codable, Hashable, Sendable {
    public var id: Swift.String
    public var year: Swift.Int
    public var totalBudget: Components.Schemas.Money
    public var totalSpent: Components.Schemas.Money
    public var remaining: Components.Schemas.Money
    public var isOverBudget: Swift.Bool
    public var recipients: [RecipientsPayloadPayload]        // per-recipient breakdown
    public var createdAt: Foundation.Date
    public var updatedAt: Foundation.Date
    // RecipientsPayloadPayload: id, recipientId, recipientName, maxSpend, spent, remaining, isOverBudget, overage
}
```

### 9. `Components.Schemas.BudgetStats`

```swift
public struct BudgetStats: Codable, Hashable, Sendable {
    public var totalBudget: Components.Schemas.Money
    public var totalSpent: Components.Schemas.Money
    public var remaining: Components.Schemas.Money
    public var recipients: [Components.Schemas.BudgetRecipientStat]
}
```

---

## Nullable fields added by derived spec (I1-b mapping note)

These fields were absent without the derived spec; they are now optional Swift properties:

| Field | Generated type | I1-b mapping |
|-------|---------------|--------------|
| `ListSummary.value1.coOwner` | `Components.Schemas.PersonRef?` | nil → no co-owner |
| `Item.expectedUnitPrice` | `Components.Schemas.Money?` | nil → price unknown |
| `YearStats.totalBudget` | `Components.Schemas.Money?` | nil → no budget set |
| `StatsYearResponse.value1.budget` | `Components.Schemas.BudgetStats?` | nil → no budget |
| `PurchaseConfirmationRequiredData.purchase` | (field absent from schema) | ignore |

---

## Money conversion

`Components.Schemas.Money` = `Swift.Double`. At the repository boundary:
- Server → domain: `doubleToDecimal(_: Double) -> Decimal?` (nil for NaN/Infinity)
- Domain → server: `decimalToDouble(_: Decimal) -> Double`
