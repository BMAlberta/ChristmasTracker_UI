//
//  DestructiveScannerTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B2: DestructiveScanner proven on synthetic sources (it fires on the bad forms and
//  stays quiet on the good ones) before it runs over the real files.
//

import Testing

@Suite("Destructive scanner Tests")
struct DestructiveScannerTests {

    private func missing(_ source: String) -> [Int] {
        DestructiveScanner.destructiveButtonsMissingToken(in: source).map(\.line)
    }

    private func swipeMissing(_ source: String) -> [Int] {
        DestructiveScanner.swipeDestructiveMissingTint(in: source).map(\.line)
    }

    // MARK: - Rule (a): the token is in the chain

    @Test("OLD: a destructive Button with no token anywhere is flagged")
    func noTokenFires() {
        let source = """
        struct S: View {
            var other: some View {
                Button(role: .destructive) {
                    go()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        """
        #expect(missing(source) == [3])
    }

    @Test("OLD: a destructive Button whose label has only a non-destructive foreground is flagged")
    func accentForegroundFires() {
        let source = """
        Button(role: .destructive, action: onRemove) {
            Image(systemName: "minus.circle")
                .foregroundStyle(Color.accentColor)
        }
        """
        #expect(missing(source) == [1])
    }

    @Test("a destructive Button with .tint(Color.destructiveColor) passes")
    func tintPasses() {
        let source = """
        Button(role: .destructive) {
            go()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .tint(Color.destructiveColor)
        .disabled(false)
        """
        #expect(missing(source).isEmpty)
    }

    @Test("a destructive Button with destructiveTint() passes")
    func destructiveTintPasses() {
        let source = """
        Button(role: .destructive) { go() } label: { Text("Delete") }
            .destructiveTint()
        """
        #expect(missing(source).isEmpty)
    }

    @Test("a Color.destructiveColor foreground inside the label counts as the token")
    func labelForegroundPasses() {
        let source = """
        Button(role: .destructive) {
            go()
        } label: {
            Label("Delete", systemImage: "trash")
                .foregroundStyle(Color.destructiveColor)
        }
        """
        #expect(missing(source).isEmpty)
    }

    @Test("a Color.destructiveColor background in the label counts as the token")
    func labelBackgroundPasses() {
        let source = """
        Button(role: .destructive, action: go) {
            Text("Archive")
                .background(Color.destructiveColor, in: .rect(cornerRadius: 8))
        }
        """
        #expect(missing(source).isEmpty)
    }

    @Test("OLD: a dialog button without the token is flagged, with it passes")
    func dialogButton() {
        let bad = """
        .confirmationDialog("Sure?", isPresented: $flag) {
            Button("Archive", role: .destructive) {
                go()
            }
            Button("Cancel", role: .cancel) { }
        }
        """
        let good = """
        .confirmationDialog("Sure?", isPresented: $flag) {
            Button("Archive", role: .destructive) {
                go()
            }
            .tint(Color.destructiveColor)
            Button("Cancel", role: .cancel) { }
        }
        """
        #expect(missing(bad) == [2])
        #expect(missing(good).isEmpty)
    }

    @Test("OLD: a context menu item without the token is flagged, with it passes")
    func contextMenuItem() {
        let bad = """
        Text("x")
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        """
        let good = """
        Text("x")
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Color.destructiveColor)
            }
        """
        #expect(missing(bad) == [3])
        #expect(missing(good).isEmpty)
    }

    @Test("a destructive item inside a Menu is checked like any other")
    func menuItem() {
        let bad = """
        Menu {
            Button("Copy") { }
            Button(role: .destructive) {
                go()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        """
        #expect(missing(bad) == [3])
    }

    @Test("non-destructive buttons are ignored, whatever their styling")
    func nonDestructiveIgnored() {
        let source = """
        Button("Save") { save() }
        Button("Cancel", role: .cancel) { }
        Button(action: go) { Text("Go") }
            .tint(.accentColor)
        Button { go() } label: { Text("Plain") }
        """
        #expect(missing(source).isEmpty)
    }

    @Test("a token on the next sibling button does not rescue a bare destructive button")
    func siblingTokenDoesNotLeak() {
        let source = """
        Button(role: .destructive) { first() } label: { Text("First") }
        Button(role: .destructive) { second() } label: { Text("Second") }
            .tint(Color.destructiveColor)
        """
        #expect(missing(source) == [1])
    }

    @Test("a token inside a dialog attached to a destructive trigger does not rescue the trigger")
    func dialogTokenDoesNotLeakToTrigger() {
        let source = """
        Button(role: .destructive) { ask() } label: { Text("Leave") }
            .tint(.accentColor)
            .confirmationDialog("Sure?", isPresented: $flag) {
                Button("Leave", role: .destructive) { go() }
                    .tint(Color.destructiveColor)
            }
        """
        #expect(missing(source) == [1])
    }

    @Test("multiple destructive buttons are each reported with their own line")
    func multipleButtons() {
        let source = """
        VStack {
            Button(role: .destructive) { a() } label: { Text("A") }
            Button(role: .destructive) { b() } label: { Text("B") }
                .tint(Color.destructiveColor)
            Button(role: .destructive) { c() } label: { Text("C") }
        }
        """
        #expect(missing(source) == [2, 5])
    }

    @Test("a comment that mentions the token or the role never fires or rescues")
    func commentsIgnored() {
        let source = """
        // Button(role: .destructive) { go() } label: { Text("Delete") }
        /* Button(role: .destructive) { go() } */
        Button(role: .destructive) { go() } label: { Text("Delete") }
            // .tint(Color.destructiveColor)
        """
        #expect(missing(source) == [3])
    }

    // MARK: - Rule (b): swipe actions carry an explicit tint

    @Test("OLD: a destructive swipe action with no tint is flagged")
    func swipeWithoutTintFires() {
        let source = """
        Text("row")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if canDelete {
                    Button(role: .destructive) {
                        archive()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
        """
        #expect(swipeMissing(source) == [4])
    }

    @Test("a label foreground alone is not an explicit tint on a swipe action")
    func swipeLabelForegroundIsNotATint() {
        let source = """
        Text("row")
            .swipeActions {
                Button(role: .destructive) {
                    archive()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                        .foregroundStyle(Color.destructiveColor)
                }
            }
        """
        #expect(swipeMissing(source) == [3])
        #expect(missing(source).isEmpty)
    }

    @Test("a destructive swipe action with .tint(Color.destructiveColor) passes")
    func swipeWithTintPasses() {
        let source = """
        Text("row")
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Color.destructiveColor)
                .disabled(false)
            }
        """
        #expect(swipeMissing(source).isEmpty)
    }

    @Test("a destructive swipe action with destructiveTint() passes")
    func swipeWithHelperPasses() {
        let source = """
        Text("row")
            .swipeActions {
                Button(role: .destructive, action: onDelete) { Text("Delete") }
                    .destructiveTint()
            }
        """
        #expect(swipeMissing(source).isEmpty)
    }

    @Test("a destructive Button outside any swipe action is not a swipe finding")
    func outsideSwipeIgnored() {
        let source = """
        Button(role: .destructive) { go() } label: { Text("Delete") }
        Text("row")
            .swipeActions {
                Button("Pin") { pin() }
            }
        """
        #expect(swipeMissing(source).isEmpty)
    }

    // MARK: - Raw red and the neutral Logout type

    private let redLogout = """
    struct Other: View {
        var body: some View { Text("x").foregroundStyle(.red) }
    }
    private struct LogoutButtonView: View {
        var body: some View {
            Button { isConfirming = true } label: {
                Text("Logout")
                    .background(.red, in: .rect(cornerRadius: 12))
            }
        }
    }
    """

    @Test("OLD: a raw .red background on the Logout trigger is flagged, and only inside that type")
    func rawRedOnLogoutFires() {
        let found = DestructiveScanner.forbiddenTokenViolations(
            inType: "LogoutButtonView", tokens: [".red", "Color.red", "destructiveColor", "destructiveTint"],
            source: redLogout)
        #expect(found?.map(\.line) == [8])
    }

    @Test("a Logout trigger using a neutral token passes")
    func neutralLogoutPasses() {
        let source = """
        private struct LogoutButtonView: View {
            var body: some View {
                Button { isConfirming = true } label: {
                    Text("Logout")
                        .foregroundStyle(Color.textPrimaryColor)
                        .background(Color.surfaceColor, in: .rect(cornerRadius: 12))
                }
            }
        }
        // .background(.red) in a comment is ignored
        """
        let found = DestructiveScanner.forbiddenTokenViolations(
            inType: "LogoutButtonView", tokens: [".red", "Color.red", "destructiveColor", "destructiveTint"],
            source: source)
        #expect(found?.isEmpty == true)
    }

    @Test("Color.red and destructive tokens on the Logout type are flagged; a missing type returns nil")
    func otherForbiddenTokens() {
        let source = """
        struct LogoutButtonView: View {
            var body: some View {
                Text("Logout").foregroundStyle(Color.red)
                Text("Logout").tint(Color.destructiveColor)
                Text("Logout").destructiveTint()
            }
        }
        """
        let tokens = [".red", "Color.red", "destructiveColor", "destructiveTint"]
        #expect(DestructiveScanner.forbiddenTokenViolations(inType: "LogoutButtonView", tokens: tokens, source: source)?.map(\.line) == [3, 4, 5])
        #expect(DestructiveScanner.forbiddenTokenViolations(inType: "Missing", tokens: tokens, source: source) == nil)
    }

    @Test("rawRedViolations flags .red, Color.red and .foregroundColor(.red), not member names like x.red or .redacted")
    func rawRedScan() {
        let source = """
        a.background(.red, in: .rect)
        b.foregroundColor(.red)
        c.foregroundStyle(Color.red)
        let ok = value.red
        d.redacted(reason: .placeholder)
        e.foregroundStyle(Color.destructiveColor)
        // f.background(.red)
        """
        #expect(DestructiveScanner.rawRedViolations(in: source).map(\.line) == [1, 2, 3])
    }

    @Test("a tint on a dialog button after the swipe closure does not count for the swipe action")
    func swipeTintMustBeInsideTheClosure() {
        let source = """
        Text("row")
            .swipeActions {
                Button(role: .destructive, action: ask) { Text("Archive") }
            }
            .confirmationDialog("Sure?", isPresented: $flag) {
                Button("Archive", role: .destructive) { go() }
                    .tint(Color.destructiveColor)
            }
        """
        #expect(swipeMissing(source) == [3])
    }
}
