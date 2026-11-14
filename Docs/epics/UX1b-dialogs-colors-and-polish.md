# UX1b: Anchored dialogs, destructive colors, the tab bar, the Face ID hint and cleanups
Track: iOS. Depends on: UX1a (merged). Blocks: the theme pass.
Contract state: unchanged; no contract change in this package.

Why: Brian's real-mode checks and the code reviews produced a polish backlog (PROGRAM.md section 11). The newest screens (items, purchases, the Children delete) already follow these rules; the older ones do not.

Rules (the product decisions; new code already follows them):
1. ANCHORED DIALOGS. Every confirmationDialog is attached to the control that opens it (the Button, the Menu, or the row for a swipe action, context menu or accessibility action), never to a screen container (a List, ScrollView, Form, NavigationStack, or the screen's root view). iOS 26 anchors a dialog to the view it is attached to.
2. STABLE PRESENTATION STATE. If a dialog is opened from a row (swipe action, context menu, accessibility action) or is presented after an await (a plan, a check, a network result), its presentation state lives in a pure presentation value owned ABOVE the rows (the screen's model or @State on the screen), exactly like ChildDeletionPresentation, and the dialog's isPresented and presenting come from that value. A plain tap on a plain Button in a non-list container, presenting synchronously, may keep Bool @State in the same view. The "set the flag, then clear it back to false" pattern is removed everywhere.
3. DESTRUCTIVE ACTIONS ARE RED. Every destructive action (delete, archive, remove, leave, clear) uses `role: .destructive` and the DesignSystem destructive color token: swipe actions (the tab view's green tint must not leak into them), context menu items, buttons, and the dialog's destructive button. Sign out is NOT destructive and stays neutral. Color is never the only signal (the title says what happens).
4. TAB BAR. The tab bar minimizes on scroll down (iOS 26 `tabBarMinimizeBehavior(.onScrollDown)`) and comes back on scroll up, on every tab whose root content is a vertical scroll view.
5. FACE ID HINT. After a failed password sign-in caused by wrong credentials, when Face ID or Touch ID sign-in is available on this device, the login screen shows ONE quiet hint as a caption just below the Sign In button (the wrong-password error itself is a modal alert and stays exactly as it is; the caption stays on screen after the alert is dismissed): "You can also sign in with Face ID." (the biometric name comes from the existing biometric-name logic: Face ID, Touch ID, or the generic wording). It is a caption, not an alert; it appears only for a credentials failure (never for a network error, a server error, a rate limit or a disabled account); it disappears when the user edits a field or signs in; it is a normal accessibility element read as the next element after Sign In, with no separate announcement.
   (Decision by Brian during UX1b, recorded here: the original wording said "under the error" and "announced to VoiceOver together with the error"; the login error is a modal alert, so the caption sits below Sign In and the alert is untouched. "Available" means the existing biometric button state is showEnrolled: biometric sign-in can actually be used now.)
6. CHILDREN TRY AGAIN. When Try Again on the Children delete banner recomputes the plan and the new plan contains any list the user did not confirm (a list id not in the confirmed plan), the flow goes back to the confirmation dialog with the new plan instead of continuing; if the recomputed plan is a subset of what was confirmed, it continues without a new dialog.

Scope: every confirmationDialog and alert in Features and App (the Children delete excepted: it conforms and only gets rule 6); every destructive control; Navigation/TabBarView.swift; the login screen's presentation; ChildrenView and the Children deletion presentation (rule 6); comments and test headers (Story B6).

Non-goals: UX1a's error banners and stale-data policy (do not change them, except the three named gaps in Story B0), services (except the recording of load outcomes in Story B0), repositories, authentication logic, biometric enrollment, the lock, purchase behavior (including the unconfirmed-purchase classifier), the theme pass, new screens, any contract change. Login, registration and lock screens keep their own alert or inline error patterns, except the Face ID hint caption and their dialogs' anchoring if they have any (the inventory decides).

Acceptance
- A scan test fails if a confirmationDialog or alert modifier is attached to a List, ScrollView, Form, NavigationStack or a screen's root container in Features or App, with a documented allowlist (alerts that are not confirmations, for example a system permission explanation, may be allowlisted with a reason).
- A scan test fails if any button, swipe action or context menu item whose role is destructive lacks the destructive color token, and if a swipe action for a destructive role lacks the explicit tint; sign out is checked to be neutral.
- Every row-opened or await-opened dialog uses a presentation value owned above the rows, with a pure transition table tested; no "set then clear false" pattern remains (scan).
- The tab view sets the minimize behavior (scan test; the visual result is Brian's real-mode check).
- The Face ID hint shows only for the credentials failure with biometrics available, never otherwise (pure presenter tests for every failure category).
- Children Try Again re-confirms exactly when the recomputed plan has unconfirmed lists (pure tests: subset, equal, superset, disjoint).
- Comment-only changes in Story B6 are proven comment-only (the check command in the story prints nothing).
- Session safety and every behavior outside presentation unchanged; no change under contract/, .claude/, any .pbxproj, the synced Docs files, LocalPackages/, services, repositories, or authentication logic.

---

# Inventory (read-only, taken on branch feat/ux1b-dialogs-colors-and-polish after the UX1a merge, PR 34, and the I5b merge, PR 35)

Baseline (P2): app suite 4230 passed, 0 failed, 0 skipped (scripts/test.sh); TrackerAPI package 212 tests in 16 suites; release-script tests 92; destination-script tests 17; scripts/verify.sh ends "verify: OK".

All paths below are under ChristmasTracker/ChristmasTracker/. Line numbers are as of this inventory.

## Confirmations and alerts

| # | File:line | Opened by | Attached to | State lives in | Row- or await-opened | Verdict |
|---|---|---|---|---|---|---|
| 1 | Features/Lists/Views/ListDetailView.swift:78 (leave list) | "Leave list" button in MembersSectionView (callback `onLeave`) | the detail screen's root view chain | `@State showLeaveConfirmation` (Bool) on the screen | plain button, synchronous | Breaks rule 1 (root). Rule 2 allows Bool because it is a plain tap, but it must move to the trigger or a presentation value |
| 2 | Features/Lists/Views/ListDetailView.swift:90 (remove member) | per-member "Remove" button in a roster row (callback `onRemove(row)`) | the detail screen's root view chain | `@State memberToRemove: MemberRowState?` on the screen; setter clears it | row-opened (a roster row inside a card) | Breaks rule 1 (root) and rule 2 (row-opened, the dialog also reads `presenting` from state the row's re-render owns indirectly) |
| 3 | Features/Lists/Views/ListDetailView.swift:379 (archive list) | the Archive button | the button | `@State showArchiveConfirmation` (Bool) | plain button, synchronous | Conforms to 1 and 2. Rule 3: the button label is filled with accent (not destructive) |
| 4 | Features/Dashboard/Views/DashboardView.swift:301 (archive list) | trailing swipe action "Archive" on a dashboard row | the row | `@State listToArchive: GiftList?` on the screen, per-row Binding (`archiveDialogBinding`) | row-opened (swipe) | Attached to the row and state on the screen: conforms to 1. Rule 2: the state is an optional model value, not a pure presentation value with a transition table; Cancel and the setter both clear it. Rule 3: the swipe action has no explicit tint |
| 5 | Features/Lists/Views/EditListView.swift:142 (remove co-owner) | "Remove co-owner" button in the Co-owner section of the form | the Form (screen container) | `@State showsRemoveConfirmation` (Bool) | plain button, synchronous | Breaks rule 1 (Form). Rule 3: the button has the role but no token |
| 6 | Features/Profile/Views/ProfileView.swift:79 (log out) | LogoutButtonView | the ScrollView inside the NavigationStack | `@State showLogoutConfirmation` (Bool) | plain button, synchronous | Breaks rule 1 (ScrollView). Rule 3: the dialog's "Logout" button has `role: .destructive`, but sign out must be NEUTRAL |
| 7 | Features/Items/Views/ItemDetailView.swift:299 (delete item) | Delete Item button | the button | `@State showDeleteConfirmation` (Bool) | plain button, synchronous | Conforms to 1, 2 and 3 |
| 8 | Features/Statistics/Views/BudgetCardMenu.swift:45 (delete budget) | Delete item in the budget card Menu | the Menu | `StatsScreenModel.isShowingDeleteConfirmation` (screen model, above the rows) | menu item | Conforms (I5a) |
| 9 | Features/Purchases/Views/ManagePurchaseView.swift:325 (delete purchase) | Delete button | the button | model/state of the purchase detail | plain button | Conforms (read only here) |
| 10 | Features/Purchases/Views/RecordPurchaseRecordSection.swift:31 (over-purchase prompt, not destructive) | Record button, after a check | the Record button | `RecordPurchaseModel.isShowingOverPurchasePrompt` (model) | await-opened | Conforms; not destructive |
| 11 | Features/Children/Views/ChildrenView.swift:368 (delete child) | row swipe and context menu | the row | `ChildDeletionPresentation` on the screen | row and await-opened | Conforms; only rule 6 changes |
| A1 | Features/Authentication/Views/LoginView.swift:82 (error alert) | `authService.error` | the ScrollView in the NavigationStack | `@State showError` mirrored by `onChange` | error display, not a confirmation | Allowlist: the login screen keeps its own alert pattern (brief non-goal) |
| A2 | LoginView.swift:87 (Set Up Biometrics) | biometric tap when setup is needed | same | `LoginBiometricModel.showSetupAlert` | explanation, not a confirmation | Allowlist: system-permission style explanation |
| A3 | LoginView.swift:105 (Enable <biometric>) | biometric tap when not enrolled | same | `LoginBiometricModel.showNotEnrolledAlert` | explanation, not a confirmation | Allowlist: explanation |
| A4 | Features/Authentication/Views/RegistrationView.swift:30 (error alert) | `authService.error` | the ScrollView | `.constant(authService.error != nil)` | error display | Allowlist: registration keeps its own alert pattern |

No other `confirmationDialog` or `.alert(` exists in Features or App (grep). The lock screen has none.

"Set, then clear" pattern: to be located by the B1 scan (rows 2 and 4 hold optional state that the setter and Cancel clear; B1 decides whether any flag is set and then immediately cleared).

## Destructive controls

| File:line | Control | Role | Color today | Verdict |
|---|---|---|---|---|
| ListDetailView.swift:366 | Archive button | destructive | accent fill (`Color.accentColor`) | needs the token |
| ListDetailView.swift:83, 99, 384 | dialog buttons (leave, remove member, archive) | destructive | none | need the token |
| MembersSectionView.swift:67 | Leave list button | destructive | `.tint(.accentColor)` | needs the token |
| MembersSectionView.swift:102 | member Remove button | none | accent foreground | needs role and token |
| DashboardView.swift:293 | Archive swipe action | destructive | none (the tab view tint leaks) | needs explicit tint |
| DashboardView.swift:306 | dialog button | destructive | none | needs the token |
| EditListView.swift:147, 212 | Remove co-owner dialog button and button | destructive | none | need the token |
| ProfileView.swift:84 | Logout dialog button | destructive | none | sign out must be NEUTRAL: remove the role |
| ItemDetailView.swift:289, 304 | Delete Item button and dialog button | destructive | token | conforms |
| BudgetCardMenu.swift:29, 50 | Delete Budget item and dialog button | destructive | token | conforms |
| BudgetEditorView.swift:255 | Remove row button | destructive | token | conforms (checked by B2 scan) |
| ManagePurchaseView.swift:309, 330 | Delete purchase button and dialog button | destructive | token | conforms |
| ChildrenView.swift:352, 359, 374 | swipe action, context menu item, dialog button | destructive | token | conforms |

Token: `Color.destructiveColor` (DesignSystem/Colors/AppColors.swift:51, `systemRed`). No destructive-role helper exists in DesignSystem yet (B2 adds one).

## Tab view

Navigation/TabBarView.swift: one `TabView(selection:)` with three tabs: DashboardView (a `List`), StatsView (to be confirmed by B3: note any root that is not a vertical scroll view), ProfileView (a `ScrollView`). `.tint(.primaryColor)` is set on the TabView (the green that leaks into swipe actions). No `tabBarMinimizeBehavior` today.

## Login

LoginView reads `authService.error` (`AuthenticationError?`), shown in the "Error" alert. A credentials failure is `AuthenticationError.invalidCredentials` (thrown in GeneratedClientAuthenticationRepository.swift:52 and :54; mapped in AuthErrorMessages.swift:12). Biometric availability and name: `authService.isBiometricAvailable`, `authService.biometricType.displayName`, and `loginBiometricButtonState(readiness:enrolledUser:biometryTypeName:)`; the sign-in button section shows when `biometricModel.buttonState != .hidden`. The login error is an alert, so the hint is a caption in the form column; B4's Gate 1 states exactly where.

## Children delete

ChildDeletionPresentation.swift: phases idle, planning, confirming(childId, plan), executing; pure transitions. ChildDeletionFlow.swift: plan, run, execute. ChildrenView.swift:290 `retryDeletion` plans afresh and continues without a new dialog (rule 6 changes this).

## Test headers saying "Fails today" or similar

50 test files under ChristmasTrackerTests (grep of "Fails today", "fails today", "currently fail"): DesignSystem (InlineErrorBannerStateTests, DestructiveColorTests, InlineErrorBannerActionsTests), Core/ListPermissionsTests, Features/Lists/ListMappingTests, Features/Items (ItemListStateTests, ItemInputBuildingTests, ItemErrorPresentationTests, ItemMappingTests, ItemDetailPurchaseOpenScanTests, ItemErrorTests, ItemRowStateTests, ItemPurchaseRowStateTests, ItemFormValidationTests), and the Features/Purchases files. The full list is regenerated by Story B6 with the grep command and pasted in its report.

## Stale comments named by earlier reviews

The Children repository comment about the delete, and older scan-test comments: located by Story B6 (search again; do not trust earlier line numbers).

## The orphaned Keychain item

The deleted file is Core/Security/DeviceFIngerprintService.swift (deleted in f57fd28, "I4b: delete the legacy purchase stack"). Its last version stored a UUID with `KeychainService.set(uuid, for: "com.christmastracker.deviceFingerprintUUID", accessControl: .afterFirstUnlock)`. The first-launch legacy wipe (Features/Authentication/Services/FirstLaunchWipe.swift) is NOT a plain list of items: it deletes the whole generic-password and internet-password classes through `KeychainWiping`, once, on a clean install. The separate `LegacyTokenCleanup` is a plain list, but it also names the biometric token and session tokens, which this package must not touch. Decision for Story B6(c): the precondition "the wipe is a plain list" is NOT met, so no code change; the finding is banked in the B6 report and the handoff.

---

# Gate 1 specs

Every story takes the FULL pipeline (isolated test-writer, implementer, convention-reviewer, then acceptance-reviewer): they touch capability-flag-driven UI and, in B0, the service layer. Contract slice: none in any story.

## Gate 1: B0 UX1a leftovers
- Acceptance: (1) a reload that fails after a successful mutation is recorded as a revalidation failure for that screen's load and shows "Couldn't update. Showing saved data." through the existing policy; the mutation stays a success. (2) Items never loaded plus an items load failure shows a neutral "Items unavailable" state in the items section, never the empty copy; a pure state function decides. (3) `detailLoadFailure` is keyed by list id; a failure for list A is never presented on list B; the F5 dismissed-count resurfacing is fixed if possible without changing the policy's category mapping, otherwise banked with the reason.
- Scope: Features/Lists/Services/ListService (load outcome recording only), Features/Lists load state and policy inputs, ListDetailView and ItemsSectionView (presentation), the matching tests. No session guard, no policy category mapping change.
- New interface: yes (the keyed failure accessor and the items-section state function). Signatures, fixed after reading ListService.swift, ListDetailView.swift, ItemsSectionView.swift and StatsScreenModel.swift:

  Gap 1 (recorded, not thrown). Today three post-mutation reloads only LOG a failure through `record(...)`: `refetchDetailAfterMemberChange` (addMember, removeMember; operation "refresh list after member change"), and in `reloadAfterArchive` both the lists reload ("reload lists after archive") and the detail refetch ("refresh list after archive"). New behavior, same two public methods, same return and throw behavior (the mutation still succeeds silently, never throws because of the reload):
  - a failed detail refetch (a failure that `record` returns non-nil; not cancellation, not an ended session, not a gone list) after addMember, removeMember or archive stores that failure under the list's id in the keyed detail failures (below);
  - a failed lists reload after archive sets `listsLoadFailure` to the recorded failure (the dashboard banner), still removing the archived list from `lists`;
  - a SUCCESSFUL detail refetch (member change or archive) removes the keyed entry of that list id; the superseded-reload rule (`reloadToken`) is unchanged: a superseded reload records nothing.
  - NOT changed: `refetchAfterArchivedReadOnly` (the mutation itself failed there), the session guards, the generation and epoch checks, the policy's category mapping.

  Gap 3 (keyed by list id). In ListService replace `private(set) var detailLoadFailure: ListError?` with `private(set) var detailLoadFailures: [String: ListError]` and:
  ```swift
  func detailLoadFailure(forListId id: String) -> ListError?   // the entry for that id only
  func clearDetailLoadFailure(forListId id: String)            // removes that id's entry
  func clearDetailLoadFailure()                                // existing: removes every entry
  ```
  `loadListDetail(id:)` clears only that id's entry when it starts and stores its failure under that id (including the `reportGuarded(... storingFailure: true)` not-found); `resetSession` clears all. ListDetailView reads `listService.detailLoadFailure(forListId: listId)` and clears with the keyed clear on disappear and when it starts a load; existing call sites and tests of the old property are migrated mechanically to the keyed accessor with the id they already use (list each in the report as "rewritten").

  F5 (dismissed-count resurfacing, `StatsScreenModel.noteLoadOutcome`: `failureCount` is incremented once per failed load outcome whether or not the failure is a new one). Fix only if it can be done inside StatsScreenModel/DismissedLoads without touching the policy's category mapping or `ScreenLoadPresentation`; otherwise bank it in the report with the exact reason.

  Gap 2 (items unavailable). New pure function in Features/Items/ViewState (new file ItemsSectionAvailability.swift):
  ```swift
  nonisolated enum ItemsSectionAvailability: Equatable, Sendable {
      case loading        // a load is running and there is nothing to show yet
      case content        // there are rows to show (cached or fresh), failure or not
      case empty          // the items loaded and are empty
      case unavailable    // no rows AND the items load failed: neutral copy, never the empty copy
      static func make(isLoading: Bool, hasRows: Bool, itemsFailure: ItemError?) -> ItemsSectionAvailability
      static let unavailableText: String   // "Items unavailable. Pull to refresh or tap Try Again."
  }
  ```
  Rules: hasRows -> content; else isLoading -> loading; else itemsFailure != nil -> unavailable; else empty. ItemsSectionView renders `.unavailable` as a neutral muted text in the items section (token styles), keeps the Add Item control rules unchanged, and shows the empty copy only for `.empty`; ListDetailView passes `itemService.listLoadError` in. No ItemService change.
- Tests (deterministic, each pinned to the old behavior in its first comment line): (1) archive succeeds, detail refetch fails -> keyed failure for that id, archive returned without throwing (old: nothing recorded); (2) addMember and removeMember likewise; (3) lists reload fails after archive -> `listsLoadFailure` set, list removed (old: nothing stored); (4) a successful refetch clears the keyed entry; (5) failure for list A is not returned by `detailLoadFailure(forListId: B)` and loading B does not clear A's entry (old: single slot); (6) session reset clears all; (7) the `ItemsSectionAvailability` table including "failed with no rows is unavailable, not empty"; (8) F5 if fixed. No session-safety test weakened.

## Gate 1: B1 Anchored dialogs and stable presentation state
- Acceptance: rows 1, 2, 4, 5, 6 of the inventory conform to rules 1 and 2; texts, buttons and outcomes unchanged; a re-render, reload, refresh or swipe close does not dismiss an open dialog; a vanished target resets to idle silently; session end and disappear reset. Scan tests for anchoring (with the allowlist A1 to A4) and for the absence of "set then clear".
- Scope: ListDetailView, MembersSectionView, DashboardView, EditListView, ProfileView, new pure presentation values under Features/Lists and Features/Dashboard, the scan test.
- New interface: yes (pure presentation values with transition tables). Signatures:

  One generic pure value, owned by the screen (`@State`), shared by the four screens that need it. New file Features/Shared/Presentation/ConfirmationPresentation.swift:
  ```swift
  nonisolated struct ConfirmationPresentation<Target: Hashable & Sendable>: Equatable, Sendable {
      let target: Target?                         // nil = idle
      static var idle: ConfirmationPresentation { get }
      var isIdle: Bool { get }
      func isConfirming(_ target: Target) -> Bool
      func requesting(_ target: Target) -> ConfirmationPresentation          // only from idle; otherwise unchanged
      func cancelled() -> ConfirmationPresentation                           // always idle
      func confirmed(_ target: Target) -> (presentation: ConfirmationPresentation, run: Target?)
          // from confirming(target): (idle, target); any other phase or another target: (unchanged, nil)
      func targetsChanged(existing: Set<Target>) -> ConfirmationPresentation // idle only if the target is no longer in existing; same ids re-rendered or reloaded: unchanged
      func reset() -> ConfirmationPresentation                               // idle (session end, screen disappear)
  }
  ```
  Targets (nonisolated, Hashable, Sendable): `MembersDialogTarget { case leave; case removeMember(userId: String) }` (Features/Lists/ViewState), `EditListDialogTarget { case removeCoOwner }` (Features/Lists/ViewState). The Dashboard archive uses `ConfirmationPresentation<String>` keyed by list id.

  Screens:
  - ListDetailView (leave, remove member): `@State private var membersDialog = ConfirmationPresentation<MembersDialogTarget>.idle`. The leave dialog is attached to the Leave list button and the remove dialog to each roster row's Remove button (both inside MembersSectionView; the screen passes the presentation and closures in). `isPresented` for each is derived from `isConfirming(...)`, and its setter only ever calls `cancelled()` when the dialog dismisses without a confirm (no flag is set and then cleared). While not idle, Add member, Leave and every Remove are disabled. The roster's user ids feed `targetsChanged(existing:)` on every roster change; `reset()` on disappear and when the session ends. The archive dialog (row 3) stays a Bool on its own button (plain tap, non-list container).
  - DashboardView (archive swipe): `@State private var archiveDialog = ConfirmationPresentation<String>.idle` replaces `listToArchive` and `archiveDialogBinding`. The dialog stays attached to the row; confirm runs `confirmed(listId)`; `targetsChanged(existing:)` with the visible list ids; `reset()` on disappear/session end.
  - EditListView (remove co-owner): the Form is a list container, so the dialog moves onto the Remove co-owner button and its state becomes `ConfirmationPresentation<EditListDialogTarget>`; competing controls (Save, Cancel, the remove button) disabled while not idle.
  - ProfileView (log out): plain Button in a ScrollView/VStack, so Bool is allowed, but the dialog moves from the ScrollView onto the Log out button inside LogoutButtonView (the button keeps its present look; rule 3 is B2).
  Pure scan helpers live in the TEST target, are pure functions over a source String, and are themselves tested with bad and good fixture snippets before being run over the real files:
  ```swift
  enum DialogScanner {
      struct Violation: Equatable { let line: Int; let modifier: String; let receiver: String }
      /// confirmationDialog/alert modifiers whose receiver chain head is List, ScrollView, Form, NavigationStack, TabView, or the screen's root view (the first expression of `var body`).
      static func containerAnchoredViolations(in source: String) -> [Violation]
      /// a Bool set to true and cleared back to false in the same synchronous scope (e.g. `flag = true` followed by `flag = false`), the "set then clear" pattern
      static func setThenClearViolations(in source: String) -> [Int]
  }
  ```
  The real-file scan walks Features/ and App/ under ChristmasTracker/ChristmasTracker and has an allowlist (relative file path to reason), initially: LoginView.swift and RegistrationView.swift (the auth screens keep their own error and explanation alerts: brief non-goal).
- Transition-table tests (pure): idle/requesting/second request ignored/cancelled/confirmed(right target, wrong target, from idle)/targetsChanged (same ids, extra ids, target gone)/reset; the dialog-target enums; "events that must not reset it" = re-render and reload with the same ids.

## Gate 1: B2 Destructive colors
- Acceptance: every destructive control in the table above uses `role: .destructive` and the token; swipe actions carry the explicit tint; Sign out is neutral (no destructive role, no red). A DesignSystem helper maps destructive action kinds to the token. Scan tests per the Acceptance.
- Scope: the views named in the table, DesignSystem, tests.
- New interface: yes (the DesignSystem destructive-role helper). Signatures, in DesignSystem/Components/DestructiveAction.swift:
  ```swift
  nonisolated enum DestructiveActionKind: CaseIterable, Sendable { case archive, delete, remove, leave, clear }
  extension DestructiveActionKind { var color: Color { get } }   // every kind maps to Color.destructiveColor
  extension View { func destructiveTint() -> some View }          // .tint(Color.destructiveColor)
  ```
  Changes (views; roles and texts stay): ListDetailView archive button (filled with the destructive token, not accent) and its dialog button; MembersSectionView Leave list button (tint destructive, not accent), the member Remove icon button (gets `role: .destructive` and the token) and the leave/remove dialog buttons; DashboardView Archive swipe action (explicit destructive tint) and its dialog button; EditListView Remove co-owner button and dialog button; ProfileView Logout: the dialog's Logout button loses `role: .destructive` and stays neutral (sign out is not destructive). Already conforming and only checked: ItemDetailView, BudgetCardMenu, BudgetEditorView, ManagePurchaseView, ChildrenView. A destructive control "has the token" when its own modifier chain contains `destructiveTint()`, `.tint(Color.destructiveColor)`, or `Color.destructiveColor` as its foreground or background style.
  Scan tests (test target, pure scanners over a source String, fixture-tested, then run over every .swift file under Features/ and App/): (a) every `Button(... role: .destructive ...)` (button, swipe action, context-menu item, dialog button) has the token in its chain; (b) a destructive Button inside `.swipeActions` has an explicit tint; (c) sign out is neutral: ProfileView.swift contains no `role: .destructive`; (d) a destructive helper test: every `DestructiveActionKind` maps to `Color.destructiveColor`. Allowlist: none expected (state any with a reason).

## Gate 1: B3 The tab bar
- Acceptance: `tabBarMinimizeBehavior(.onScrollDown)` set once on the TabView; nothing else about tabs changes; any tab whose root is not a vertical scroll view is noted. A scan test.
- Scope: Navigation/TabBarView.swift, one scan test.
- New interface: no. (Solo mode would be permitted by CLAUDE.md, but this package says full pipeline for every story; the story is small, so the pipeline is short.)

## Gate 1: B4 The Face ID hint
- Acceptance: a pure presenter maps (failure category, biometric button state, biometric name) to no hint or the hint text; rendered as a muted caption just below the Sign In button (the error alert is unchanged), kept in screen state so it survives the alert's dismissal, cleared on field edit or sign-in start; a normal accessibility element after Sign In with no extra announcement. No sign-in, biometric or lock logic changes.
- Scope: Features/Authentication/Views/LoginView.swift (rendering and the hint state only), a new presenter file, tests.
- New interface: yes. Signatures (new file Features/Authentication/LoginFaceIDHint.swift):
  ```swift
  nonisolated enum LoginFaceIDHint {
      /// nil unless error == .invalidCredentials AND buttonState is .showEnrolled
      static func text(for error: AuthenticationError?, buttonState: LoginBiometricButtonState, biometricName: String) -> String?
      // "You can also sign in with \(biometricName)."   (biometricName from BiometricType.displayName)
  }
  nonisolated struct LoginFaceIDHintState: Equatable, Sendable {
      let text: String?                                    // nil = no hint
      static let none: LoginFaceIDHintState
      func signInFailed(error: AuthenticationError?, buttonState: LoginBiometricButtonState, biometricName: String) -> LoginFaceIDHintState   // text(for:...) or none
      func fieldEdited() -> LoginFaceIDHintState           // none
      func signInStarted() -> LoginFaceIDHintState         // none
      func reset() -> LoginFaceIDHintState                 // none (screen disappear / session end)
  }
  ```
  LoginView holds `@State private var hint = LoginFaceIDHintState.none`; `handleLogin` calls `signInStarted()` before the login, and after the awaited `authService.login` returns it calls `signInFailed(error: authService.error, ...)`; `onChange` of email and password call `fieldEdited()`. The hint caption Text sits directly after LoginActionSection in `contentView`, uses AppTypography/AppColors/AppSpacing tokens, and has no accessibility identifier containing user data. The existing `.alert("Error"...)` code is not touched. "Available" = `loginBiometricButtonState(...)` is `.showEnrolled` (biometric sign-in can be used now); `.hidden`, `.showNotEnrolled`, `.showNeedsSetup` give no hint.
- Tests: the presenter for every AuthenticationError case with an enrolled button state (only invalidCredentials shows the hint), every non-enrolled button state with invalidCredentials (no hint), the name for faceID, touchID and none ("Face ID", "Touch ID", "Face ID or Touch ID"), nil error; the state transitions (signInFailed shows, fieldEdited/signInStarted/reset clear, a later non-credentials failure replaces a shown hint with none); a scan test that LoginView.swift renders the hint only through `LoginFaceIDHintState`/`LoginFaceIDHint` (no literal "You can also sign in" in views), that the `.alert("Error"` block still exists unchanged, and that no sign-in, biometric or lock files changed is checked in review by git diff.

## Gate 1: B5 Children Try Again re-confirms
- Acceptance: Try Again recomputes the plan; any list id not in the confirmed plan returns to confirming with the new plan; a subset or equal plan continues; a blocked plan follows the existing blocked path; everything else (first-failure stop, child never deleted after a failed archive, cancel on disappear, session guards, red controls, announcements) is intact.
- Scope: ChildDeletionPresentation, ChildrenView, ChildrenState (announcements, if needed), tests.
- New interface: yes (a new transition on ChildDeletionPresentation).

## Gate 1: B6 Cleanups
- Acceptance: (a) and (b) comment lines only, proven by the empty check; (c) not changed (the wipe is not a plain list; banked); (d) and (e) dead-code removal, each its own commit with its own verify runs and stop conditions.
- Scope: test headers, the Children repository comment, ChildrenState and the recipient options (d), ItemPermissions and ItemMapping comments (e).
- New interface: no.

## Gate 1: B7 Handoff and real-mode check
- Acceptance: the handoff note per CLAUDE.md with the fixed numbered real-mode check; one step per inventory dialog taken from the code.
- Scope: Docs/handoffs, Docs/reports. Docs only.
- New interface: no.
