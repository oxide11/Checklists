import Foundation

// MARK: - Step Type

enum StepType: String, Codable, CaseIterable {
    case action
    case decision
    case warning
    case caution

    var systemImage: String {
        switch self {
        case .action: "circle"
        case .decision: "arrow.triangle.branch"
        case .warning: "exclamationmark.triangle.fill"
        case .caution: "exclamationmark.circle.fill"
        }
    }
}

import SwiftUI

extension StepType {
    var color: Color {
        switch self {
        case .action: .primary
        case .decision: .cyan
        case .warning: .red
        case .caution: .orange
        }
    }

    var font: Font {
        switch self {
        case .warning: .body.weight(.bold)
        case .caution: .body.weight(.semibold)
        case .action, .decision: .body
        }
    }
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

// MARK: - User Role

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case viewer
    case editor
    case approver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .viewer: "Viewer"
        case .editor: "Editor"
        case .approver: "Approver"
        }
    }

    var systemImage: String {
        switch self {
        case .viewer: "eye"
        case .editor: "pencil"
        case .approver: "checkmark.seal"
        }
    }

    var color: Color {
        switch self {
        case .viewer: .blue
        case .editor: .orange
        case .approver: .green
        }
    }
}

// MARK: - Procedure Status

enum ProcedureStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case pendingReview
    case approved
    case rejected
    case published

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .pendingReview: "Pending Review"
        case .approved: "Approved"
        case .rejected: "Rejected"
        case .published: "Published"
        }
    }

    var color: Color {
        switch self {
        case .draft: .secondary
        case .pendingReview: .orange
        case .approved: .green
        case .rejected: .red
        case .published: .blue
        }
    }

    var systemImage: String {
        switch self {
        case .draft: "doc"
        case .pendingReview: "clock"
        case .approved: "checkmark.seal.fill"
        case .rejected: "xmark.seal.fill"
        case .published: "globe"
        }
    }
}

// MARK: - Issue Status

enum IssueStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case acknowledged
    case resolved

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .open: .red
        case .acknowledged: .orange
        case .resolved: .green
        }
    }
}

// MARK: - Issue Severity

enum IssueSeverity: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .low: "minus.circle"
        case .medium: "exclamationmark.circle"
        case .high: "exclamationmark.triangle"
        case .critical: "bolt.circle.fill"
        }
    }

    var filledSystemImage: String {
        switch self {
        case .low: "minus.circle.fill"
        case .medium: "exclamationmark.circle.fill"
        case .high: "exclamationmark.triangle.fill"
        case .critical: "bolt.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .low: .green
        case .medium: .yellow
        case .high: .orange
        case .critical: .red
        }
    }
}

// MARK: - Change Type

enum ChangeType: String, Codable, CaseIterable, Identifiable {
    case created
    case edited
    case approved
    case rejected
    case published
    case submitted

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .created: "plus.circle.fill"
        case .edited: "pencil.circle.fill"
        case .approved: "checkmark.seal.fill"
        case .rejected: "xmark.circle.fill"
        case .published: "paperplane.circle.fill"
        case .submitted: "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .created: .green
        case .edited: .blue
        case .approved: .green
        case .rejected: .red
        case .published: .purple
        case .submitted: .orange
        }
    }
}

// MARK: - Duration Formatting

extension Double {
    /// Formats a duration in seconds as "Xm Ys" or "Ys"
    var formattedDuration: String {
        let mins = Int(self) / 60
        let secs = Int(self) % 60
        if mins > 0 {
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        }
        return "\(secs)s"
    }
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
