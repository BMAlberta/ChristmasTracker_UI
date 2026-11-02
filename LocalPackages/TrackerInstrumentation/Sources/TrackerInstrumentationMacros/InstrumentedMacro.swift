// InstrumentedMacro.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin


public struct InstrumentedMacro: BodyMacro {
    public static func expansion(of node: AttributeSyntax,
                                 providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
                                 in context: some MacroExpansionContext) throws -> [CodeBlockItemSyntax] {

        guard let body = declaration.body else {
            throw MacroExpansionErrorMessage("@Instrumented requires a function body")
        }

        let originalStatements = body.statements

        let effects = (declaration as? FunctionDeclSyntax)?.signature.effectSpecifiers
        let isAsync = effects?.asyncSpecifier != nil
        let isThrowing = effects?.throwsClause != nil

        let statements: [CodeBlockItemSyntax] = [
                """
                #if DEBUG || QA
                let __log = OSLog(subsystem: "com.bmalberta.com.ChristmasTracker", category: "instrumentation")
                os_signpost(.begin, log: __log, name: #function)
                #endif
                """,
                """
                let __sentryTransaction = SentrySDK.startTransaction(name: #function as String, operation: #function as String)
                """,
                """
                defer {
                    #if DEBUG || QA
                    os_signpost(.end, log: __log, name: #function)
                    #endif
                    __sentryTransaction.finish()
                }
                """,
        ]
        + originalStatements.map { $0 }

        return statements
    }
}

@main
struct TrackerInstrumentationPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        InstrumentedMacro.self,
    ]
}
