import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@Model
final class ChangeLogEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var authorName: String = ""
    var changeType: String = ChangeType.edited.rawValue
    var summary: String = ""
    var previousVersionNumber: String? = nil
    var newVersionNumber: String? = nil
    var fieldChangesData: Data? = nil

    var checklist: Checklist? = nil

    /// Typed access to the change type
    var change: ChangeType {
        get { ChangeType(rawValue: changeType) ?? .edited }
        set { changeType = newValue.rawValue }
    }

    /// Decoded field changes from JSON
    var fieldChanges: [FieldChange] {
        get {
            guard let data = fieldChangesData else { return [] }
            return (try? JSONDecoder().decode([FieldChange].self, from: data)) ?? []
        }
        set {
            fieldChangesData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        changeType: ChangeType = .edited,
        summary: String = "",
        previousVersionNumber: String? = nil,
        newVersionNumber: String? = nil,
        authorName: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.changeType = changeType.rawValue
        self.summary = summary
        self.previousVersionNumber = previousVersionNumber
        self.newVersionNumber = newVersionNumber
        self.authorName = authorName.isEmpty ? Self.deviceName : authorName
    }

    static var deviceName: String {
        #if os(iOS) || os(tvOS)
        UIDevice.current.name
        #elseif os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        "Unknown Device"
        #endif
    }
}

// MARK: - Field Change

struct FieldChange: Codable, Identifiable {
    var id: UUID = UUID()
    var fieldName: String
    var oldValue: String
    var newValue: String
}
