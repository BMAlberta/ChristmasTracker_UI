//
//  DialogScannerTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B1: DialogScanner proven on synthetic sources (it fires on the bad forms and stays
//  quiet on the good ones) before it runs over the real files.
//

import Testing

@Suite("Dialog scanner Tests")
struct DialogScannerTests {

    private func violations(_ source: String) -> [DialogScanner.Violation] {
        DialogScanner.containerAnchoredViolations(in: source)
    }

    // MARK: - Anchoring: bad

    @Test("OLD: a dialog chained onto a ScrollView is flagged")
    func scrollViewFires() {
        let source = """
        struct S: View {
            var body: some View {
                NavigationStack {
                    ScrollView {
                        Text("x")
                    }
                    .padding()
                    .confirmationDialog("Sure?", isPresented: $flag) {
                        Button("Go", role: .destructive) { }
                    }
                }
            }
        }
        """
        let found = violations(source)
        #expect(found.count == 1)
        #expect(found.first?.receiver == "ScrollView")
        #expect(found.first?.modifier == "confirmationDialog")
        #expect(found.first?.line == 8)
    }

    @Test("OLD: a dialog chained onto a List is flagged")
    func listFires() {
        let source = """
        struct S: View {
            var other: some View {
                List {
                    Text("x")
                }
                .confirmationDialog("Sure?", isPresented: $flag) { }
            }
        }
        """
        #expect(violations(source).map(\.receiver) == ["List"])
    }

    @Test("OLD: a dialog chained onto a Form is flagged")
    func formFires() {
        let source = """
        Form {
            Text("x")
        }
        .font(.body)
        .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).map(\.receiver) == ["Form"])
    }

    @Test("OLD: a dialog chained onto a NavigationStack is flagged")
    func navigationStackFires() {
        let source = """
        NavigationStack {
            Text("x")
        }
        .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).map(\.receiver) == ["NavigationStack"])
    }

    @Test("OLD: a dialog chained onto a TabView is flagged")
    func tabViewFires() {
        let source = """
        TabView {
            Text("x")
        }
        .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).map(\.receiver) == ["TabView"])
    }

    @Test("OLD: an alert chained onto a container is flagged too")
    func alertFires() {
        let source = """
        ScrollView {
            Text("x")
        }
        .alert("Oops", isPresented: $flag) { }
        """
        let found = violations(source)
        #expect(found.map(\.modifier) == ["alert"])
        #expect(found.map(\.receiver) == ["ScrollView"])
    }

    @Test("OLD: a dialog chained onto the root view of body is flagged")
    func rootOfBodyFires() {
        let source = """
        struct S: View {
            var body: some View {
                let detail = currentDetail
                return content(detail: detail)
                    .background(Color.clear)
                    .confirmationDialog("Sure?", isPresented: $flag) { }
            }
        }
        """
        let found = violations(source)
        #expect(found.count == 1)
        #expect(found.first?.receiver == "content")
        #expect(found.first?.line == 6)
    }

    @Test("OLD: a dialog on a root VStack of body is flagged")
    func rootStackFires() {
        let source = """
        struct S: View {
            var body: some View {
                VStack {
                    Text("x")
                }
                .confirmationDialog("Sure?", isPresented: $flag) { }
            }
        }
        """
        #expect(violations(source).map(\.receiver) == ["VStack"])
    }

    @Test("Two bad dialogs on one screen are both reported")
    func twoViolations() {
        let source = """
        List {
            Text("x")
        }
        .confirmationDialog("A", isPresented: $a) { }
        .confirmationDialog("B", isPresented: $b) { }
        """
        #expect(violations(source).count == 2)
    }

    // MARK: - Anchoring: good

    @Test("A dialog attached to a Button is fine")
    func buttonQuiet() {
        let source = """
        Button(role: .destructive) {
            flag = true
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .disabled(busy)
        .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A dialog attached to a Menu is fine")
    func menuQuiet() {
        let source = """
        Menu {
            Button("Delete") { }
        } label: {
            Image(systemName: "ellipsis")
        }
        .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A dialog attached to a row inside ForEach is fine")
    func forEachRowQuiet() {
        let source = """
        struct S: View {
            var body: some View {
                List {
                    ForEach(rows) { row in
                        Button { select(row) } label: { Text(row.title) }
                            .buttonStyle(.plain)
                            .confirmationDialog("Sure?", isPresented: $flag) { }
                    }
                }
            }
        }
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A dialog attached to a LabeledContent trigger is fine")
    func labeledContentQuiet() {
        let source = """
        LabeledContent("Owner", value: name)
            .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A dialog attached to a Label trigger is fine")
    func labelQuiet() {
        let source = """
        Label("Leave", systemImage: "door")
            .confirmationDialog("Sure?", isPresented: $flag) { }
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A container that holds a triggered dialog is not itself flagged")
    func containerHoldingTriggerQuiet() {
        let source = """
        ScrollView {
            Button("Go") { }
                .confirmationDialog("Sure?", isPresented: $flag) { }
        }
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A mention in a comment never fires")
    func commentQuiet() {
        let source = """
        // ScrollView { }.confirmationDialog("x", isPresented: $f) { }
        Text("x")
        """
        #expect(violations(source).isEmpty)
    }

    @Test("A source without dialogs is clean")
    func noDialogsQuiet() {
        #expect(violations("struct S { var body: some View { List { Text(\"x\") } } }").isEmpty)
    }

    // MARK: - Set then clear

    @Test("OLD: flag = true then flag = false in one scope is flagged at the clear")
    func setThenClearFires() {
        let source = """
        func open() {
            flag = true
            flag = false
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source) == [3])
    }

    @Test("OLD: set then clear with statements between, still no suspension, is flagged")
    func setThenClearWithWorkBetweenFires() {
        let source = """
        func open() {
            self.showsConfirm = true
            prepare()
            self.showsConfirm = false
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source) == [4])
    }

    @Test("A normal setter that clears only on dismissal is fine")
    func normalSetterQuiet() {
        let source = """
        var binding: Binding<Bool> {
            Binding(
                get: { isConfirming },
                set: { isPresented in
                    if !isPresented { flag = false }
                }
            )
        }
        func ask() {
            flag = true
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }

    @Test("A clear in a different scope than the set is fine")
    func differentScopeQuiet() {
        let source = """
        func run() {
            do {
                busy = true
            }
            busy = false
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }

    @Test("A clear after a suspension is fine")
    func clearAfterAwaitQuiet() {
        let source = """
        func load() async {
            isLoading = true
            await fetch()
            isLoading = false
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }

    @Test("A defer clear is fine")
    func deferQuiet() {
        let source = """
        func load() async {
            isLoading = true
            defer { isLoading = false }
            work()
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }

    @Test("Different flags set and cleared in one scope are fine")
    func differentFlagsQuiet() {
        let source = """
        func swap() {
            showsA = true
            showsB = false
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }

    @Test("Switch cases that set and clear the same flag are fine")
    func switchCasesQuiet() {
        let source = """
        switch phase {
        case .loading:
            showsLoading = true
        case .loaded:
            showsLoading = false
        }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }

    @Test("A comment that shows the pattern never fires")
    func setThenClearCommentQuiet() {
        let source = """
        // flag = true
        // flag = false
        func noop() { }
        """
        #expect(DialogScanner.setThenClearViolations(in: source).isEmpty)
    }
}
