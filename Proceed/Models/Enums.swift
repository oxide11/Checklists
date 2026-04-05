import Foundation

// MARK: - Checklist Category

enum ChecklistCategory: String, Codable, CaseIterable, Identifiable {
    case aviation
    case agriculture
    case vehicleMaintenance
    case homeRepair
    case firstAid
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aviation: "Aviation"
        case .agriculture: "Agriculture"
        case .vehicleMaintenance: "Vehicle Maintenance"
        case .homeRepair: "Home Repair"
        case .firstAid: "First Aid"
        case .custom: "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .aviation: "airplane"
        case .agriculture: "leaf.fill"
        case .vehicleMaintenance: "car.fill"
        case .homeRepair: "hammer.fill"
        case .firstAid: "cross.case.fill"
        case .custom: "folder.fill"
        }
    }
}

// MARK: - Step Type

enum StepType: String, Codable, CaseIterable {
    case action
    case decision
    case warning
    case caution
}

// MARK: - Media Type

enum MediaType: String, Codable, CaseIterable {
    case image
    case video
    case audio
    case model3D

    var displayName: String {
        switch self {
        case .image: "Photo"
        case .video: "Video"
        case .audio: "Audio"
        case .model3D: "3D Model"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .video: "video"
        case .audio: "waveform"
        case .model3D: "cube"
        }
    }
}

// MARK: - Branch Option (Decision step routes)

struct BranchOption: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var label: String
    var targetStepID: UUID?
}

// MARK: - LLM Provider

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case appleIntelligence
    case openAI
    case googleGemini
    case anthropicClaude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleIntelligence: "Apple Intelligence"
        case .openAI: "OpenAI"
        case .googleGemini: "Google Gemini"
        case .anthropicClaude: "Anthropic Claude"
        }
    }

    var requiresAPIKey: Bool {
        self != .appleIntelligence
    }

    var keychainKey: String {
        "llm_api_key_\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .appleIntelligence: "cpu"
        case .openAI: "globe"
        case .googleGemini: "sparkles"
        case .anthropicClaude: "brain"
        }
    }
}
