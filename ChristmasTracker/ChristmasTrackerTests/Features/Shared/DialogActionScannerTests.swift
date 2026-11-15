//
//  DialogActionScannerTests.swift
//  ChristmasTrackerTests
//
//  TH1.1 Story A2: fixtures for DialogActionScanner.
//

import Testing

@Suite("Dialog action scanner Tests")
struct DialogActionScannerTests {

    private func dialog(_ button: String) -> String {
        """
        struct V: View {
            var body: some View {
                Text("x")
                    .confirmationDialog("Sure?", isPresented: $show, titleVisibility: .visible) {
                        \(button)
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("Message")
                    }
            }
        }
        """
    }

    @Test("a dialog button titled Delete without a role fires")
    func deleteWithoutRoleFires() {
        let found = DialogActionScanner.missingDestructiveRole(in: dialog("Button(\"Delete\") { go() }"))
        #expect(found.count == 1)
        #expect(found.first?.line == 5)
    }

    @Test("a dialog button titled Delete with the destructive role does not fire")
    func deleteWithRoleDoesNotFire() {
        #expect(DialogActionScanner.missingDestructiveRole(in: dialog("Button(\"Delete\", role: .destructive) { go() }")).isEmpty)
    }

    @Test("an alert button titled Remove without a role fires")
    func alertRemoveWithoutRoleFires() {
        let source = """
        Text("x").alert("Remove?", isPresented: $show) {
            Button("Remove") { go() }
            Button("Cancel", role: .cancel) { }
        }
        """
        #expect(DialogActionScanner.missingDestructiveRole(in: source).count == 1)
    }

    @Test("Cancel does not fire, even with a keyword title")
    func cancelDoesNotFire() {
        let source = dialog("Button(\"Leave\", role: .cancel) { }")
        #expect(DialogActionScanner.missingDestructiveRole(in: source).isEmpty)
    }

    @Test("Continue Anyway does not fire")
    func continueAnywayDoesNotFire() {
        let source = dialog("Button(model.prompt?.confirmButtonTitle ?? \"Continue Anyway\") { go() }")
        #expect(DialogActionScanner.missingDestructiveRole(in: source).isEmpty)
    }

    @Test("a literal Sign Out without a role fires")
    func signOutFires() {
        #expect(DialogActionScanner.missingDestructiveRole(in: dialog("Button(\"Sign Out\") { go() }")).count == 1)
    }

    @Test("an identifier title carrying a keyword fires without a role and passes with one")
    func identifierTitles() {
        for title in ["ListArchiveConfirmation.confirmButtonTitle", "StatsScreenModel.deleteButtonTitle",
                      "CoOwnerRemoveConfirmation.confirmButtonTitle", "MembersSectionState.leaveConfirmation.confirmButtonTitle"] {
            #expect(DialogActionScanner.missingDestructiveRole(in: dialog("Button(\(title)) { go() }")).count == 1, "\(title)")
            #expect(DialogActionScanner.missingDestructiveRole(in: dialog("Button(\(title), role: .destructive) { go() }")).isEmpty, "\(title)")
        }
    }

    @Test("a keyword in a comment does not fire")
    func commentDoesNotFire() {
        let source = dialog("// Button(\"Delete\") { go() }\n        Button(\"Keep\") { go() }")
        #expect(DialogActionScanner.missingDestructiveRole(in: source).isEmpty)
    }

    @Test("a Delete button outside a dialog action closure does not fire")
    func outsideDialogDoesNotFire() {
        let source = """
        VStack { Button("Delete") { go() } }
        """
        #expect(DialogActionScanner.missingDestructiveRole(in: source).isEmpty)
    }

    @Test("examinedButtons counts compliant and non-compliant keyword buttons, not Cancel or other titles")
    func examinedCount() {
        let source = dialog("Button(\"Delete\", role: .destructive) { go() }\n        Button(\"Remove\") { go() }\n        Button(\"Keep\") { go() }")
        let examined = DialogActionScanner.examinedButtons(in: source)
        #expect(examined.count == 2)
        #expect(examined.filter(\.isDestructive).count == 1)
    }

    @Test("a real-looking Logout dialog with the role removed fires")
    func realLookingLogoutFires() {
        let source = """
        .confirmationDialog(
            "Logout",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Logout") {
                Task { await authService.logout() }
            }
            .destructiveTint()
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to logout?")
        }
        """
        #expect(DialogActionScanner.missingDestructiveRole(in: source).count == 1)
    }
}
