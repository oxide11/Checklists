# Proceed — Backlog

Snapshot of the app's state on branch `claude/review-and-backlog-HT7wr`. Items are grouped by area and tagged with a rough severity: **P0** (correctness/safety), **P1** (real bug or visible UX gap), **P2** (polish/tech debt), **P3** (nice-to-have).

---

## Completed on this branch

Items closed during the audit-and-fix pass (in commit order):

- **Data integrity:** explicit `.nullify` deleteRule on `Folder.checklists`, `ProcedureCategory.checklists`, `Equipment.checklists`; regression tests cover all three.
- **Execution semantics:** `ExecutionEngine.completeStep` refuses decision steps (forces `selectBranch`); tests updated and a guard test proves a rejected complete leaves no dirty state.
- **Destructive UX:** swipe-to-delete on Folders/Categories/Equipment/Issues now routes through `.confirmationDialog` with a count-aware message.
- **Save failures:** `EditableChecklist.save` and `IssueReportView.submit` call `context.save()` and throw; both editors catch and present the real error in an alert.
- **Services hardening:** Keychain pins items to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; `ExportService.exportPDF` throws `ExportError` with real messages instead of silently returning empty `Data`; CloudKit error message reaches `ShareStatusView`.
- **Workflow entity:** new `Workflow` `@Model` replaces the `workflowID`/`workflowName` string trio with a real relationship; `WorkflowDetailView` takes a `Workflow`; empty workflows are deleted on removal; tests cover create/cleanup/dissolve.
- **`Checklist.status` as enum:** stored as `ProcedureStatus` directly; the silent-fallback `procedureStatus` computed property was removed; the `PendingApprovalsView` predicate compares against the enum case.
- **UX wins:** `EquipmentInventoryView` empty state has an "Add Equipment" CTA; `StepEditorView` decision rows now warn when a branch has no label, is unlinked, or points at a deleted step.
- **Accessibility:** `ExecutionStepRow` and `InlineStepRow` completion indicators announce their state; `ChecklistRow` collapses into a single VoiceOver utterance covering emergency / version / step count / review-due.
- **Timer race:** `ChecklistExecutionView`'s auto-advance check verifies `engine.currentStepID == step.id` before firing, so manual completes or navigation during the banner delay don't get clobbered.
- **Tests:** PDF export (`%PDF` magic + multi-step size); delete-rule regression for Folder/Category/Equipment; Workflow create/cleanup/no-cascade-to-procedures; engine edge cases (double-complete idempotency, branch-to-missing-target, selectBranch-on-action).

---

## What Works Today

- **Library navigation** — `ContentView` renders Emergency, Folders, Workflows, and Category sections from SwiftData `@Query`s; drag-and-drop into folders is wired (`ContentView.swift:134-139`, `196-201`).
- **Editor** — `ChecklistEditorView` + `StepEditorView` support full CRUD, step reordering, branch authoring, equipment linking, media attachments.
- **Execution engine** — `ExecutionEngine` is a correct DAG traversal with cycle protection (`ExecutionEngine.swift:89-116`), branch selection, and a clean reset path. 18 unit tests cover linear/branching paths.
- **Export** — `ExportService` produces real Markdown, HTML, and PDF output (not stubs) with HTML escaping (`ExportService.swift:228-235`).
- **Keychain** — `KeychainService` correctly uses `SecItemAdd`/`SecItemDelete`/`SecItemCopyMatching` round-trips with 8 integration tests.
- **Approvals** — Draft → Pending → Approved/Rejected flow exists end-to-end via `PendingApprovalsView` / `ApprovalView`.
- **CloudKit container** — `ProceedApp` configures `.automatic` CloudKit with a graceful in-memory fallback if the store fails to open (`ProceedApp.swift:22-49`).
- **Test coverage** — Unit tests for execution, JSON round-trips, enums, computed properties, editable-checklist save flow, export, keychain.

---

## Open Items

### Data Layer

- **P1 — Two parallel equipment representations.** `Checklist.requiredEquipment: [String]` (JSON, `:47-55`) and `Checklist.requiredEquipmentItems: [Equipment]` (relationship, `:24-25`) both exist. `EditableChecklist.save` updates strings but doesn't sync the relationship. Product decision needed: ad-hoc text items + linked Equipment records as two distinct concepts, or collapse to one.
- **P1 — Silent JSON decode failures.** `branchOptions`, `requiredEquipment`, `requiredEquipmentIDs`, `fieldChanges` all `?? []` on decode failure. A corrupt blob silently drops branch targets or audit history. Add `os.Logger` at the call sites at minimum.
- **P2 — Equipment ↔ Step orphan refs.** `ChecklistStep.requiredEquipmentIDsData` stores raw UUIDs (`ChecklistStep.swift:30-40`) with no FK enforcement. Reads filter missing IDs (so display is fine), but the data bloats. Either migrate to a real many-to-many `@Relationship` on the step, or add a cleanup hook when Equipment is deleted.
- **P2 — No soft-delete / archival.** All `.cascade` deletes are permanent. ChangeLog survives but the steps it references don't, so audit entries become orphans referencing a missing step.
- **P2 — `MediaAttachment` orphan window.** Cascade fires on step delete, but a user removing media mid-edit before save leaves the in-memory `EditableMediaAttachment` removed and the underlying `MediaAttachment` blob untouched until save replaces all steps.
- **P2 — `ProcedureRole` permissions are display-only.** Viewer/editor/approver tags exist but no code path enforces them.
- **P3 — `EditableModels` duplicates every field.** Maintenance cost grows linearly with the schema. Worth revisiting with codegen or a protocol once the model stabilizes.

### Execution

- **P1 — `isCriticalFailure` is display-only.** Renders as a badge but the engine never gates on it. Product decision: should marking a step critical force a separate acknowledgment / signature before passing, or is "critical" just a visual cue?
- **P1 — Timer logic lives in the view.** `ChecklistExecutionView.swift:236-273` owns the timer task, so the auto-advance flow isn't unit-testable. Moving it into `ExecutionEngine` (with a callback for view-side bookkeeping) would close the gap.
- **P2 — Inline-mode timer duplicates the view timer.** `ChecklistDetailView.swift:453-464` runs its own copy of the same pattern. Will be obsoleted by moving timer state into the engine.

### Views & UX

- **P1 — Detail pane is a dead end.** `ContentView.swift:276-280` shows only `ContentUnavailableView` in the detail column — no recently-opened list, no "create your first" CTA.
- **P2 — Stacked presentation modifiers.** `ChecklistDetailView` carries eight sheet/fullScreenCover modifiers. Works today, but an enum-driven presentation route would prevent accidental double-toggles.
- **P2 — Remaining accessibility gaps.** Settings toggles (`SettingsView.swift:22-48`) and the "procedure complete" banner still need labels/hints. (Completion indicators and `ChecklistRow` were covered.)
- **P2 — Step row duplication.** `InlineStepRow` (319 lines) and `ExecutionStepRow` (370 lines) implement the same timer / equipment / media / branch UI twice. Unify with a `DisplayMode` enum on a single row.
- **P3 — `@AppStorage` re-read every body eval** in `ChecklistExecutionView.swift:9-12`. Cheap; worth a `@State` cache only if profiling flags it.
- **P3 — `@Query` per-step filter** in execution views fetches all equipment per row. Scope the query when the equipment count grows.

### Services & Infrastructure

- **P1 — `CloudKitSharingService` is a UI shim.** `CloudSharingSheet` (`:45-106`) wraps `UICloudSharingController` and delegates record creation to a caller-supplied closure. There's no persistence of who's sharing what, no share-acceptance handling, no participant management. The file's name still overpromises.

### Tests

- **P1 — No UI/integration tests.** Engine logic is well-covered, but the SwiftUI view layer (sheet/cover state, timer auto-advance triggering, branch selection from a tap) is untested. Requires an XCUITest target or a ViewInspector-style harness.
- **P2 — `EditableChecklistSaveTests` doesn't cover delete cascades** — adding a step, then removing it, then saving — and doesn't exercise the new `try context.save()` failure path.

---

## Suggested Next Sprint

The highest-leverage remaining work, in order:

1. **Move timer state into `ExecutionEngine`** — unblocks unit-level timer tests and eliminates the duplicated view-side pattern in inline and execution modes.
2. **Decide and execute equipment source-of-truth** — either drop `Checklist.requiredEquipment: [String]` or document the split formally and have `EditableChecklist.save` sync both sides.
3. **Detail-pane CTA + remaining accessibility labels** — small, visible polish for first-run and VoiceOver users.
4. **Real `CloudKitSharingService`** — persistence of share state, participant handling, accept-share flow. Larger product work.
5. **UI/integration test harness** — set up an XCUITest target driving a scripted procedure run.
