# Proceed — Backlog

Snapshot of the app's state on branch `claude/review-and-backlog-HT7wr` (commit `e04905e`). Items are grouped by area and tagged with a rough severity: **P0** (correctness/safety), **P1** (real bug or visible UX gap), **P2** (polish/tech debt), **P3** (nice-to-have).

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

## Data Layer

### P0
- **Folder/Category delete leaves dangling references.** `Checklist.folder` (`Checklist.swift:19`) and `Checklist.category` (`:18`) have no explicit `deleteRule`. Deleting a Folder/Category leaves Checklists pointing at a tombstoned object; behavior under CloudKit sync is undefined. Set `.nullify` explicitly on the inverse declarations in `Folder.swift:11` and `Category.swift` (add a `@Relationship(deleteRule: .nullify, inverse: \Checklist.category)` on `ProcedureCategory.checklists`, currently missing the `@Relationship` decorator at `Category.swift:13`).
- **Equipment ↔ Step orphan refs.** `ChecklistStep.requiredEquipmentIDsData` stores raw UUIDs (`ChecklistStep.swift:30-40`) with no FK enforcement; deleting an `Equipment` row leaves step requirements pointing at nothing. Either migrate to a real `@Relationship` or add a cleanup pass when Equipment is deleted.

### P1
- **Two parallel equipment representations.** `Checklist.requiredEquipment: [String]` (JSON-encoded names, `:47-55`) and `Checklist.requiredEquipmentItems: [Equipment]` (relationship, `:24-25`) both exist. `EditableChecklist.save` updates strings but doesn't sync the relationship. Pick one source of truth.
- **`status` is a free-form `String`.** `Checklist.status` is documented to be a finite set (`Checklist.swift:14`) but stored as `String`. The `procedureStatus` computed property (`:72-75`) silently falls back to `.published` on bad input. Either store the enum directly or add a setter guard.
- **Silent JSON failure on relationship-adjacent data.** `branchOptions`, `requiredEquipment`, `requiredEquipmentIDs`, `fieldChanges` all `?? []` on decode failure. A corrupt blob silently drops branch targets or audit history. At minimum log; ideally surface as a recoverable error in the editor.

### P2
- **Branch targets unvalidated.** `BranchOption.targetStepID` is a UUID with no constraint that it points at a step in the same checklist (`ChecklistStep.swift:57-65`). Editor should validate; engine already cycle-guards but happily walks to a missing target → execution dead-ends.
- **No soft-delete / archival.** All `.cascade` deletes are permanent. ChangeLog survives but the steps it references don't, so audit entries become orphans.
- **`createWorkflow` lives on `Checklist` as a static func** (`:106-113`), mutating `workflowID/Order/Name` directly with no Workflow entity. Querying "which checklists are in workflow X" requires scanning all checklists. Consider a `Workflow` model.
- **`MediaAttachment` orphaning on in-place edits.** Cascade fires on step delete, but if a user removes media during an edit the orphaned blob persists.
- **`ProcedureRole` has no permission enforcement.** Roles exist as labels only; viewer/editor distinctions are not honored anywhere.

### P3
- **`EditableModels` duplicates every field** of the underlying SwiftData models (`EditableModels.swift`). Maintenance cost grows with each new field. Consider a code-gen or protocol approach when the schema stabilizes.

---

## Execution

### P0
- **Decision-step "complete without choosing" is possible at the engine level.** `completeStep` on a `.decision` step inserts the ID into `completedStepIDs` but doesn't advance (`ExecutionEngine.swift:62-68`). The UI is expected to call `selectBranch` instead, but the engine itself doesn't reject the misuse. Add a guard or split the API so decision steps can only be completed via `selectBranch`.

### P1
- **Critical-step gating is display-only.** `ChecklistStep.isCriticalFailure` (`:27`) renders a badge in `ExecutionStepRow.swift:233-237` but is not consulted by the engine. If the product intent is "user must explicitly confirm before passing a critical step," that gate doesn't exist.
- **Timer logic lives entirely in the view** (`ChecklistExecutionView.swift:236-273`) — not engine-owned, so untestable. The view-disappear cancellation works, but there's still a race window between `.onDisappear` and the next `MainActor.run` if the user dismisses mid-tick.

### P2
- **Inline-mode timer leak risk.** `ChecklistDetailView.swift:453-464` has the same view-owned timer pattern, with `.onDisappear { stopTimer() }` at `:221`. Safe today but two copies of the same fragile pattern.

---

## Views & UX

### P1
- **Destructive deletes have no confirmation.** Folders (`FolderManagerView.swift:32-36`), categories (`CategoryManagerView.swift:42-48`), equipment (`EquipmentInventoryView.swift:45-47`), and issue reports (`IssueListView.swift:24-29`) all delete on swipe with no confirmation. Cascade rules can wipe linked checklists. Wrap in `.confirmationDialog` like `WorkflowDetailView.swift:71-85` already does.
- **Silent save failures.** `ChecklistEditorView.swift:36-39` calls `editable.save(...)` and immediately dismisses. If SwiftData throws, the user never knows. Same pattern in `IssueReportView.swift:123`.
- **No error feedback on export failure.** `ChecklistDetailView.swift:400-429` exports synchronously; only a generic alert if URL never gets set. PDF generation in `ExportService.exportPDF` (`:194-223`) returns `Data?` and swallows context-creation failures (no logging, no thrown error).
- **Empty states without CTA.** `EquipmentInventoryView` shows `ContentUnavailableView` but no "New Equipment" button (`:29-34`). Settings shows no CTA when zero API keys are saved (`:135-151`).
- **Detail pane is a dead end.** `ContentView.swift:276-280` shows only `ContentUnavailableView` in the detail column — no recently-opened, no "create your first" CTA.

### P2
- **`ShareStatusView` referenced but coordination unclear.** Used inline in `SettingsView.swift:156`; if it surfaces "Enable sharing" actions, there's no sheet/cover wiring between it and `CloudKitSharingService.CloudSharingSheet`.
- **Stacked presentation modifiers.** `ChecklistDetailView` carries 8 sheet/fullScreenCover modifiers (`:327-397`). Works today but a single mistake on two `isPresented` flags toggling together produces undefined behavior. Consider an enum-driven presentation route.
- **Accessibility gaps.** Completion checkmarks (`InlineStepRow.swift:79-91`), settings toggles (`SettingsView.swift:22-48`), and the "procedure complete" banner have no `.accessibilityLabel`/`.accessibilityHint`.
- **Step row duplication.** `InlineStepRow.swift` (319 lines) and `ExecutionStepRow.swift` (351 lines) implement the same timer / equipment / media / branch UI twice. Unify with a `DisplayMode` enum on a single row.

### P3
- **`@AppStorage` re-read every body eval** in `ChecklistExecutionView.swift:9-12`. Cheap, but worth a `@State` cache if profiling shows it.
- **`@Query` re-fetch noise.** `ChecklistDetailView.swift:6-7` and `ChecklistExecutionView.swift:7-8` both run `@Query` for all equipment/all checklists then filter per-step. Could be scoped.

---

## Services & Infrastructure

### P1
- **Keychain accessibility class unset.** `KeychainService.swift:31-36` omits `kSecAttrAccessible`. Default is `kSecAttrAccessibleWhenUnlocked` — fine for security but means API keys are unreadable while the device is locked (e.g., background sync). For aviation/field use, consider `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` explicitly.
- **`CloudKitSharingService` is a UI shim, not a sharing service.** `CloudSharingSheet` (`:45-106`) wraps `UICloudSharingController` and delegates record creation to a caller-supplied closure. There's no persistence of who's sharing what, no share-acceptance handling, no participant management — the file's name overpromises.
- **PDF export error path is dead.** `ExportService.exportPDF` returns `nil` silently on context failure (`:213-222`), and callers can't distinguish "empty checklist" from "PDF subsystem broken."

### P2
- **`CloudKitSharingService.checkAccountStatus` swallows the error** (`:33-39`); if the underlying `accountStatus()` throws inside a detached task, no signal reaches the user.

---

## Tests

### P1
- **No UI/integration tests.** The execution UI, timer auto-advance, branch selection from a tap, sheet/cover state — all untested. Add a small `@MainActor` XCTest target that drives `ChecklistExecutionView` through a scripted procedure.
- **No PDF export test.** `ExportServiceTests` cover Markdown (13) and HTML (8) thoroughly but skip PDF entirely.
- **No CloudKit / sharing tests.** Not unexpected (hard to mock) but the gap is worth flagging.

### P2
- **No negative-path tests** for execution: completing a step while a timer is mid-tick, attempting to complete a decision twice, ordering edge cases when `orderIndex` ties.
- **`EditableChecklistSaveTests` doesn't cover delete cascades** — adding a step then removing it then saving.

---

## Suggested Sprint Order

If picking up where this branch leaves off, the highest-leverage order is:

1. **P0 cluster: data integrity** — explicit `deleteRule`s on `folder`/`category`/`equipment` relationships, and decide on a single source of truth for equipment.
2. **P0/P1 execution semantics** — gate decision-step completion in the engine, decide whether `isCriticalFailure` should block.
3. **P1 destructive-action confirmations + silent-save error surfacing** — small, visible quality wins.
4. **P1 services** — set keychain accessibility class, surface PDF/CloudKit errors.
5. **P1 tests** — UI-level execution test + PDF export test.
6. **P2 refactors** — unify `InlineStepRow` and `ExecutionStepRow`; introduce a `Workflow` entity.
