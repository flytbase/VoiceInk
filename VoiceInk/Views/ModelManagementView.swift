import SwiftData
import SwiftUI

struct ModelManagementView: View {
    @ObservedObject var whisperState: WhisperState
    @State private var modelToDelete: WhisperModel?
    @StateObject private var aiService = AIService()
    @StateObject private var transcriptionPromptService = TranscriptionPromptService()
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var whisperPrompt = WhisperPrompt()
    @State private var transcriptionMode: TranscriptionMode =
        TranscriptionMode(
            rawValue: UserDefaults.standard.string(forKey: "TranscriptionMode") ?? "local")
        ?? .local
    @State private var isEditingPrompt = false
    @State private var selectedPromptForEdit: TranscriptionPrompt?

    enum TranscriptionMode: String, CaseIterable {
        case local = "local"
        case cloud = "cloud"

        var displayName: String {
            switch self {
            case .local: return "Local (Whisper)"
            case .cloud: return "Cloud (AI Provider)"
            }
        }

        var description: String {
            switch self {
            case .local:
                return "Use local Whisper models for privacy-focused, offline transcription."
            case .cloud:
                return "Use cloud AI providers for enhanced accuracy and advanced features."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. TRANSCRIPTION MODE (TOP - Primary Decision)
                transcriptionModeSection

                // 2. MODE-SPECIFIC SECTIONS
                if transcriptionMode == .local {
                    // Local Mode: Whisper-specific sections
                    defaultModelSection
                    languageSelectionSection
                    availableModelsSection
                } else {
                    // Cloud Mode: AI Provider + Prompts
                    cloudProviderSection
                    languageContextSection
                    transcriptionPromptsSection
                }
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .alert(item: $modelToDelete) { model in
            Alert(
                title: Text("Delete Model"),
                message: Text("Are you sure you want to delete the model '\(model.name)'?"),
                primaryButton: .destructive(Text("Delete")) {
                    Task {
                        await whisperState.deleteModel(model)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $isEditingPrompt) {
            TranscriptionPromptEditorView(
                mode: .add, transcriptionPromptService: transcriptionPromptService)
        }
        .sheet(item: $selectedPromptForEdit) { prompt in
            TranscriptionPromptEditorView(
                mode: .edit(prompt), transcriptionPromptService: transcriptionPromptService)
        }
    }

    // MARK: - Transcription Mode Section (TOP)
    private var transcriptionModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription Method")
                .font(.title2)
                .fontWeight(.bold)

            Picker("Transcription Mode", selection: $transcriptionMode) {
                ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: transcriptionMode) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "TranscriptionMode")

                // Enable/disable Gemini transcription based on mode
                let geminiTranscription = GeminiAudioTranscription.shared
                geminiTranscription.setEnabled(newValue == .cloud)
            }

            Text(transcriptionMode.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Local Mode Sections
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(
                whisperState.currentModel.flatMap { model in
                    PredefinedModels.models.first { $0.name == model.name }?.displayName
                } ?? "No model selected"
            )
            .font(.title2)
            .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }

    private var languageSelectionSection: some View {
        LanguageSelectionView(
            whisperState: whisperState, displayMode: .full, whisperPrompt: whisperPrompt)
    }

    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Models")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("(\(whisperState.predefinedModels.count))")
                    .foregroundColor(.secondary)
                    .font(.subheadline)

                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(whisperState.predefinedModels) { model in
                    ModelCardRowView(
                        model: model,
                        isDownloaded: whisperState.availableModels.contains {
                            $0.name == model.name
                        },
                        isCurrent: whisperState.currentModel?.name == model.name,
                        downloadProgress: whisperState.downloadProgress,
                        modelURL: whisperState.availableModels.first { $0.name == model.name }?.url,
                        deleteAction: {
                            if let downloadedModel = whisperState.availableModels.first(where: {
                                $0.name == model.name
                            }) {
                                modelToDelete = downloadedModel
                            }
                        },
                        setDefaultAction: {
                            if let downloadedModel = whisperState.availableModels.first(where: {
                                $0.name == model.name
                            }) {
                                Task {
                                    await whisperState.setDefaultModel(downloadedModel)
                                }
                            }
                        },
                        downloadAction: {
                            Task {
                                await whisperState.downloadModel(model)
                            }
                        }
                    )
                }
            }
        }
        .padding()
    }

    // MARK: - Cloud Mode Sections
    private var cloudProviderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cloud AI Provider")
                .font(.title3)
                .fontWeight(.semibold)

            APIKeyManagementView()
                .environmentObject(aiService)
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }

    private var languageContextSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Language Context")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Select the language of your audio to help the AI understand context better.")
                .font(.caption)
                .foregroundColor(.secondary)

            LanguageSelectionView(
                whisperState: whisperState, displayMode: .full, whisperPrompt: whisperPrompt)
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }

    private var transcriptionPromptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription Prompts")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Choose how you want the AI to process your audio transcription.")
                .font(.caption)
                .foregroundColor(.secondary)

            TranscriptionPromptSelectionGrid(
                prompts: transcriptionPromptService.allPrompts,
                selectedPromptId: transcriptionPromptService.selectedPromptId,
                onPromptSelected: { prompt in
                    transcriptionPromptService.setActivePrompt(prompt)
                },
                onEditPrompt: { prompt in
                    selectedPromptForEdit = prompt
                },
                onDeletePrompt: { prompt in
                    transcriptionPromptService.deletePrompt(prompt)
                },
                onAddNewPrompt: {
                    isEditingPrompt = true
                }
            )
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }
}

// MARK: - Transcription Prompt Selection Grid
struct TranscriptionPromptSelectionGrid: View {
    let prompts: [TranscriptionPrompt]
    let selectedPromptId: UUID?
    let onPromptSelected: (TranscriptionPrompt) -> Void
    let onEditPrompt: (TranscriptionPrompt) -> Void
    let onDeletePrompt: (TranscriptionPrompt) -> Void
    let onAddNewPrompt: () -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(prompts) { prompt in
                TranscriptionPromptCard(
                    prompt: prompt,
                    isSelected: selectedPromptId == prompt.id,
                    onSelect: { onPromptSelected(prompt) },
                    onEdit: prompt.isDefault ? nil : { onEditPrompt(prompt) },
                    onDelete: prompt.isDefault ? nil : { onDeletePrompt(prompt) }
                )
            }

            // Add New Prompt Card
            AddNewPromptCard(onTap: onAddNewPrompt)
        }
    }
}

// MARK: - Transcription Prompt Card
struct TranscriptionPromptCard: View {
    let prompt: TranscriptionPrompt
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prompt.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if prompt.isDefault {
                    Text("Default")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }
            }

            Text(prompt.prompt)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.borderless)
                .foregroundColor(isSelected ? .white : .accentColor)

                Spacer()

                if let onEdit = onEdit {
                    Button("Edit") {
                        onEdit()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }

                if let onDelete = onDelete {
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .frame(minHeight: 120)
        .background(isSelected ? Color.accentColor : Color(.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Add New Prompt Card
struct AddNewPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        VStack {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundColor(.accentColor)

            Text("Add Custom Prompt")
                .font(.headline)
                .foregroundColor(.accentColor)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Transcription Prompt Editor View
struct TranscriptionPromptEditorView: View {
    enum Mode {
        case add
        case edit(TranscriptionPrompt)
    }

    let mode: Mode
    let transcriptionPromptService: TranscriptionPromptService

    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var showingHelp = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isPromptFieldFocused: Bool

    private let maxNameLength = 100
    private let maxPromptLength = 2000
    private let minPromptLength = 10

    private var isValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= maxNameLength
    }

    private var isValidPrompt: Bool {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt.count >= minPromptLength && trimmedPrompt.count <= maxPromptLength
    }

    private var canSave: Bool {
        isValidName && isValidPrompt
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode.isEdit ? "Edit Prompt" : "New Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    savePrompt()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Prompt Name")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(name.count)/\(maxNameLength)")
                            .font(.caption)
                            .foregroundColor(name.count > maxNameLength ? .red : .secondary)
                    }

                    TextField("Enter a descriptive name for your prompt", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            isPromptFieldFocused = true
                        }

                    if !name.isEmpty && !isValidName {
                        Text(
                            name.count > maxNameLength ? "Name is too long" : "Name cannot be empty"
                        )
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Prompt Text")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(prompt.count)/\(maxPromptLength) characters")
                            .font(.caption)
                            .foregroundColor(prompt.count > maxPromptLength ? .red : .secondary)
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $prompt)
                            .focused($isPromptFieldFocused)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))

                        if prompt.isEmpty {
                            Text(
                                "Enter your transcription prompt here...\n\nExample: 'Please transcribe the following audio file accurately and translate to English. Provide only the English text without any additional commentary.'"
                            )
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isPromptFieldFocused
                                    ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: isPromptFieldFocused ? 2 : 1)
                    )

                    HStack {
                        if !prompt.isEmpty && !isValidPrompt {
                            Text(
                                prompt.count < minPromptLength
                                    ? "Prompt is too short (minimum \(minPromptLength) characters)"
                                    : "Prompt is too long"
                            )
                            .font(.caption)
                            .foregroundColor(.red)
                        } else if !prompt.isEmpty {
                            Text("\(prompt.split(separator: " ").count) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(width: 700, height: 550)
        .onAppear {
            if case .edit(let existingPrompt) = mode {
                name = existingPrompt.name
                prompt = existingPrompt.prompt
            }
        }
    }

    private func savePrompt() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .add:
            let newPrompt = TranscriptionPrompt(name: trimmedName, prompt: trimmedPrompt)
            transcriptionPromptService.addCustomPrompt(newPrompt)
        case .edit(let existingPrompt):
            var updatedPrompt = existingPrompt
            updatedPrompt.name = trimmedName
            updatedPrompt.prompt = trimmedPrompt
            transcriptionPromptService.updatePrompt(updatedPrompt)
        }
    }
}

extension TranscriptionPromptEditorView.Mode {
    var isEdit: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}
