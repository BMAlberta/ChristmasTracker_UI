//
//  ServiceInstrumentationRule.swift
//  ChristmasTrackerTests
//
//  LG1-L4, rule R3 logic (see ServiceInstrumentationScanTests for the rule and its tests): a service file that
//  calls a repository must have `@Instrumented`, `InstrumentedOperation.run`, or a hand span with a comment
//  that says why the macro is not used.
//

import Foundation

nonisolated enum ServiceInstrumentationRule {

    /// Relative paths allowed to call a repository without instrumentation. Each entry needs a written reason.
    /// Empty: every current service file that calls a repository is instrumented, so no exception is needed.
    static let knownExceptions: Set<String> = []

    /// True when `raw` calls a repository and has none of the accepted instrumentation forms.
    static func isMissingInstrumentation(_ raw: String) -> Bool {
        let code = ItemSourceScan.codeOnly(raw)
        guard ServiceSourceWalk.callsRepository(code) else { return false }
        if code.range(of: #"@Instrumented\b"#, options: .regularExpression) != nil { return false }
        if code.contains("InstrumentedOperation.run") { return false }
        let explained = raw.contains("@Instrumented cannot") || raw.contains("Actor-isolated")
        return !(code.contains("SentrySDK.startTransaction") && explained)
    }
}
