import SwiftUI
import CloudKit
import SwiftData
import CoreData

enum CloudSharingError: LocalizedError {
    case noPreparation
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .noPreparation:
            return "Unable to share: sharing has not been configured for this procedure."
        case .iCloudUnavailable:
            return "Sign in to iCloud in Settings to share procedures with your team."
        }
    }
}

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

// MARK: - CloudKit Sharing View Controller Wrapper

#if canImport(UIKit)
struct CloudSharingSheet: UIViewControllerRepresentable {
    let container: CKContainer
    let share: CKShare?
    let preparation: (@Sendable () async throws -> CKShare)?

    init(container: CKContainer = .default(), share: CKShare? = nil, preparation: (@Sendable () async throws -> CKShare)? = nil) {
        self.container = container
        self.share = share
        self.preparation = preparation
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller: UICloudSharingController

        if let share {
            controller = UICloudSharingController(share: share, container: container)
        } else {
            controller = UICloudSharingController { _, prepareHandler in
                Task {
                    do {
                        guard let prep = self.preparation else {
                            prepareHandler(nil, nil, CloudSharingError.noPreparation)
                            return
                        }
                        let newShare = try await prep()
                        prepareHandler(newShare, self.container, nil)
                    } catch {
                        prepareHandler(nil, nil, error)
                    }
                }
            }
        }

        controller.availablePermissions = [.allowPublic, .allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // Sharing failed — the user will see the CloudKit error
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Procedure"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            // Share saved successfully
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            // User stopped sharing
        }
    }
}
#endif

// MARK: - Share Status View

struct ShareStatusView: View {
    @State private var accountAvailable = false
    @State private var checked = false

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

                Text("Sign in to iCloud in Settings to enable sync and sharing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .task {
            accountAvailable = await CloudKitSharingService.shared.checkAccountStatus()
            checked = true
        }
    }
}
