import Testing
import Foundation
@testable import Proceed

// MARK: - StepType Tests

@Suite("StepType")
struct StepTypeTests {

    @Test("Raw values are stable")
    func rawValues() {
        #expect(StepType.action.rawValue == "action")
        #expect(StepType.decision.rawValue == "decision")
        #expect(StepType.warning.rawValue == "warning")
        #expect(StepType.caution.rawValue == "caution")
    }

    @Test("systemImage is non-empty for all cases")
    func systemImages() {
        for type in StepType.allCases {
            #expect(!type.systemImage.isEmpty)
        }
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        for type in StepType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(StepType.self, from: data)
            #expect(decoded == type)
        }
    }

    @Test("CaseIterable contains exactly 4 cases")
    func allCasesCount() {
        #expect(StepType.allCases.count == 4)
    }
}

// MARK: - MediaType Tests

@Suite("MediaType")
struct MediaTypeTests {

    @Test("Raw values are stable")
    func rawValues() {
        #expect(MediaType.image.rawValue == "image")
        #expect(MediaType.video.rawValue == "video")
        #expect(MediaType.audio.rawValue == "audio")
        #expect(MediaType.model3D.rawValue == "model3D")
    }

    @Test("displayName is human-readable")
    func displayNames() {
        #expect(MediaType.image.displayName == "Photo")
        #expect(MediaType.video.displayName == "Video")
        #expect(MediaType.audio.displayName == "Audio")
        #expect(MediaType.model3D.displayName == "3D Model")
    }

    @Test("systemImage is non-empty for all cases")
    func systemImages() {
        for type in MediaType.allCases {
            #expect(!type.systemImage.isEmpty)
        }
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        for type in MediaType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(MediaType.self, from: data)
            #expect(decoded == type)
        }
    }
}

// MARK: - UserRole Tests

@Suite("UserRole")
struct UserRoleTests {

    @Test("id equals rawValue")
    func idEqualsRawValue() {
        for role in UserRole.allCases {
            #expect(role.id == role.rawValue)
        }
    }

    @Test("displayName is human-readable")
    func displayNames() {
        #expect(UserRole.viewer.displayName == "Viewer")
        #expect(UserRole.editor.displayName == "Editor")
        #expect(UserRole.approver.displayName == "Approver")
    }

    @Test("systemImage is non-empty for all cases")
    func systemImages() {
        for role in UserRole.allCases {
            #expect(!role.systemImage.isEmpty)
        }
    }

    @Test("CaseIterable contains exactly 3 cases")
    func allCasesCount() {
        #expect(UserRole.allCases.count == 3)
    }
}

// MARK: - ProcedureStatus Tests

@Suite("ProcedureStatus")
struct ProcedureStatusTests {

    @Test("Raw values are stable")
    func rawValues() {
        #expect(ProcedureStatus.draft.rawValue == "draft")
        #expect(ProcedureStatus.pendingReview.rawValue == "pendingReview")
        #expect(ProcedureStatus.approved.rawValue == "approved")
        #expect(ProcedureStatus.rejected.rawValue == "rejected")
        #expect(ProcedureStatus.published.rawValue == "published")
    }

    @Test("displayName is human-readable")
    func displayNames() {
        #expect(ProcedureStatus.draft.displayName == "Draft")
        #expect(ProcedureStatus.pendingReview.displayName == "Pending Review")
        #expect(ProcedureStatus.approved.displayName == "Approved")
        #expect(ProcedureStatus.rejected.displayName == "Rejected")
        #expect(ProcedureStatus.published.displayName == "Published")
    }

    @Test("systemImage is non-empty for all cases")
    func systemImages() {
        for status in ProcedureStatus.allCases {
            #expect(!status.systemImage.isEmpty)
        }
    }

    @Test("CaseIterable contains exactly 5 cases")
    func allCasesCount() {
        #expect(ProcedureStatus.allCases.count == 5)
    }
}

// MARK: - LLMProvider Tests

@Suite("LLMProvider")
struct LLMProviderTests {

    @Test("Only appleIntelligence does not require API key")
    func requiresAPIKey() {
        #expect(LLMProvider.appleIntelligence.requiresAPIKey == false)
        #expect(LLMProvider.openAI.requiresAPIKey == true)
        #expect(LLMProvider.googleGemini.requiresAPIKey == true)
        #expect(LLMProvider.anthropicClaude.requiresAPIKey == true)
    }

    @Test("keychainKey includes raw value")
    func keychainKeyFormat() {
        for provider in LLMProvider.allCases {
            #expect(provider.keychainKey == "llm_api_key_\(provider.rawValue)")
        }
    }

    @Test("displayName is human-readable")
    func displayNames() {
        #expect(LLMProvider.appleIntelligence.displayName == "Apple Intelligence")
        #expect(LLMProvider.openAI.displayName == "OpenAI")
        #expect(LLMProvider.googleGemini.displayName == "Google Gemini")
        #expect(LLMProvider.anthropicClaude.displayName == "Anthropic Claude")
    }

    @Test("systemImage is non-empty for all cases")
    func systemImages() {
        for provider in LLMProvider.allCases {
            #expect(!provider.systemImage.isEmpty)
        }
    }

    @Test("id equals rawValue")
    func idEqualsRawValue() {
        for provider in LLMProvider.allCases {
            #expect(provider.id == provider.rawValue)
        }
    }
}

// MARK: - BranchOption Tests

@Suite("BranchOption")
@MainActor
struct BranchOptionTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let targetID = UUID()
        let option = BranchOption(label: "Go left", targetStepID: targetID)
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(BranchOption.self, from: data)
        #expect(decoded.id == option.id)
        #expect(decoded.label == "Go left")
        #expect(decoded.targetStepID == targetID)
    }

    @Test("Codable round-trip with nil targetStepID")
    func codableWithNilTarget() throws {
        let option = BranchOption(label: "Unlinked", targetStepID: nil)
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(BranchOption.self, from: data)
        #expect(decoded.label == "Unlinked")
        #expect(decoded.targetStepID == nil)
    }
}

// MARK: - FieldChange Tests

@Suite("FieldChange")
@MainActor
struct FieldChangeTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let fc = FieldChange(fieldName: "Title", oldValue: "Old", newValue: "New")
        let data = try JSONEncoder().encode(fc)
        let decoded = try JSONDecoder().decode(FieldChange.self, from: data)
        #expect(decoded.id == fc.id)
        #expect(decoded.fieldName == "Title")
        #expect(decoded.oldValue == "Old")
        #expect(decoded.newValue == "New")
    }
}
