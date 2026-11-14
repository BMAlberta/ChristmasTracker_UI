//
//  LoginFaceIDHintScanTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B4: OLD behavior: LoginView rendered no Face ID hint at all. LoginView.swift must
//  render the hint only through LoginFaceIDHintState, just below the Sign In section, keep the
//  error alert, and use design tokens. Needs the checkout on disk (scripts/test.sh has it).
//

import Foundation
import Testing

@Suite("Login Face ID hint scan Tests")
struct LoginFaceIDHintScanTests {

    private let path = "Features/Authentication/Views/LoginView.swift"

    private func loginCode(file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source(path), "LoginView.swift is missing")
        return ItemSourceScan.codeOnly(raw)
    }

    private func contentViewBody(_ code: String) throws -> String {
        try #require(ItemSourceScan.braceBody(after: "private var contentView", in: code), "contentView not found")
    }

    @Test("no literal hint sentence in the view; the text comes from the presenter")
    func noLiteralSentence() throws {
        #expect(!(try loginCode()).contains("You can also sign in"))
    }

    @Test("LoginView holds LoginFaceIDHintState in a hint property and reads hint.text")
    func usesStateAndText() throws {
        let code = try loginCode()
        #expect(code.contains("LoginFaceIDHintState"))
        #expect(code.contains("hint.text"))
    }

    @Test("the Error alert is unchanged")
    func errorAlertRemains() throws {
        let code = try loginCode()
        #expect(code.contains(".alert(\"Error\""))
        #expect(code.contains("isPresented: $showError"))
    }

    @Test("the hint text sits after the LoginActionSection use in contentView")
    func hintAfterActionSection() throws {
        let body = try contentViewBody(try loginCode())
        let action = try #require(body.range(of: "LoginActionSection("), "LoginActionSection not in contentView")
        let hint = try #require(body.range(of: "hint.text"), "hint.text not in contentView")
        #expect(action.lowerBound < hint.lowerBound)
    }

    @Test("the hint lines use tokens, not raw colors or system fonts")
    func hintUsesTokens() throws {
        let body = try contentViewBody(try loginCode())
        let hintStart = try #require(body.range(of: "hint.text"), "hint.text not in contentView")
        let lines = body[hintStart.lowerBound...].components(separatedBy: "\n").prefix(6).joined(separator: "\n")
        for forbidden in ["Color(", ".red", "#", ".font(.system"] {
            #expect(!lines.contains(forbidden), "hint lines contain \(forbidden)")
        }
    }
}
