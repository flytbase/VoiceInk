import AppKit
import Foundation
import SwiftData
import SwiftUI

// MARK: - State Structures

struct SelectionState {
    var selectedTranscriptionVersionId: UUID?
    var selectedEnhancementVersionId: UUID?
}

struct ProcessingState {
    var isRetranscribing = false
    var isEnhancing = false
    var showRetranscribeSuccess = false
    var showEnhanceSuccess = false
}

struct FeedbackState {
    var showCopyFeedback = false
    var copyFeedbackMessage = ""
    var errorMessage = ""
    var showingError = false
    var showingDeleteAlert = false
}

struct UIState {
    var showMoreRawText = false
    var showMoreEnhancedText = false
}

// MARK: - TranscriptionCardViewModel

@MainActor
class TranscriptionCardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectionState = SelectionState()
    @Published var processingState = ProcessingState()
    @Published var feedbackState = FeedbackState()
    @Published var uiState = UIState()

    // MARK: - Dependencies

    private let transcription: Transcription
    private let modelContext: ModelContext
    private let enhancementService: AIEnhancementService
    private let audioStorage: AudioStorageService

    // MARK: - Constants

    private enum Constants {
        static let copyFeedbackDuration: UInt64 = 2_000_000_000  // 2 seconds
        static let successMessageDuration: UInt64 = 3_000_000_000  // 3 seconds
        static let previewTextLimit = 150
        static let previewLineLimit = 2
    }

    // MARK: - Initialization

    init(
        transcription: Transcription,
        modelContext: ModelContext,
        enhancementService: AIEnhancementService,
        audioStorage: AudioStorageService = AudioStorageService.shared
    ) {
        self.transcription = transcription
        self.modelContext = modelContext
        self.enhancementService = enhancementService
        self.audioStorage = audioStorage

        setupDefaultSelections()
    }
    
    // MARK: - Fallback Initialization
    
    static func fallback(
        transcription: Transcription,
        error: Error
    ) -> TranscriptionCardViewModel {
        // Create a minimal fallback configuration
        let fallbackModelContext = try! ModelContext(ModelContainer(for: Transcription.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let fallbackEnhancementService = AIEnhancementService(modelContext: fallbackModelContext)
        
        let viewModel = TranscriptionCardViewModel(
            transcription: transcription,
            modelContext: fallbackModelContext,
            enhancementService: fallbackEnhancementService
        )
        
        // Set error state
        viewModel.feedbackState.errorMessage = "Failed to initialize: \(error.localizedDescription)"
        viewModel.feedbackState.showingError = true
        
        return viewModel
    }

    // MARK: - Setup

    private func setupDefaultSelections() {
        if selectionState.selectedTranscriptionVersionId == nil {
            selectionState.selectedTranscriptionVersionId =
                transcription.latestVersion?.id ?? transcription.mainVersion?.id
        }

        if selectionState.selectedEnhancementVersionId == nil,
            let selectedVersion = selectedTranscriptionVersion
        {
            selectionState.selectedEnhancementVersionId =
                enhancementsForVersion(selectedVersion.id).first?.id
        }
    }

    // MARK: - Computed Properties

    var selectedTranscriptionVersion: TranscriptionVersion? {
        if let selectedId = selectionState.selectedTranscriptionVersionId {
            return transcription.transcriptionVersions.first { $0.id == selectedId }
        }
        return transcription.latestVersion ?? transcription.mainVersion
    }

    var selectedEnhancementVersion: EnhancementVersion? {
        if let selectedId = selectionState.selectedEnhancementVersionId {
            return transcription.enhancementVersions.first { $0.id == selectedId }
        }
        // Auto-select latest enhancement for the selected transcription version
        if let transcriptionVersion = selectedTranscriptionVersion {
            return enhancementsForVersion(transcriptionVersion.id).first
        }
        return transcription.latestEnhancement
    }

    var hasEnhancements: Bool {
        !transcription.enhancementVersions.isEmpty
    }

    var sortedTranscriptionVersions: [TranscriptionVersion] {
        transcription.transcriptionVersions.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var sortedEnhancementVersions: [EnhancementVersion] {
        transcription.enhancementVersions.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var previewText: String {
        // Use latest transcription version for preview, not the selected one
        let fullText = transcription.latestVersion?.text ?? transcription.text
        let lines = fullText.components(separatedBy: .newlines)
        let previewLines = Array(lines.prefix(2))
        let preview = previewLines.joined(separator: "\n")
        return preview.count > Constants.previewTextLimit
            ? String(preview.prefix(Constants.previewTextLimit)) + "..." : preview
    }

    // MARK: - Helper Methods

    func enhancementsForVersion(_ versionId: UUID) -> [EnhancementVersion] {
        return transcription.enhancementVersions
            .filter { $0.baseVersionId == versionId }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    // MARK: - Selection Actions

    func selectTranscriptionVersion(_ versionId: UUID) {
        selectionState.selectedTranscriptionVersionId = versionId

        // Auto-select latest enhancement when switching transcription versions
        let enhancements = enhancementsForVersion(versionId)
        selectionState.selectedEnhancementVersionId = enhancements.first?.id
    }

    func selectEnhancementVersion(_ enhancementId: UUID) {
        selectionState.selectedEnhancementVersionId = enhancementId
    }

    // MARK: - UI Actions

    func toggleRawTextExpansion() {
        uiState.showMoreRawText.toggle()
    }

    func toggleEnhancedTextExpansion() {
        uiState.showMoreEnhancedText.toggle()
    }

    func showDeleteAlert() {
        feedbackState.showingDeleteAlert = true
    }

    // MARK: - Copy Actions

    func copyRawText() {
        let textToCopy: String
        if let selectedVersion = selectedTranscriptionVersion {
            textToCopy = selectedVersion.text
        } else {
            textToCopy = transcription.text
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)

        showCopyFeedback(message: "Raw text copied")
    }

    func copyEnhancedText() {
        guard hasEnhancements else { return }

        let textToCopy: String
        if let selectedId = selectionState.selectedEnhancementVersionId,
            let enhancement = transcription.enhancementVersions.first(where: { $0.id == selectedId }
            )
        {
            textToCopy = enhancement.enhancedText
        } else if let latestEnhancement = transcription.enhancementVersions.sorted(by: {
            $0.createdAt > $1.createdAt
        }).first {
            textToCopy = latestEnhancement.enhancedText
        } else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)

        showCopyFeedback(message: "Enhanced text copied")
    }

    private func showCopyFeedback(message: String) {
        feedbackState.copyFeedbackMessage = message
        feedbackState.showCopyFeedback = true

        Task {
            try await Task.sleep(nanoseconds: Constants.copyFeedbackDuration)
            await MainActor.run {
                feedbackState.showCopyFeedback = false
            }
        }
    }

    // MARK: - Processing Actions

    func performRetranscription() async {
        print("🔄 [DEBUG] performRetranscription() called")
        
        guard let audioURLString = transcription.audioFileURL,
            let audioURL = URL(string: audioURLString),
            FileManager.default.fileExists(atPath: audioURL.path)
        else {
            print("🔄 [DEBUG] Audio file not found")
            showError("Audio file not found")
            return
        }

        await MainActor.run {
            print("🔄 [DEBUG] Setting isRetranscribing = true")
            processingState.isRetranscribing = true
        }

        defer {
            Task { @MainActor in
                print("🔄 [DEBUG] defer: Setting isRetranscribing = false")
                processingState.isRetranscribing = false
            }
        }

        do {
            // Use the shared manager for re-transcription
            try await EnhancedTranscriptionManager.shared.retranscribeWithVersioning(
                transcription: transcription,
                modelContext: modelContext,
                whisperState: WhisperState(modelContext: modelContext)
            )

            // Show success message
            processingState.showRetranscribeSuccess = true

            // Hide success message after delay
            try await Task.sleep(nanoseconds: Constants.successMessageDuration)
            processingState.showRetranscribeSuccess = false

        } catch {
            showError("Re-transcription failed: \(error.localizedDescription)")
        }
    }

    func performEnhancement() async {
        guard enhancementService.isConfigured else {
            showError("AI Enhancement not configured. Please check settings.")
            return
        }

        guard enhancementService.isEnhancementEnabled else {
            showError("AI Enhancement is disabled. Enable it in settings.")
            return
        }

        guard let activePrompt = enhancementService.activePrompt else {
            showError("No enhancement prompt selected. Please select one in settings.")
            return
        }

        processingState.isEnhancing = true

        defer {
            processingState.isEnhancing = false
        }

        // Get text to enhance
        let textToEnhance: String
        if let selectedVersion = selectedTranscriptionVersion {
            textToEnhance = selectedVersion.text
        } else {
            textToEnhance = transcription.text
        }

        do {
            // Use the configured enhancement service
            let enhancedText = try await enhancementService.enhance(textToEnhance)

            // Create enhancement version
            let baseVersionId =
                selectedTranscriptionVersion?.id ?? transcription.mainVersion?.id ?? UUID()
            let enhancementVersion = EnhancementVersion(
                enhancedText: enhancedText,
                enhancementMethod: activePrompt.title,
                baseVersionId: baseVersionId,
                enhancementPrompt: activePrompt.promptText
            )

            // Add to transcription
            transcription.addEnhancementVersion(enhancementVersion)

            // Save to model context
            try modelContext.save()

            // Show success feedback
            showCopyFeedback(message: "Enhancement completed")

        } catch {
            showError("Enhancement failed: \(error.localizedDescription)")
        }
    }

    func downloadAudio() async {
        do {
            _ = try await audioStorage.downloadAudio(from: transcription)
        } catch {
            showError("Audio download failed: \(error.localizedDescription)")
        }
    }

    func deleteTranscription() {
        modelContext.delete(transcription)
        try? modelContext.save()
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        feedbackState.errorMessage = message
        feedbackState.showingError = true
    }

    func handleError(_ error: Error, context: String = "") {
        let message =
            context.isEmpty
            ? error.localizedDescription
            : "\(context): \(error.localizedDescription)"
        showError(message)
    }
}
