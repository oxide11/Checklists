import Testing
import Foundation
@testable import Proceed

// MARK: - Markdown Export

@Suite("ExportService Markdown")
@MainActor
struct ExportMarkdownTests {

    @Test("Title appears as H1")
    func titleAsH1() {
        let checklist = makeChecklist(title: "Engine Startup", steps: [makeActionStep()])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("# Engine Startup"))
    }

    @Test("Version is present")
    func versionPresent() {
        let checklist = makeChecklist(title: "Test", steps: [makeActionStep()])
        checklist.versionNumber = "v2.5"
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("v2.5"))
    }

    @Test("Emergency block included when isEmergency")
    func emergencyBlock() {
        let checklist = makeChecklist(title: "Test", steps: [makeActionStep()])
        checklist.isEmergency = true
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("EMERGENCY PROCEDURE"))
    }

    @Test("Emergency block absent when not emergency")
    func noEmergencyBlock() {
        let checklist = makeChecklist(title: "Test", steps: [makeActionStep()])
        checklist.isEmergency = false
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(!md.contains("EMERGENCY PROCEDURE"))
    }

    @Test("Warning step has WARNING prefix")
    func warningPrefix() {
        let step = makeWarningStep(text: "High voltage")
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("WARNING:"))
        #expect(md.contains("High voltage"))
    }

    @Test("Caution step has CAUTION prefix")
    func cautionPrefix() {
        let step = makeCautionStep(text: "Slippery surface")
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("CAUTION:"))
        #expect(md.contains("Slippery surface"))
    }

    @Test("Decision step has DECISION prefix")
    func decisionPrefix() {
        let step = makeDecisionStep(text: "Is pressure OK?", question: "Is pressure OK?")
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("DECISION:"))
        #expect(md.contains("Is pressure OK?"))
    }

    @Test("Action step has no prefix")
    func actionNoPrefix() {
        let step = makeActionStep(text: "Turn the valve")
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("1. Turn the valve"))
    }

    @Test("Timer formatting: minutes and seconds")
    func timerMinutesAndSeconds() {
        let step = makeActionStep(text: "Wait")
        step.timerDuration = 125  // 2m 5s
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("2m 5s"))
    }

    @Test("Timer formatting: seconds only")
    func timerSecondsOnly() {
        let step = makeActionStep(text: "Wait")
        step.timerDuration = 45
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("45s"))
        #expect(!md.contains("0m"))
    }

    @Test("Zero timer is omitted")
    func zeroTimerOmitted() {
        let step = makeActionStep(text: "Wait")
        step.timerDuration = 0
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(!md.contains("Timer"))
    }

    @Test("Nil timer is omitted")
    func nilTimerOmitted() {
        let step = makeActionStep(text: "Wait")
        step.timerDuration = nil
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(!md.contains("Timer"))
    }

    @Test("Step notes as blockquotes")
    func stepNotesBlockquote() {
        let step = makeActionStep(text: "Do thing")
        step.note = "Important detail"
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("> *Important detail*"))
    }

    @Test("Preparation notes included")
    func preparationNotes() {
        let checklist = makeChecklist(title: "Test", steps: [makeActionStep()])
        checklist.preparationNotes = "Gather tools first"
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("## Preparation"))
        #expect(md.contains("Gather tools first"))
    }

    @Test("Equipment listed as checkbox items")
    func equipmentCheckboxItems() {
        let checklist = makeChecklist(title: "Test", steps: [makeActionStep()])
        checklist.requiredEquipment = ["Wrench", "Hammer"]
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("- [ ] Wrench"))
        #expect(md.contains("- [ ] Hammer"))
    }

    @Test("Steps use 1-based numbering")
    func oneBasedNumbering() {
        let step1 = makeActionStep(text: "First")
        let step2 = makeActionStep(text: "Second")
        let step3 = makeActionStep(text: "Third")
        let checklist = makeChecklist(steps: [step1, step2, step3])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("1. First"))
        #expect(md.contains("2. Second"))
        #expect(md.contains("3. Third"))
    }

    @Test("Decision branch options listed")
    func decisionBranchOptions() {
        let step = makeDecisionStep(
            text: "Choose",
            question: "Choose path",
            branchOptions: [
                BranchOption(label: "Left"),
                BranchOption(label: "Right")
            ]
        )
        let checklist = makeChecklist(steps: [step])
        let md = ExportService.exportMarkdown(checklist: checklist)
        #expect(md.contains("→ Left"))
        #expect(md.contains("→ Right"))
    }
}

// MARK: - HTML Export

@Suite("ExportService HTML")
@MainActor
struct ExportHTMLTests {

    @Test("Contains DOCTYPE and title tag")
    func doctypeAndTitle() {
        let checklist = makeChecklist(title: "My Proc", steps: [makeActionStep()])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<title>My Proc</title>"))
    }

    @Test("HTML escapes special characters in title")
    func htmlEscapesTitle() {
        let checklist = makeChecklist(title: "A<B>C&D\"E", steps: [makeActionStep()])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("A&lt;B&gt;C&amp;D&quot;E"))
    }

    @Test("Emergency div present when isEmergency")
    func emergencyDiv() {
        let checklist = makeChecklist(title: "Test", steps: [makeActionStep()])
        checklist.isEmergency = true
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("class=\"emergency\""))
        #expect(html.contains("EMERGENCY PROCEDURE"))
    }

    @Test("Warning step has warning CSS class")
    func warningCSSClass() {
        let step = makeWarningStep(text: "Danger")
        let checklist = makeChecklist(steps: [step])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("class=\"step warning\""))
    }

    @Test("Caution step has caution CSS class")
    func cautionCSSClass() {
        let step = makeCautionStep(text: "Careful")
        let checklist = makeChecklist(steps: [step])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("class=\"step caution\""))
    }

    @Test("Decision step has decision CSS class")
    func decisionCSSClass() {
        let step = makeDecisionStep(text: "Choose")
        let checklist = makeChecklist(steps: [step])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("class=\"step decision\""))
    }

    @Test("Timer rendered in HTML")
    func timerRendered() {
        let step = makeActionStep(text: "Wait")
        step.timerDuration = 90  // 1m 30s
        let checklist = makeChecklist(steps: [step])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("1m 30s"))
    }

    @Test("Step note rendered with step-note class")
    func stepNoteRendered() {
        let step = makeActionStep(text: "Do thing")
        step.note = "See manual"
        let checklist = makeChecklist(steps: [step])
        let html = ExportService.exportHTML(checklist: checklist)
        #expect(html.contains("class=\"step-note\""))
        #expect(html.contains("See manual"))
    }
}
