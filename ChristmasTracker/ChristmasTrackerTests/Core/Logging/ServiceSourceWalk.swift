//
//  ServiceSourceWalk.swift
//  ChristmasTrackerTests
//
//  LG1-L4: shared support for the three service logging scans. The service files are found by WALKING the app
//  source folder (from `#filePath`, through `ItemSourceTree`), never from a hardcoded list, so a new service
//  file is covered the day it is added.
//
//  "Calls a repository" is one detection used by every rule (comments are stripped first):
//    - a `try await` followed on the same line by a name that ends in `repository` / `Repository`
//      (`try await repository.fetch()`, `try await perform { try await itemRepository.x() }`,
//      `try await work(repository)`), or the same with the name on the next line; or
//    - a `client.<member>` use (the generated client).
//

import Foundation

nonisolated enum ServiceSourceWalk {

    struct File {
        let path: String
        let raw: String
        let code: String
    }

    private static let serviceFileShape = #"^(?:Features/[^/]+/Services/|Core/API/)[^/]*Service\.swift$"#
    private static let serviceFolderShape = #"^Features/[^/]+/Services/[^/]+\.swift$"#
    private static let repositoryCallShape =
        #"\btry await\b[^\n]*\b\w*[rR]epository\b|\btry await\s*\n\s*\w*[rR]epository\b|\bclient\.\w"#
    private static let logCallShape = #"\blog\.(?:started|processed|cancelled|failed|skipped)\(|"#
        + #"\bLog(?:Debug|Info|Warning|Error|Critical)\("#

    /// Every `*Service.swift` under `Features/<feature>/Services/` and `Core/API/`.
    static func serviceFiles(in tree: ItemSourceTree) -> [File] {
        files(in: tree, matching: serviceFileShape)
    }

    /// Every `.swift` file directly under `Features/<feature>/Services/`.
    static func featureServiceFolderFiles(in tree: ItemSourceTree) -> [File] {
        files(in: tree, matching: serviceFolderShape)
    }

    private static func files(in tree: ItemSourceTree, matching shape: String) -> [File] {
        tree.all.compactMap { url in
            let path = tree.relativePath(url)
            guard path.range(of: shape, options: .regularExpression) != nil,
                  let raw = tree.source(path) else { return nil }
            return File(path: path, raw: raw, code: ItemSourceScan.codeOnly(raw))
        }
    }

    /// True when `code` (comments already stripped) calls a repository or the generated client.
    static func callsRepository(_ code: String) -> Bool {
        code.range(of: repositoryCallShape, options: .regularExpression) != nil
    }

    /// True when `code` (comments already stripped) has a `log.<step>(` or a `Log*(` call.
    static func writesLogLine(_ code: String) -> Bool {
        code.range(of: logCallShape, options: .regularExpression) != nil
    }
}
