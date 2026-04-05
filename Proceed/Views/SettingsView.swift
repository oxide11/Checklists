import SwiftUI

struct SettingsView: View {
    @AppStorage("nightVisionEnabled") private var nightVisionEnabled = false
    @AppStorage("highlightCurrentStep") private var highlightCurrentStep = true
    @AppStorage("autoStartTimers") private var autoStartTimers = true
    @AppStorage("autoAdvanceOnTimerEnd") private var autoAdvanceOnTimerEnd = false
    @AppStorage("progressiveDisclosure") private var progressiveDisclosure = true
    @State private var selectedProvider: LLMProvider = .appleIntelligence
    @State private var apiKeyInput: String = ""
    @State private var savedProviders: Set<LLMProvider> = []
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let keychain = KeychainService.shared

    var body: some View {
        Form {
            // MARK: Display

            Section {
                Toggle(isOn: $nightVisionEnabled) {
                    Label("Night Vision Mode", systemImage: "moon.fill")
                }

                Toggle(isOn: $highlightCurrentStep) {
                    Label("Highlight Current Step", systemImage: "target")
                }
            } header: {
                Text("Display")
            } footer: {
                Text("Night Vision provides a red-on-black display for low-light environments. Highlight Current Step adds a visual background to the active step during execution.")
            }

            // MARK: Execution

            Section {
                Toggle(isOn: $autoStartTimers) {
                    Label("Auto-Start Timers", systemImage: "timer")
                }

                Toggle(isOn: $autoAdvanceOnTimerEnd) {
                    Label("Auto-Advance After Timer", systemImage: "forward.fill")
                }

                Toggle(isOn: $progressiveDisclosure) {
                    Label("Progressive Disclosure", systemImage: "eye.slash")
                }
            } header: {
                Text("Execution")
            } footer: {
                Text("Auto-Start begins timers when a timed step becomes current. Auto-Advance moves to the next step when a timer completes. Progressive Disclosure shows only the title for upcoming steps.")
            }

            // MARK: Organization

            Section {
                NavigationLink {
                    CategoryManagerView()
                } label: {
                    Label("Categories", systemImage: "square.grid.2x2")
                }

                NavigationLink {
                    FolderManagerView()
                } label: {
                    Label("Folders", systemImage: "folder")
                }
            } header: {
                Text("Organization")
            }

            // MARK: Provider Selection

            Section {
                Picker("AI Provider", selection: $selectedProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Label(provider.displayName, systemImage: provider.systemImage)
                            .tag(provider)
                    }
                }
                .onChange(of: selectedProvider) { _, _ in
                    apiKeyInput = ""
                }
            } header: {
                Text("AI Engine")
            } footer: {
                Text("Select the AI provider used to parse manuals into procedures.")
            }

            // MARK: API Key Input

            if selectedProvider.requiresAPIKey {
                Section {
                    SecureField("API Key", text: $apiKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    Button("Save to Keychain") {
                        saveAPIKey()
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    if savedProviders.contains(selectedProvider) {
                        HStack {
                            Label("Key stored securely", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)

                            Spacer()

                            Button("Remove", role: .destructive) {
                                removeAPIKey()
                            }
                            .font(.subheadline)
                        }
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Your key is stored in the iOS Keychain and never leaves this device except for direct API calls to the selected provider.")
                }
            } else {
                Section {
                    Label("Runs entirely on-device. No API key required.", systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } header: {
                    Text("Configuration")
                }
            }

            // MARK: Saved Keys Overview

            Section {
                ForEach(LLMProvider.allCases.filter(\.requiresAPIKey)) { provider in
                    HStack {
                        Label(provider.displayName, systemImage: provider.systemImage)
                        Spacer()
                        if savedProviders.contains(provider) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle.dashed")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Key Status")
            }

            // MARK: About

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    HStack {
                        Text("About Proceed")
                        Spacer()
                        Text("v1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .onAppear { refreshSavedProviders() }
        .alert("API Key", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            try keychain.save(key: selectedProvider.keychainKey, value: trimmed)
            savedProviders.insert(selectedProvider)
            apiKeyInput = ""
            alertMessage = "\(selectedProvider.displayName) key saved securely."
            showAlert = true
        } catch {
            alertMessage = "Failed to save key: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func removeAPIKey() {
        keychain.delete(key: selectedProvider.keychainKey)
        savedProviders.remove(selectedProvider)
    }

    private func refreshSavedProviders() {
        savedProviders = Set(
            LLMProvider.allCases.filter { $0.requiresAPIKey && keychain.hasValue(for: $0.keychainKey) }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
