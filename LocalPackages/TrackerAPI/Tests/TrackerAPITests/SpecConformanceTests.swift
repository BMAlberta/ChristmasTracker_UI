// SpecConformanceTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Verifies that the derived spec file produced by scripts/make-client-spec.sh
// is a faithful transformation of contract/openapi.json and that exactly 5
// schema-level transformations are applied.

import Testing
import Foundation
import TrackerAPI

@Suite("SpecConformance")
struct SpecConformanceTests {

    // MARK: - Repo root helpers

    /// Navigate from this source file up to the repository root.
    private func repoRoot() -> URL {
        let testFilePath = URL(fileURLWithPath: #filePath)
        return testFilePath
            .deletingLastPathComponent() // TrackerAPITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // TrackerAPI
            .deletingLastPathComponent() // LocalPackages
            .deletingLastPathComponent() // repo root
    }

    // MARK: - Transform helpers

    /// Describes a single transformation that was applied to a JSON object.
    private struct TransformRecord {
        let path: String
        let key: String
        let kind: TransformKind
    }

    private enum TransformKind {
        /// anyOf[X, {type:null}] or anyOf[{type:null}, X] → replaced with X; key removed from required
        case anyOfNullable
        /// {type:null} standalone → property key removed entirely; key removed from required
        case pureNullRemoved
    }

    /// Recursively walk `json` (post-order: deepest first) applying the two transformations.
    /// Returns the transformed object and the total count of transformations applied.
    private func applyTransforms(_ json: Any, path: String = "") -> (Any, Int) {
        switch json {
        case var dict as [String: Any]:
            // First, recursively transform all values (post-order)
            var totalCount = 0
            for (key, value) in dict {
                let (transformed, count) = applyTransforms(value, path: "\(path)/\(key)")
                dict[key] = transformed
                totalCount += count
            }

            // Now apply property-level transforms
            if var properties = dict["properties"] as? [String: Any] {
                var keysToRemoveFromRequired: [String] = []
                var transformCount = 0

                for (propKey, propValue) in properties {
                    guard let propObj = propValue as? [String: Any] else { continue }

                    if let result = transformAnyOfNullable(propObj) {
                        // anyOf[X, null] or anyOf[null, X] → replace with X
                        properties[propKey] = result
                        keysToRemoveFromRequired.append(propKey)
                        transformCount += 1
                    } else if isPureNull(propObj) {
                        // {type: "null"} with no other meaningful keys → remove property
                        properties.removeValue(forKey: propKey)
                        keysToRemoveFromRequired.append(propKey)
                        transformCount += 1
                    }
                }

                if transformCount > 0 {
                    dict["properties"] = properties

                    // Remove transformed keys from the required array
                    if var required = dict["required"] as? [String] {
                        required.removeAll { keysToRemoveFromRequired.contains($0) }
                        dict["required"] = required
                    }

                    totalCount += transformCount
                }
            }

            return (dict, totalCount)

        case let array as [Any]:
            var totalCount = 0
            let transformed = array.map { element -> Any in
                let (t, c) = applyTransforms(element, path: path)
                totalCount += c
                return t
            }
            return (transformed, totalCount)

        default:
            return (json, 0)
        }
    }

    /// If `obj` is `{"anyOf": [X, {"type":"null"}]}` or `{"anyOf": [{"type":"null"}, X]}`,
    /// returns X (the non-null schema). Otherwise returns nil.
    private func transformAnyOfNullable(_ obj: [String: Any]) -> Any? {
        guard obj.count <= 2,
              let anyOf = obj["anyOf"] as? [Any],
              anyOf.count == 2 else { return nil }

        let a = anyOf[0]
        let b = anyOf[1]

        if isPureNull(b), let aObj = a as? [String: Any], !isPureNull(aObj) {
            // anyOf: [X, null] — description may be present in outer obj
            return aObj
        }
        if isPureNull(a), let bObj = b as? [String: Any], !isPureNull(bObj) {
            // anyOf: [null, X]
            return bObj
        }
        return nil
    }

    /// Returns true if `obj` is exactly `{"type": "null"}` (no other keys).
    private func isPureNull(_ value: Any) -> Bool {
        guard let obj = value as? [String: Any] else { return false }
        return obj.count == 1 && (obj["type"] as? String) == "null"
    }

    /// Serialise `json` to Data using `.sortedKeys` for a deterministic comparison.
    private func sortedJSON(_ json: Any) throws -> Data {
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    // MARK: - Test 1: derivedSpecMatchesTransformedContract

    @Test("Derived spec file matches the Swift-transform applied to contract/openapi.json")
    func derivedSpecMatchesTransformedContract() async throws {
        let root = repoRoot()

        let contractURL = root.appendingPathComponent("contract/openapi.json")
        let derivedURL = root.appendingPathComponent(
            "LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json"
        )

        let contractData = try #require(
            try? Data(contentsOf: contractURL),
            "contract/openapi.json must exist at \(contractURL.path)"
        )
        let derivedData = try #require(
            try? Data(contentsOf: derivedURL),
            "LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json must exist — run scripts/make-client-spec.sh first"
        )

        let contractJSON = try #require(
            try? JSONSerialization.jsonObject(with: contractData),
            "contract/openapi.json must be valid JSON"
        )
        let derivedJSON = try #require(
            try? JSONSerialization.jsonObject(with: derivedData),
            "LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json must be valid JSON"
        )

        let (transformedContract, transformCount) = applyTransforms(contractJSON)

        // The transform must touch exactly 5 properties
        #expect(transformCount == 5, "Expected 5 transformations; got \(transformCount)")

        let transformedContractData = try sortedJSON(transformedContract)
        let derivedSortedData = try sortedJSON(derivedJSON)

        #expect(
            transformedContractData == derivedSortedData,
            "Derived spec does not match the Swift-transformed contract. Run scripts/make-client-spec.sh to regenerate."
        )
    }

    // MARK: - Test 2: transformedPropertyCountIs5

    @Test("Applying the nullable transform to contract/openapi.json produces exactly 5 changes")
    func transformedPropertyCountIs5() async throws {
        let root = repoRoot()
        let contractURL = root.appendingPathComponent("contract/openapi.json")

        let contractData = try #require(
            try? Data(contentsOf: contractURL),
            "contract/openapi.json must exist at \(contractURL.path)"
        )
        let contractJSON = try #require(
            try? JSONSerialization.jsonObject(with: contractData),
            "contract/openapi.json must be valid JSON"
        )

        let (_, transformCount) = applyTransforms(contractJSON)

        #expect(transformCount == 5, "Expected exactly 5 anyOf-null / pure-null transformations; got \(transformCount)")
    }

    // MARK: - Test 3: publicOperationIDsMatchSpec

    @Test("publicOperationIDs matches operations in derived spec with no security requirement")
    func publicOperationIDsMatchSpec() async throws {
        let root = repoRoot()
        let derivedURL = root.appendingPathComponent(
            "LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json"
        )
        let data = try #require(
            try? Data(contentsOf: derivedURL),
            "openapi.json must exist"
        )
        let spec = try #require(
            try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            "openapi.json must be valid JSON object"
        )

        // Find all operationIds where the operation has no security requirement
        // (either missing security key or security is an empty array)
        var specPublicOps: Set<String> = []
        if let paths = spec["paths"] as? [String: Any] {
            for (_, pathItem) in paths {
                guard let pathObj = pathItem as? [String: Any] else { continue }
                for method in ["get", "post", "put", "patch", "delete", "head"] {
                    guard let operation = pathObj[method] as? [String: Any] else { continue }
                    guard let operationId = operation["operationId"] as? String else { continue }
                    // "public" = no security requirement OR security is an empty array
                    let security = operation["security"] as? [[String: Any]]
                    if security == nil || security!.isEmpty {
                        specPublicOps.insert(operationId)
                    }
                }
            }
        }

        #expect(!specPublicOps.isEmpty, "Expected to find at least one public operation in spec")

        // publicOperationIDs is defined in PublicOperations.swift (implementer creates it)
        // This line causes a compile error until PublicOperations.swift is created:
        #expect(
            publicOperationIDs == specPublicOps,
            "publicOperationIDs does not match spec. Spec has: \(specPublicOps.sorted()), constant has: \(publicOperationIDs.sorted())"
        )

        // Also verify the expected four operations are there
        for op in ["checkAppVersion", "register", "login", "refreshToken"] {
            #expect(specPublicOps.contains(op), "Expected \(op) to be a public operation in spec")
        }
    }
}
