import Foundation
import SwiftData

struct SampleDataGenerator {

    @MainActor
    static func populateIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Checklist>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        createEngineFire(context: context)
        createPreFlight(context: context)
        createAdultCPR(context: context)
        createOilChange(context: context)
        createCircuitBreaker(context: context)
        createPreSpray(context: context)
    }

    // MARK: - Aviation — Engine Fire During Takeoff (Emergency)

    private static func createEngineFire(context: ModelContext) {
        let cl = Checklist(title: "Engine Fire During Takeoff", category: .aviation, versionNumber: "v2.1", isEmergency: true)

        let s0 = ChecklistStep(stepType: .warning, text: "ENGINE FIRE detected during takeoff roll", orderIndex: 0)
        s0.requiresAcknowledgment = true

        let s1 = ChecklistStep(stepType: .action, text: "Reject takeoff — apply maximum braking", orderIndex: 1)
        let s2 = ChecklistStep(stepType: .action, text: "Thrust levers — IDLE", orderIndex: 2)
        let s3 = ChecklistStep(stepType: .action, text: "Engine fire extinguisher — ACTIVATE", orderIndex: 3)

        let s4 = ChecklistStep(stepType: .decision, text: "Fire warning light status", orderIndex: 4)
        s4.question = "Is the fire warning light extinguished?"

        let s5 = ChecklistStep(stepType: .action, text: "Taxi to nearest taxiway, contact ATC Ground", orderIndex: 5)
        s5.note = "Fire confirmed extinguished"

        let s6 = ChecklistStep(stepType: .warning, text: "EVACUATE — Initiate emergency evacuation immediately", orderIndex: 6)
        s6.requiresAcknowledgment = true
        s6.isCriticalFailure = true

        let steps = [s0, s1, s2, s3, s4, s5, s6]
        wireLinear(steps)
        s4.branchOptions = [
            BranchOption(label: "YES — Extinguished", targetStepID: s5.id),
            BranchOption(label: "NO — Still Illuminated", targetStepID: s6.id)
        ]
        insert(checklist: cl, steps: steps, context: context)
    }

    // MARK: - Aviation — Pre-Flight Walkaround

    private static func createPreFlight(context: ModelContext) {
        let cl = Checklist(title: "Pre-Flight Walkaround", category: .aviation, versionNumber: "v1.3")
        // Mark as outdated for demo — reviewed 14 months ago
        cl.lastReviewedDate = Calendar.current.date(byAdding: .month, value: -14, to: Date()) ?? Date()

        let steps = [
            ChecklistStep(stepType: .action, text: "Nose section — pitot cover removed, no visible damage", orderIndex: 0),
            ChecklistStep(stepType: .action, text: "Left wing — leading edge, flaps, ailerons intact", orderIndex: 1),
            ChecklistStep(stepType: .action, text: "Left fuel tank — visual quantity matches gauges", orderIndex: 2),
            ChecklistStep(stepType: .action, text: "Left main gear — tire pressure, brake lines, strut", orderIndex: 3),
            ChecklistStep(stepType: .action, text: "Empennage — elevator, rudder, trim tabs free and secure", orderIndex: 4),
            ChecklistStep(stepType: .action, text: "Right wing — mirror left wing inspection", orderIndex: 5),
            ChecklistStep(stepType: .action, text: "Right fuel tank — visual quantity matches gauges", orderIndex: 6),
            ChecklistStep(stepType: .action, text: "Engine cowling — oil level, fuel drain, exhaust", orderIndex: 7),
        ]
        wireLinear(steps)
        insert(checklist: cl, steps: steps, context: context)
    }

    // MARK: - First Aid — Adult CPR (Emergency)

    private static func createAdultCPR(context: ModelContext) {
        let cl = Checklist(title: "Adult CPR", category: .firstAid, versionNumber: "v3.0", isEmergency: true)

        let s0 = ChecklistStep(stepType: .warning, text: "Ensure scene is SAFE before approaching", orderIndex: 0)
        s0.requiresAcknowledgment = true

        let s1 = ChecklistStep(stepType: .action, text: "Check responsiveness — tap shoulders, shout 'Are you OK?'", orderIndex: 1)

        let s2 = ChecklistStep(stepType: .decision, text: "Responsiveness check", orderIndex: 2)
        s2.question = "Is the person responsive?"

        let s3 = ChecklistStep(stepType: .action, text: "Monitor and keep comfortable, call for help if needed", orderIndex: 3)
        s3.note = "Person is responsive — do not begin CPR"

        let s4 = ChecklistStep(stepType: .action, text: "Call 911 or direct a bystander to call", orderIndex: 4)

        let s5 = ChecklistStep(stepType: .action, text: "Open airway — head tilt, chin lift", orderIndex: 5)

        let s6 = ChecklistStep(stepType: .action, text: "Begin 30 chest compressions — 2 inches deep, 100-120 BPM", orderIndex: 6)
        s6.timerDuration = 18
        s6.note = "Push hard and fast in the center of the chest"

        let s7 = ChecklistStep(stepType: .action, text: "Give 2 rescue breaths — 1 second each", orderIndex: 7)
        let s8 = ChecklistStep(stepType: .action, text: "Continue 30:2 cycle until AED or EMS arrives", orderIndex: 8)

        let steps = [s0, s1, s2, s3, s4, s5, s6, s7, s8]
        wireLinear(steps)
        s2.branchOptions = [
            BranchOption(label: "YES — Responsive", targetStepID: s3.id),
            BranchOption(label: "NO — Unresponsive", targetStepID: s4.id)
        ]
        insert(checklist: cl, steps: steps, context: context)
    }

    // MARK: - Vehicle Maintenance — Oil Change

    private static func createOilChange(context: ModelContext) {
        let cl = Checklist(title: "Oil Change Procedure", category: .vehicleMaintenance, versionNumber: "v1.0")

        let s0 = ChecklistStep(stepType: .caution, text: "Allow engine to cool for at least 30 minutes", orderIndex: 0)
        s0.requiresAcknowledgment = true

        let steps: [ChecklistStep] = [
            s0,
            ChecklistStep(stepType: .action, text: "Gather supplies: new oil, filter, drain pan, wrench", orderIndex: 1),
            ChecklistStep(stepType: .action, text: "Position drain pan directly under oil drain plug", orderIndex: 2),
            ChecklistStep(stepType: .action, text: "Remove drain plug with wrench — oil will flow immediately", orderIndex: 3),
            {
                let s = ChecklistStep(stepType: .action, text: "Allow oil to drain completely", orderIndex: 4)
                s.timerDuration = 300
                s.note = "Wait for drip rate to slow to less than one drip per second"
                return s
            }(),
            ChecklistStep(stepType: .action, text: "Install new oil filter — hand-tighten only", orderIndex: 5),
            ChecklistStep(stepType: .action, text: "Replace drain plug, torque to manufacturer spec", orderIndex: 6),
            ChecklistStep(stepType: .action, text: "Add new oil through fill cap per owner's manual quantity", orderIndex: 7),
            ChecklistStep(stepType: .action, text: "Start engine, idle 1 minute, then check dipstick level", orderIndex: 8),
        ]
        wireLinear(steps)
        insert(checklist: cl, steps: steps, context: context)
    }

    // MARK: - Home Repair — Circuit Breaker Reset

    private static func createCircuitBreaker(context: ModelContext) {
        let cl = Checklist(title: "Circuit Breaker Reset", category: .homeRepair, versionNumber: "v1.0")

        let s0 = ChecklistStep(stepType: .warning, text: "NEVER touch the electrical panel with wet hands — risk of electrocution", orderIndex: 0)
        s0.requiresAcknowledgment = true

        let s1 = ChecklistStep(stepType: .action, text: "Open the breaker panel cover", orderIndex: 1)
        let s2 = ChecklistStep(stepType: .action, text: "Identify the tripped breaker — it will be in a middle or OFF position", orderIndex: 2)
        let s3 = ChecklistStep(stepType: .action, text: "Push the breaker firmly to the full OFF position", orderIndex: 3)
        let s4 = ChecklistStep(stepType: .action, text: "Flip the breaker to the ON position", orderIndex: 4)

        let s5 = ChecklistStep(stepType: .decision, text: "Breaker status after reset", orderIndex: 5)
        s5.question = "Does the breaker trip again immediately?"

        let s6 = ChecklistStep(stepType: .warning, text: "Do NOT reset again — call a licensed electrician (possible short circuit)", orderIndex: 6)
        s6.requiresAcknowledgment = true
        s6.isCriticalFailure = true

        let s7 = ChecklistStep(stepType: .action, text: "Verify affected outlets and lights are working, close panel", orderIndex: 7)

        let steps = [s0, s1, s2, s3, s4, s5, s6, s7]
        wireLinear(steps)
        s5.branchOptions = [
            BranchOption(label: "YES — Trips Again", targetStepID: s6.id),
            BranchOption(label: "NO — Holds", targetStepID: s7.id)
        ]
        insert(checklist: cl, steps: steps, context: context)
    }

    // MARK: - Agriculture — Pre-Spray Checklist

    private static func createPreSpray(context: ModelContext) {
        let cl = Checklist(title: "Crop Duster Pre-Spray", category: .agriculture, versionNumber: "v1.2")

        let s0 = ChecklistStep(stepType: .caution, text: "Wear full PPE before handling any chemical product", orderIndex: 0)
        s0.requiresAcknowledgment = true

        let steps: [ChecklistStep] = [
            s0,
            ChecklistStep(stepType: .action, text: "Verify wind speed below 10 mph per chemical label", orderIndex: 1),
            ChecklistStep(stepType: .action, text: "Confirm spray mixture ratio per agronomist recommendation", orderIndex: 2),
            ChecklistStep(stepType: .action, text: "Inspect boom nozzles for clogs or damage", orderIndex: 3),
            ChecklistStep(stepType: .action, text: "Calibrate spray rate — run test strip at operating speed", orderIndex: 4),
            ChecklistStep(stepType: .action, text: "Log operation: field ID, chemical, rate, weather conditions", orderIndex: 5),
        ]
        wireLinear(steps)
        insert(checklist: cl, steps: steps, context: context)
    }

    // MARK: - Helpers

    private static func wireLinear(_ steps: [ChecklistStep]) {
        for i in 0..<steps.count - 1 {
            steps[i].nextStepID = steps[i + 1].id
        }
    }

    private static func insert(checklist: Checklist, steps: [ChecklistStep], context: ModelContext) {
        context.insert(checklist)
        for step in steps {
            step.checklist = checklist
            context.insert(step)
        }
    }
}
