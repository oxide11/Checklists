import SwiftUI
import CloudKit

/// Wraps CloudKit sharing for SwiftData procedures.
/// Requires the SwiftData ModelContainer to use `cloudKitDatabase: .automatic`.
@Observable
final class CloudKitSharingService {
    static let shared = CloudKitSharingService()

    var isSharing = false
    var errorMessage: String? = nil

    private init() {}

    /// Checks if CloudKit is available for the current user.
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await CKContainer.default().accountStatus()
            return status == .available
        } catch {
            errorMessage = "iCloud not available: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Share Status View

struct ShareStatusView: View {
    @State private var accountAvailable = false
    @State private var checked = false
    private let service = CloudKitSharingService.shared

    var body: some View {
        VStack(spacing: 12) {
            if !checked {
                ProgressView("Checking iCloud...")
            } else if accountAvailable {
                Label("iCloud Connected", systemImage: "checkmark.icloud.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.medium))

                Text("Procedures sync automatically across your devices via iCloud. Use the Share button on a procedure to collaborate with team members.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Label("iCloud Not Available", systemImage: "xmark.icloud.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.medium))

                Text(service.errorMessage ?? "Sign in to iCloud in Settings to enable sync and sharing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .task {
            accountAvailable = await service.checkAccountStatus()
            checked = true
        }
    }
}
