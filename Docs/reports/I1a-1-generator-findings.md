# I1-a Story 1 — Generator Findings

**Package:** I1-a — TrackerAPI Swift Package  
**Story:** A1 — Create the LocalPackages/TrackerAPI package, run the generator, capture findings  
**Date:** 2026-11-05

---

## 1. Pinned Dependency Versions

| Package | Version | Published |
|---|---|---|
| swift-openapi-generator | 1.14.2 | 2026-10-19 |
| swift-openapi-runtime | 1.13.3 | 2026-10-20 |
| swift-openapi-urlsession | 1.4.0 | 2026-10-22 |

Transitive dependencies resolved by SPM:
- swift-http-types 1.8.0
- swift-collections 1.7.5
- swift-algorithms 1.2.1
- swift-argument-parser 1.8.2
- swift-numerics 1.1.1
- OpenAPIKit 6.4.0
- Yams 6.2.2

---

## 2. Spec File — Symlink vs Copy

A symlink was used:

```
LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.yaml -> ../../../../contract/openapi.json
```

The generator resolved the symlink without error.

---

## 3. First Build Duration

44.68 seconds (including dependency resolution, compilation of all transitive packages, and code generation).

---

## 4. Generator Diagnostics

### Warnings (all expected, no errors)

```
warning: Feature "Cookie params" is not supported, skipping
  [context: foundIn=Operations.RefreshToken.Input.Cookies
  (#/paths/tracker/v2/auth/refresh/POST/cookie)/refreshToken]

warning: Schema "null" is not supported, reason: "schema type", skipping
  [context: foundIn=Components.Schemas.ListSummary.Value1Payload
  (#/components/schemas/ListSummary/value1)/coOwner]

warning: Schema "null" is not supported, reason: "schema type", skipping
  [context: foundIn=Components.Schemas.Item
  (#/components/schemas/Item)/expectedUnitPrice]

warning: Schema "null" is not supported, reason: "schema type", skipping
  [context: foundIn=Components.Schemas.PurchaseConfirmationRequiredData
  (#/components/schemas/PurchaseConfirmationRequiredData)/purchase]

warning: Schema "null" is not supported, reason: "schema type", skipping
  [context: foundIn=Components.Schemas.YearStats
  (#/components/schemas/YearStats)/totalBudget]

warning: Schema "null" is not supported, reason: "schema type", skipping
  [context: foundIn=Components.Schemas.StatsYearResponse
  (#/components/schemas/StatsYearResponse)/budget]
```

The null-schema warnings are due to `anyOf: [{ $ref }, { type: null }]` patterns. The generator 1.14.2 drops these fields entirely rather than generating an optional type. The fields that were dropped:

| Schema | Field | Schema pattern | Impact |
|---|---|---|---|
| `ListSummary.Value1Payload` | `coOwner` | anyOf[PersonRef, null] | Field absent; JSON is decoded but coOwner ignored |
| `Item` | `expectedUnitPrice` | anyOf[Money, null] | Field absent; JSON is decoded but price ignored |
| `PurchaseConfirmationRequiredData` | `purchase` | anyOf[Purchase, null] | Field absent |
| `YearStats` | `totalBudget` | anyOf[Money, null] | Field absent |
| `StatsYearResponse` | `budget` | anyOf[Money, null] | Field absent |

The refreshToken cookie-param warning is expected; refresh uses a cookie-based refresh token that the generator cannot model.

---

## 5. Generated Swift Names — Key Types

### Operations (in `Operations` namespace)

| OpenAPI operationId | Generated Swift enum |
|---|---|
| `CheckAppVersion` | `Operations.CheckAppVersion` |
| `Login` | `Operations.Login` |
| `RefreshToken` | `Operations.RefreshToken` |
| `ListLists` | `Operations.ListLists` |
| `GetList` | `Operations.GetList` |
| `GetCurrentUser` | `Operations.GetCurrentUser` |
| `GetMe` | `Operations.GetMe` |
| `GetUser` | `Operations.GetUser` |

Each operation has `.Input` and `.Output` nested types, following the standard OpenAPI generator pattern.

### Component schemas (in `Components.Schemas`)

| OpenAPI schema | Generated Swift type | Notes |
|---|---|---|
| `Error` | `Components.Schemas._Error` | Renamed; `Error` shadows `Swift.Error` |
| `ListSummary` | `Components.Schemas.ListSummary` | allOf → `value1: Value1Payload`, `value2: CapabilityFlags` |
| `ListDetail` | `Components.Schemas.ListDetail` | allOf → `value1: ListSummary`, `value2: Value2Payload` |
| `Item` | `Components.Schemas.Item` | `expectedUnitPrice` DROPPED (anyOf null) |
| `User` | `Components.Schemas.User` | Standard flat struct |
| `VersionOutdatedDetails` | `Components.Schemas.VersionOutdatedDetails` | Standard flat struct |
| `MemberSummary` | `Components.Schemas.MemberSummary` | Standard flat struct |
| `CapabilityFlags` | `Components.Schemas.CapabilityFlags` | Flat struct with 6 bool fields |

### ListSummary allOf structure

The `ListSummary` schema is `allOf[inlineObject, $ref(CapabilityFlags)]`. The generator produces:

```swift
public struct ListSummary: Codable, Hashable, Sendable {
    public var value1: Value1Payload       // inline object: id, name, theme, year, visibility,
                                           // status, recipient, owner, myRole, memberCount,
                                           // createdAt, updatedAt — coOwner DROPPED
    public var value2: CapabilityFlags     // isRecipient, canSeeGiftActivity, canPurchase,
                                           // canAddOffList, canSeeOffList, canCreateItem
}
```

Decoding uses a flat decoder; both `value1` and `value2` are initialized from the same flat JSON object.

### ListDetail allOf structure

```swift
public struct ListDetail: Codable, Hashable, Sendable {
    public var value1: Components.Schemas.ListSummary   // full summary (itself allOf)
    public var value2: Value2Payload                     // { members: [MemberSummary]? }
}
```

### coOwner — anyOf-null

The `coOwner` field on `ListSummary.Value1Payload` was **dropped** by the generator with:
```
warning: Schema "null" is not supported, reason: "schema type", skipping
```
JSON containing `"coOwner": null` or `"coOwner": {...}` decodes without error (field is silently ignored). The field is not accessible in Swift.

### Money fields

`Money` schema (`type: number, multipleOf: 0.01`) generates as `Swift.Double` (not `Decimal`). The `totalCost` field on `Purchase` is `Swift.Double`. The `expectedUnitPrice` field on `Item` was dropped entirely.

**Important for I1-b mapping layer:** The repository boundary must convert `Swift.Double` → `Decimal` when mapping to domain models.

### UUID fields

UUID fields (`format: uuid`) generate as `Swift.String`. The repository mapping layer must convert to `Foundation.UUID` where domain models use `UUID`.

### ListRole enum

```swift
@frozen public enum ListRole: String, Codable, Hashable, Sendable, CaseIterable {
    case owner = "owner"
    case coOwner = "co-owner"      // idiomatic: co-owner → coOwner
    case member = "member"
    case viewer = "viewer"
}
```

### Dates

Date fields (`format: date-time`) generate as `Foundation.Date`. The generated `Client.swift` uses `ISO8601DateTranscoder` by default; the custom `TrackerDateTranscoder` is used in tests (and should be injected at the client configuration level in I1-b).

### 426/429 response appearances

426 and 429 are **documented** in the spec and appear as named cases:
- `case upgradeRequired(Components.Responses.UpgradeRequiredError)` — not `.undocumented`
- `case tooManyRequests(Components.Responses.RateLimitError)` — not `.undocumented`

The `.undocumented(statusCode:, payload:)` case is still present for any other unexpected status codes.

---

## 6. Recommendations for I1-b Mapping Layer

### allOf accessor pattern
Access `ListSummary` base fields via `.value1` and capability flags via `.value2`. Access `ListDetail` members via `.value2.members`. Do not flat-map these at the generated type level; map at the repository boundary.

### anyOf-null dropped fields
The generator drops `coOwner`, `expectedUnitPrice`, `purchase`, `totalBudget`, and `budget` because the null schema variant is unsupported. The mapping layer must treat these as `nil` always. Consider filing a contract issue or waiting for generator support; for now, domain model fields should be `nil`-defaulted.

**Filed as contract issue:** These fields are correctly specified in the contract (`anyOf[ref, null]`); the limitation is the generator. No backend change needed. Document in the mapping layer with `// GENERATOR-LIMITATION: anyOf[null] dropped`.

### Money → Decimal conversion
The generator produces `Swift.Double` for `Money` and `MoneyAmount`. Map to `Decimal` at the repository boundary using `Decimal(string: String(value))` or similar to avoid floating-point imprecision.

### UUID → Foundation.UUID
Map `Swift.String` UUID fields to `Foundation.UUID` at the repository boundary, using `UUID(uuidString:)`.

### Date transcoder
Inject `TrackerDateTranscoder` into the `OpenAPIClientConfiguration` date transcoder when constructing the generated `Client` in I1-b:
```swift
let configuration = OpenAPIClientConfiguration(dateTranscoder: TrackerDateTranscoder())
```

### _Error type
The error envelope schema is `Components.Schemas._Error`. Access fields: `.error.code`, `.error.errorCode`, `.error.message`.
