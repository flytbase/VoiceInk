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
    private let loggingService: LoggingService

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
        audioStorage: AudioStorageService = AudioStorageService.shared,
        loggingService: LoggingService = LoggingService.shared
    ) {
        self.transcription = transcription
        self.modelContext = modelContext
        self.enhancementService = enhancementService
        self.audioStorage = audioStorage
        self.loggingService = loggingService

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
            enhancementService: fallbackEnhancementService,
            loggingService: LoggingService.shared
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
        let startTime = Date()
        let transcriptionId = transcription.id.uuidString
        
        // Log start of re-transcription
        loggingService.info(
            "Starting re-transcription process from TranscriptionCard",
            category: .transcription,
            context: [
                "transcription_id": transcriptionId,
                "original_text_length": "\(transcription.text.count)",
                "duration": "\(transcription.duration)s",
                "existing_versions": "\(transcription.transcriptionVersions.count)",
                "source": "TranscriptionCard"
            ]
        )
        
        guard let audioURLString = transcription.audioFileURL,
            let audioURL = URL(string: audioURLString),
            FileManager.default.fileExists(atPath: audioURL.path)
        else {
            loggingService.error(
                "Re-transcription failed: Audio file not found",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "audio_url": transcription.audioFileURL ?? "nil",
                    "source": "TranscriptionCard"
                ]
            )
            showError("Audio file not found")
            return
        }

        await MainActor.run {
            loggingService.debug(
                "Setting re-transcription processing state",
                category: .transcription,
                context: ["transcription_id": transcriptionId, "source": "TranscriptionCard"]
            )
            processingState.isRetranscribing = true
        }

        defer {
            Task { @MainActor in
                loggingService.debug(
                    "Clearing re-transcription processing state",
                    category: .transcription,
                    context: ["transcription_id": transcriptionId, "source": "TranscriptionCard"]
                )
                processingState.isRetranscribing = false
            }
        }

        do {
            loggingService.debug(
                "Initializing WhisperState for re-transcription",
                category: .transcription,
                context: ["transcription_id": transcriptionId, "source": "TranscriptionCard"]
            )
            
            // Use the shared manager for re-transcription
            try await EnhancedTranscriptionManager.shared.retranscribeWithVersioning(
                transcription: transcription,
                modelContext: modelContext,
                whisperState: WhisperState(modelContext: modelContext)
            )

            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.info(
                "Re-transcription completed successfully from TranscriptionCard",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "new_versions_count": "\(transcription.transcriptionVersions.count)",
                    "source": "TranscriptionCard"
                ]
            )

            // Show success message
            processingState.showRetranscribeSuccess = true

            // Hide success message after delay
            try await Task.sleep(nanoseconds: Constants.successMessageDuration)
            processingState.showRetranscribeSuccess = false

        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.error(
                "Re-transcription failed from TranscriptionCard",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)",
                    "source": "TranscriptionCard"
                ],
                error: error
            )
            showError("Re-transcription failed: \(error.localizedDescription)")
        }
    }

    func performEnhancement() async {
        let startTime = Date()
        let transcriptionId = transcription.id.uuidString
        
        // Log start of enhancement
        loggingService.info(
            "Starting AI enhancement process from TranscriptionCard",
            category: .enhancement,
            context: [
                "transcription_id": transcriptionId,
                "text_length": "\(transcription.text.count)",
                "existing_enhancements": "\(transcription.enhancementVersions.count)",
                "has_versions": "\(!transcription.transcriptionVersions.isEmpty)",
                "source": "TranscriptionCard"
            ]
        )
        
        guard enhancementService.isConfigured else {
            loggingService.error(
                "AI Enhancement not configured",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "source": "TranscriptionCard"
                ]
            )
            showError("AI Enhancement not configured. Please check settings.")
            return
        }

        guard enhancementService.isEnhancementEnabled else {
            loggingService.error(
                "AI Enhancement is disabled",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "source": "TranscriptionCard"
                ]
            )
            showError("AI Enhancement is disabled. Enable it in settings.")
            return
        }

        guard let activePrompt = enhancementService.activePrompt else {
            loggingService.error(
                "No enhancement prompt selected",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "source": "TranscriptionCard"
                ]
            )
            showError("No enhancement prompt selected. Please select one in settings.")
            return
        }

        loggingService.debug(
            "Setting enhancement processing state",
            category: .enhancement,
            context: [
                "transcription_id": transcriptionId,
                "enhancement_method": activePrompt.title,
                "source": "TranscriptionCard"
            ]
        )

        processingState.isEnhancing = true

        defer {
            loggingService.debug(
                "Clearing enhancement processing state",
                category: .enhancement,
                context: ["transcription_id": transcriptionId, "source": "TranscriptionCard"]
            )
            processingState.isEnhancing = false
        }

        // Get text to enhance
        let textToEnhance: String
        if let selectedVersion = selectedTranscriptionVersion {
            textToEnhance = selectedVersion.text
            loggingService.debug(
                "Using selected transcription version for enhancement",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "version_id": selectedVersion.id.uuidString,
                    "text_length": "\(selectedVersion.text.count)",
                    "source": "TranscriptionCard"
                ]
            )
        } else {
            textToEnhance = transcription.text
            loggingService.debug(
                "Using original transcription text for enhancement",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "text_length": "\(transcription.text.count)",
                    "source": "TranscriptionCard"
                ]
            )
        }

        do {
            loggingService.debug(
                "Calling AI enhancement service",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "enhancement_method": activePrompt.title,
                    "input_text_length": "\(textToEnhance.count)",
                    "source": "TranscriptionCard"
                ]
            )
            
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

            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.info(
                "AI enhancement completed successfully from TranscriptionCard",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "enhancement_method": activePrompt.title,
                    "input_text_length": "\(textToEnhance.count)",
                    "output_text_length": "\(enhancedText.count)",
                    "total_enhancements": "\(transcription.enhancementVersions.count)",
                    "source": "TranscriptionCard"
                ]
            )

            // Show success feedback
            showCopyFeedback(message: "Enhancement completed")

        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.error(
                "AI enhancement failed from TranscriptionCard",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "enhancement_method": activePrompt.title,
                    "input_text_length": "\(textToEnhance.count)",
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)",
                    "source": "TranscriptionCard"
                ],
                error: error
            )
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
