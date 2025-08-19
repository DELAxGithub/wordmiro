import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var llmService = LLMService.shared
    @State private var settings: LLMSettings
    @State private var showingAPIKeyField = false
    
    init() {
        _settings = State(initialValue: LLMService.shared.settings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("LLM Provider") {
                    Picker("Provider", selection: $settings.provider) {
                        ForEach(LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("API Configuration") {
                    HStack {
                        Text("API Key")
                        Spacer()
                        if settings.apiKey.isEmpty {
                            Text("Not Set")
                                .foregroundColor(.red)
                                .font(.caption)
                        } else {
                            Text("••••••••")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingAPIKeyField = true
                    }
                    
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", settings.temperature))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.temperature, in: 0.0...1.0, step: 0.1) {
                        Text("Temperature")
                    } minimumValueLabel: {
                        Text("0.0")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("1.0")
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text("\(settings.maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settings.maxTokens) },
                        set: { settings.maxTokens = Int($0) }
                    ), in: 500...2000, step: 100) {
                        Text("Max Tokens")
                    } minimumValueLabel: {
                        Text("500")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("2000")
                            .font(.caption)
                    }
                }
                
                Section("Provider Information") {
                    LabeledContent("Model", value: settings.provider.model)
                    LabeledContent("Base URL", value: settings.provider.baseURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Status") {
                    HStack {
                        Text("Configuration")
                        Spacer()
                        if settings.isValid {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Incomplete", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
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
                    .disabled(!hasChanges)
                }
            }
            .sheet(isPresented: $showingAPIKeyField) {
                APIKeyInputView(
                    provider: settings.provider,
                    apiKey: $settings.apiKey
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                settings = llmService.settings
            }
        }
    }
    
    private var hasChanges: Bool {
        return settings.provider != llmService.settings.provider ||
               settings.apiKey != llmService.settings.apiKey ||
               abs(settings.temperature - llmService.settings.temperature) > 0.01 ||
               settings.maxTokens != llmService.settings.maxTokens
    }
    
    private func saveSettings() {
        llmService.updateSettings(settings)
        dismiss()
    }
}

struct APIKeyInputView: View {
    let provider: LLMProvider
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var tempKey = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    
                    Text("\(provider.displayName) API Key")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your API key to enable LLM functionality")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.headline)
                    
                    SecureField("Enter your \(provider.displayName) API key", text: $tempKey)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .onAppear {
                            tempKey = apiKey
                            isTextFieldFocused = true
                        }
                    
                    Text("Your API key is stored securely in the device keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Save") {
                        apiKey = tempKey
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tempKey.isEmpty)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}