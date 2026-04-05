import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text("Proceed")
                        .font(.largeTitle.weight(.bold))
                    Text("Intelligent procedure execution for high-stakes environments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("Key Features") {
                featureRow(
                    icon: "list.bullet.clipboard",
                    title: "Interactive Procedures",
                    detail: "Step-by-step execution with check-off and progress tracking"
                )
                featureRow(
                    icon: "arrow.triangle.branch",
                    title: "Conditional Branching",
                    detail: "Decision points that dynamically route to the correct path"
                )
                featureRow(
                    icon: "brain",
                    title: "AI-Powered Ingestion",
                    detail: "Import manuals and auto-generate structured procedures"
                )
                featureRow(
                    icon: "square.grid.2x2",
                    title: "Multi-Domain",
                    detail: "Aviation, first aid, agriculture, vehicle maintenance, and more"
                )
                featureRow(
                    icon: "moon.fill",
                    title: "Night Vision Mode",
                    detail: "Red-on-black display to preserve dark-adapted vision"
                )
                featureRow(
                    icon: "icloud",
                    title: "CloudKit Sync",
                    detail: "Procedures sync across all your devices automatically"
                )
            }

            Section("Version") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
