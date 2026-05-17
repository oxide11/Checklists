import Testing
import Foundation
@testable import Proceed

// MARK: - Checklist.isOutdated

@Suite("Checklist.isOutdated")
@MainActor
struct ChecklistIsOutdatedTests {

    @Test("13 months old is outdated")
    func thirteenMonthsIsOutdated() {
        let checklist = Checklist(title: "Old")
        let thirteenMonthsAgo = Calendar.current.date(byAdding: .month, value: -13, to: Date())!
        checklist.lastReviewedDate = thirteenMonthsAgo
        checklist.lastUpdatedDate = thirteenMonthsAgo
        #expect(checklist.isOutdated == true)
    }

    @Test("11 months old is not outdated")
    func elevenMonthsNotOutdated() {
        let checklist = Checklist(title: "Recent")
        let elevenMonthsAgo = Calendar.current.date(byAdding: .month, value: -11, to: Date())!
        checklist.lastReviewedDate = elevenMonthsAgo
        checklist.lastUpdatedDate = elevenMonthsAgo
        #expect(checklist.isOutdated == false)
    }

    @Test("Today is not outdated")
    func todayNotOutdated() {
        let checklist = Checklist(title: "Fresh")
        // Default dates are Date() = today
        #expect(checklist.isOutdated == false)
    }

    @Test("Updated recently but reviewed long ago is outdated")
    func reviewedLongAgo() {
        let checklist = Checklist(title: "Split")
        checklist.lastUpdatedDate = Date()
        checklist.lastReviewedDate = Calendar.current.date(byAdding: .month, value: -13, to: Date())!
        #expect(checklist.isOutdated == true)
    }
}

// MARK: - Checklist.hasPreparation

@Suite("Checklist.hasPreparation")
@MainActor
struct ChecklistHasPreparationTests {

    @Test("No notes and no equipment returns false")
    func noPreparation() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = nil
        checklist.requiredEquipmentData = nil
        checklist.requiredEquipmentItems = []
        #expect(checklist.hasPreparation == false)
    }

    @Test("Empty notes and no equipment returns false")
    func emptyNotes() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = ""
        checklist.requiredEquipmentData = nil
        checklist.requiredEquipmentItems = []
        #expect(checklist.hasPreparation == false)
    }

    @Test("Notes set returns true")
    func notesSet() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = "Wear PPE"
        #expect(checklist.hasPreparation == true)
    }

    @Test("Equipment list set returns true")
    func equipmentSet() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = nil
        checklist.requiredEquipment = ["Wrench"]
        #expect(checklist.hasPreparation == true)
    }

    @Test("Equipment items relationship set returns true")
    func equipmentItemsSet() {
        let checklist = Checklist(title: "Test")
        checklist.preparationNotes = nil
        checklist.requiredEquipmentData = nil
        checklist.requiredEquipmentItems = [Equipment(name: "Hammer")]
        #expect(checklist.hasPreparation == true)
    }
}

// MARK: - Checklist.status

@Suite("Checklist.status")
@MainActor
struct ChecklistStatusTests {

    @Test("Default status is published")
    func defaultStatus() {
        let checklist = Checklist(title: "Test")
        #expect(checklist.status == .published)
    }

    @Test("All ProcedureStatus cases can be assigned and read back")
    func allCasesRoundTrip() {
        let checklist = Checklist(title: "Test")
        for status in ProcedureStatus.allCases {
            checklist.status = status
            #expect(checklist.status == status)
        }
    }
}

// MARK: - Checklist.orderedSteps

@Suite("Checklist.orderedSteps")
@MainActor
struct ChecklistOrderedStepsTests {

    @Test("Steps sorted by orderIndex")
    func sortedByOrderIndex() {
        let checklist = Checklist(title: "Test")
        let step1 = ChecklistStep(stepType: .action, text: "First", orderIndex: 0)
        let step2 = ChecklistStep(stepType: .action, text: "Second", orderIndex: 1)
        let step3 = ChecklistStep(stepType: .action, text: "Third", orderIndex: 2)
        // Insert in reverse order
        checklist.steps = [step3, step1, step2]
        let ordered = checklist.orderedSteps
        #expect(ordered[0].text == "First")
        #expect(ordered[1].text == "Second")
        #expect(ordered[2].text == "Third")
    }

    @Test("Nil steps returns empty")
    func nilStepsReturnsEmpty() {
        let checklist = Checklist(title: "Test")
        checklist.steps = nil
        #expect(checklist.orderedSteps.isEmpty)
    }
}

// MARK: - ProcedureRole.userRole

@Suite("ProcedureRole.userRole")
@MainActor
struct ProcedureRoleUserRoleTests {

    @Test("Valid role strings map correctly")
    func validMapping() {
        let role = ProcedureRole(userIdentifier: "user1", displayName: "Alice", role: .editor)
        #expect(role.userRole == .editor)
    }

    @Test("Invalid raw value falls back to viewer")
    func invalidFallback() {
        let role = ProcedureRole()
        role.role = "superadmin"
        #expect(role.userRole == .viewer)
    }

    @Test("Setting userRole updates raw string")
    func setUpdatesRaw() {
        let role = ProcedureRole()
        role.userRole = .approver
        #expect(role.role == "approver")
    }
}

// MARK: - ChangeLogEntry.authorName

@Suite("ChangeLogEntry.authorName")
@MainActor
struct ChangeLogEntryAuthorTests {

    @Test("Explicit name is preserved")
    func explicitName() {
        let entry = ChangeLogEntry(changeType: .created, summary: "Test", authorName: "Alice")
        #expect(entry.authorName == "Alice")
    }

    @Test("Empty name falls back to device name")
    func emptyNameFallback() {
        let entry = ChangeLogEntry(changeType: .created, summary: "Test", authorName: "")
        #expect(!entry.authorName.isEmpty)
        #expect(entry.authorName == ChangeLogEntry.deviceName)
    }
}
