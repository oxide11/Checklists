import SwiftUI
import SwiftData

struct TeamManagementView: View {
    let checklist: Checklist
    @Environment(\.modelContext) private var modelContext
    @State private var showAddMember = false
    @State private var newName = ""
    @State private var newRole: UserRole = .viewer

    private var roles: [ProcedureRole] {
        checklist.safeRoles.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        List {
            if roles.isEmpty {
                Section {
                    Text("No team members assigned. Add members to enable the approval workflow.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            Section("Team Members") {
                ForEach(roles) { member in
                    HStack(spacing: 12) {
                        Image(systemName: member.role.systemImage)
                            .foregroundStyle(member.role.color)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(.body.weight(.medium))
                            Text(member.userIdentifier.isEmpty ? "Local" : member.userIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Picker("Role", selection: Binding(
                            get: { member.role },
                            set: { newValue in member.role = newValue }
                        )) {
                            ForEach(UserRole.allCases) { userRole in
                                Text(userRole.displayName).tag(userRole)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                .onDelete { offsets in
                    // Snapshot the array before deleting to avoid index
                    // invalidation from the computed property re-evaluating.
                    let snapshot = roles
                    for i in offsets {
                        modelContext.delete(snapshot[i])
                    }
                }
            }

            Section {
                Button {
                    showAddMember = true
                } label: {
                    Label("Add Team Member", systemImage: "person.badge.plus")
                }
            }
        }
        .navigationTitle("Team")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Add Team Member", isPresented: $showAddMember) {
            TextField("Name", text: $newName)
            Picker("Role", selection: $newRole) {
                ForEach(UserRole.allCases) { role in
                    Text(role.displayName).tag(role)
                }
            }
            Button("Add") {
                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let role = ProcedureRole(
                    userIdentifier: ChangeLogEntry.deviceName,
                    displayName: newName.trimmingCharacters(in: .whitespaces),
                    role: newRole
                )
                role.checklist = checklist
                modelContext.insert(role)
                newName = ""
                newRole = .viewer
            }
            Button("Cancel", role: .cancel) {
                newName = ""
                newRole = .viewer
            }
        } message: {
            Text("Enter the team member's name and role.")
        }
    }


}
