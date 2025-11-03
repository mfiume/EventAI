import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = AIConfiguration.load()
    @State private var apiKey = ""
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    @State private var showAPIKey = false

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationView {
            Form {
                // AI Provider Section
                Section {
                    Picker("AI Provider", selection: $configuration.provider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: configuration.provider) { _ in
                        // Update model to default when provider changes
                        configuration.model = configuration.provider.defaultModel
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose which AI service to use for event extraction.")
                        Link("Get API Key", destination: URL(string: configuration.provider.signupURL)!)
                            .font(.footnote)
                    }
                }

                // API Key Section
                Section {
                    HStack {
                        if showAPIKey {
                            TextField("API Key", text: $apiKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        Button(action: { showAPIKey.toggle() }) {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(apiKey.isEmpty || isTestingConnection)

                    if let result = testResult {
                        switch result {
                        case .success:
                            Label("Connection successful", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain and never leaves your device.")
                }

                // Model Selection
                Section {
                    Picker("Model", selection: $configuration.model) {
                        ForEach(configuration.provider.availableModels) { model in
                            HStack {
                                Text(model.displayName)
                                if model.isDefault {
                                    Text("(Recommended)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(model.id)
                        }
                    }
                } header: {
                    Text("Model")
                } footer: {
                    Text("Choose which AI model to use. Recommended models offer the best balance of speed and quality.")
                }

                // Advanced Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", configuration.temperature))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $configuration.temperature, in: 0.0...1.0, step: 0.1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Tokens")
                            Spacer()
                            Text("\(configuration.maxTokens)")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(configuration.maxTokens) },
                            set: { configuration.maxTokens = Int($0) }
                        ), in: 500...4000, step: 100)
                    }
                } header: {
                    Text("Advanced Settings")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature controls response randomness (0 = deterministic, 1 = creative).")
                        Text("Max Tokens limits the length of AI responses.")
                    }
                }

                // Privacy Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("No Backend Server", systemImage: "checkmark.circle")
                        Label("No Usage Tracking", systemImage: "checkmark.circle")
                        Label("API Keys Stored Locally", systemImage: "checkmark.circle")
                        Label("Direct AI Calls", systemImage: "checkmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("EventAI 2.0 has no backend. All processing happens on your device and directly with your chosen AI provider.")
                }

                // Clear Data
                Section {
                    Button(role: .destructive, action: clearAllData) {
                        Label("Clear All Settings", systemImage: "trash")
                    }
                } footer: {
                    Text("This will remove your API key and reset all settings to defaults.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .onAppear {
                loadAPIKey()
            }
        }
    }

    // MARK: - Actions
    private func loadAPIKey() {
        if let key = try? KeychainService.loadAPIKey() {
            apiKey = key
        }
    }

    private func saveSettings() {
        // Save API key to Keychain
        if !apiKey.isEmpty {
            try? KeychainService.saveAPIKey(apiKey)
        }

        // Save configuration to UserDefaults
        configuration.save()

        dismiss()
    }

    private func testConnection() {
        guard !apiKey.isEmpty else { return }

        isTestingConnection = true
        testResult = nil

        Task {
            do {
                let service = AIServiceFactory.createService(configuration: configuration, apiKey: apiKey)
                let success = try await service.testConnection()

                await MainActor.run {
                    if success {
                        testResult = .success
                    } else {
                        testResult = .failure("Connection failed")
                    }
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }

    private func clearAllData() {
        // Clear API key
        try? KeychainService.deleteAPIKey()

        // Clear configuration
        AIConfiguration.clear()

        // Reset state
        configuration = AIConfiguration()
        apiKey = ""
        testResult = nil

        dismiss()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
