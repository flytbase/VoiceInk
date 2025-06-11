import AVFoundation
import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
class AudioTranscriptionManager: ObservableObject {
    static let shared = AudioTranscriptionManager()

    @Published var isProcessing = false
    @Published var processingPhase: ProcessingPhase = .idle
    @Published var currentTranscription: Transcription?
    @Published var messageLog: String = ""
    @Published var errorMessage: String?

    // NEW: Streaming-specific published properties
    @Published var streamingState: StreamingState = .idle
    @Published var streamingProgress: StreamingProgress = StreamingProgress()
    @Published var liveTranscriptionText: String = ""
    @Published var isStreamingMode: Bool = false

    // NEW: Re-transcription tracking
    @Published var activeRetranscriptions: Set<UUID> = []

    private var currentTask: Task<Void, Error>?
    private var whisperContext: WhisperContext?
    private let audioProcessor = AudioProcessor()
    private let loggingService: LoggingService

    // NEW: Streaming services
    private let geminiStreamingService = GeminiStreamingService()
    private let audioPreprocessingService = AudioPreprocessingService()
    private var streamingProgressEstimator: StreamingProgressEstimator?
    private var uploadedFile: UploadedFile?

    enum ProcessingPhase {
        case idle
        case loading
        case processingAudio
        case transcribing
        case enhancing
        case completed

        var message: String {
            switch self {
            case .idle:
                return ""
            case .loading:
                return "Loading transcription model..."
            case .processingAudio:
                return "Processing audio file for transcription..."
            case .transcribing:
                let geminiTranscription = GeminiAudioTranscription.shared
                if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
                    return "Transcribing audio with Gemini 2.5 Pro..."
                } else {
                    return "Transcribing audio with Whisper..."
                }
            case .enhancing:
                return "Enhancing transcription with AI..."
            case .completed:
                return "Transcription completed!"
            }
        }
    }

    private init(loggingService: LoggingService = LoggingService.shared) {
        self.loggingService = loggingService
    }

    func startProcessing(
        url: URL, modelContext: ModelContext, whisperState: WhisperState,
        audioContext: String? = nil
    ) {
        let startTime = Date()
        let sessionId = UUID().uuidString
        let audioFileName = url.lastPathComponent

        // Log start of processing
        loggingService.info(
            "Starting audio transcription processing",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "file_name": audioFileName,
                "file_url": url.path,
                "source": "AudioTranscriptionManager",
            ]
        )

        // Cancel any existing processing
        cancelProcessing()

        isProcessing = true
        processingPhase = .loading
        messageLog = ""
        errorMessage = nil

        currentTask = Task {
            do {
                // Check if streaming mode should be used
                if shouldUseStreamingMode(for: url) {
                    // Use streaming transcription
                    await transcribeWithStreaming(
                        audioURL: url,
                        modelContext: modelContext,
                        whisperState: whisperState
                    )
                    return
                }

                // Continue with Whisper transcription for non-streaming cases
                loggingService.debug(
                    "Using Whisper transcription path",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "method": "Whisper",
                        "source": "AudioTranscriptionManager",
                    ]
                )

                guard let currentModel = whisperState.currentModel else {
                    loggingService.error(
                        "Whisper transcription failed: No model selected",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "source": "AudioTranscriptionManager",
                        ]
                    )
                    throw TranscriptionError.noModelSelected
                }

                loggingService.debug(
                    "Loading Whisper model",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "model_path": currentModel.url.path,
                        "source": "AudioTranscriptionManager",
                    ]
                )

                // Load Whisper model
                whisperContext = try await WhisperContext.createContext(path: currentModel.url.path)

                // Process audio file
                processingPhase = .processingAudio
                let samples = try await audioProcessor.processAudioToSamples(url)

                loggingService.debug(
                    "Audio processed to samples",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "sample_count": "\(samples.count)",
                        "source": "AudioTranscriptionManager",
                    ]
                )

                // Get audio duration
                let audioAsset = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))

                // Create permanent copy of the audio file
                let recordingsDirectory = FileManager.default.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("com.prakashjoshipax.VoiceInk")
                    .appendingPathComponent("Recordings")

                let fileName = "transcribed_\(UUID().uuidString).wav"
                let permanentURL = recordingsDirectory.appendingPathComponent(fileName)

                try FileManager.default.createDirectory(
                    at: recordingsDirectory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: url, to: permanentURL)

                loggingService.debug(
                    "Audio file copied to permanent storage",
                    category: .fileSystem,
                    context: [
                        "session_id": sessionId,
                        "permanent_path": permanentURL.path,
                        "source": "AudioTranscriptionManager",
                    ]
                )

                // Transcribe
                processingPhase = .transcribing
                await whisperContext?.setPrompt(whisperState.whisperPrompt.transcriptionPrompt)
                try await whisperContext?.fullTranscribe(samples: samples)
                var text = await whisperContext?.getTranscription() ?? ""
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                text = WhisperTextFormatter.format(text)

                loggingService.debug(
                    "Whisper transcription completed",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "text_length": "\(text.count)",
                        "duration": "\(duration)s",
                        "source": "AudioTranscriptionManager",
                    ]
                )

                // Apply word replacements if enabled
                if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                    let originalLength = text.count
                    text = WordReplacementService.shared.applyReplacements(to: text)
                    loggingService.debug(
                        "Word replacements applied",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "original_length": "\(originalLength)",
                            "new_length": "\(text.count)",
                            "source": "AudioTranscriptionManager",
                        ]
                    )
                }

                // Handle enhancement if enabled
                if let enhancementService = whisperState.enhancementService,
                    enhancementService.isEnhancementEnabled,
                    enhancementService.isConfigured
                {

                    loggingService.debug(
                        "Starting AI enhancement",
                        category: .enhancement,
                        context: [
                            "session_id": sessionId,
                            "text_length": "\(text.count)",
                            "source": "AudioTranscriptionManager",
                        ]
                    )

                    processingPhase = .enhancing
                    do {
                        let enhancedText = try await enhancementService.enhance(text)
                        let transcription = Transcription(
                            text: text,
                            duration: duration,
                            enhancedText: enhancedText,
                            audioFileURL: permanentURL.absoluteString
                        )
                        modelContext.insert(transcription)
                        try modelContext.save()
                        currentTranscription = transcription

                        loggingService.info(
                            "Whisper transcription with enhancement completed successfully",
                            category: .enhancement,
                            context: [
                                "session_id": sessionId,
                                "transcription_id": transcription.id.uuidString,
                                "enhanced_text_length": "\(enhancedText.count)",
                                "source": "AudioTranscriptionManager",
                            ]
                        )
                    } catch {
                        loggingService.warning(
                            "Enhancement failed, using original transcription",
                            category: .enhancement,
                            context: [
                                "session_id": sessionId,
                                "error_domain": (error as NSError).domain,
                                "error_code": "\((error as NSError).code)",
                                "source": "AudioTranscriptionManager",
                            ]
                        )
                        messageLog +=
                            "Enhancement failed: \(error.localizedDescription). Using original transcription.\n"
                        let transcription = Transcription(
                            text: text,
                            duration: duration,
                            audioFileURL: permanentURL.absoluteString
                        )
                        modelContext.insert(transcription)
                        try modelContext.save()
                        currentTranscription = transcription
                    }
                } else {
                    let transcription = Transcription(
                        text: text,
                        duration: duration,
                        audioFileURL: permanentURL.absoluteString
                    )
                    modelContext.insert(transcription)
                    try modelContext.save()
                    currentTranscription = transcription

                    loggingService.info(
                        "Whisper transcription completed successfully (no enhancement)",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "transcription_id": transcription.id.uuidString,
                            "text_length": "\(text.count)",
                            "source": "AudioTranscriptionManager",
                        ]
                    )
                }

                processingPhase = .completed
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await finishProcessing()

                let totalProcessingTime = Date().timeIntervalSince(startTime)
                loggingService.info(
                    "Whisper transcription session completed",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "total_processing_time": String(format: "%.2f", totalProcessingTime),
                        "method": "Whisper",
                        "source": "AudioTranscriptionManager",
                    ]
                )

            } catch {
                await handleError(error)
            }
        }
    }

    func cancelProcessing() {
        currentTask?.cancel()
        cleanupResources()
    }

    private func finishProcessing() {
        isProcessing = false
        processingPhase = .idle
        currentTask = nil
        cleanupResources()
    }

    private func handleError(_ error: Error) {
        loggingService.error(
            "Transcription processing failed",
            category: .transcription,
            context: [
                "error_domain": (error as NSError).domain,
                "error_code": "\((error as NSError).code)",
                "source": "AudioTranscriptionManager",
            ],
            error: error
        )
        errorMessage = error.localizedDescription
        messageLog += "Error: \(error.localizedDescription)\n"
        isProcessing = false
        processingPhase = .idle
        currentTask = nil
        cleanupResources()
    }

    private func cleanupResources() {
        whisperContext = nil
        streamingProgressEstimator = nil
        uploadedFile = nil
        liveTranscriptionText = ""
        streamingState = .idle
    }

    // MARK: - NEW: Streaming Transcription Methods

    /// Unified streaming transcription method for both new files and re-transcription
    func transcribeWithStreaming(
        audioURL: URL,
        modelContext: ModelContext,
        whisperState: WhisperState,
        isRetranscription: Bool = false,
        originalTranscription: Transcription? = nil,
        transcriptionId: UUID? = nil,
        audioContext: String? = nil
    ) async {
        let sessionId = UUID().uuidString
        let startTime = Date()

        loggingService.info(
            "Starting streaming transcription",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "file_name": audioURL.lastPathComponent,
                "is_retranscription": "\(isRetranscription)",
                "transcription_id": transcriptionId?.uuidString ?? "none",
                "method": "Gemini Streaming",
            ]
        )

        // Track re-transcription if applicable
        if isRetranscription, let id = transcriptionId {
            activeRetranscriptions.insert(id)
        }

        // Cancel any existing processing
        cancelProcessing()

        // Set up streaming mode
        isProcessing = true
        isStreamingMode = true
        streamingState = .idle
        streamingProgress = StreamingProgress()
        liveTranscriptionText = ""
        errorMessage = nil

        currentTask = Task {
            do {
                // Validate Gemini configuration
                try geminiStreamingService.validateConfiguration()

                // Phase 1: Audio preprocessing (if enabled)
                let optimizedURL: URL
                if StreamingConfiguration.preprocessAudio {
                    streamingState = .preprocessing(progress: 0.0)

                    optimizedURL = try await audioPreprocessingService.preprocessForGemini(
                        inputURL: audioURL
                    ) { progress in
                        Task { @MainActor in
                            self.streamingState = .preprocessing(progress: progress)
                        }
                    }
                } else {
                    // Skip preprocessing, use original file
                    optimizedURL = audioURL
                }

                // Get audio duration for progress estimation
                let audioAsset = AVURLAsset(url: audioURL)
                let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))
                streamingProgressEstimator = StreamingProgressEstimator(audioDuration: duration)

                // Phase 2: File upload
                streamingState = .uploading(progress: 0.0)

                // Get MIME type for the audio file
                let mimeType = getMimeType(for: optimizedURL)

                uploadedFile = try await geminiStreamingService.uploadAudioFile(
                    url: optimizedURL,
                    mimeType: mimeType
                ) { progress in
                    Task { @MainActor in
                        self.streamingState = .uploading(progress: progress)
                    }
                }

                // Phase 3: Streaming transcription
                streamingState = .streaming(progress: 0.0, liveText: "")

                // Get the selected prompt from TranscriptionPromptService
                let promptService = TranscriptionPromptService()
                let selectedPrompt = promptService.selectedPrompt
                var prompt =
                    selectedPrompt?.prompt
                    ?? "Please transcribe this audio file accurately. Provide the complete transcription without any additional commentary."

                // Append audio context if provided
                if let context = audioContext, !context.isEmpty {
                    prompt += "\n\nAdditional Context: \(context)"
                    loggingService.debug(
                        "Added audio context to prompt",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "context_length": "\(context.count)",
                            "context_preview": String(context.prefix(100)),
                        ]
                    )
                }

                var fullTranscriptionText = ""

                for try await chunk in geminiStreamingService.streamTranscription(
                    fileURI: uploadedFile!.uri,
                    prompt: prompt
                ) {
                    // Update live text
                    fullTranscriptionText += chunk.text
                    liveTranscriptionText = fullTranscriptionText

                    // Update progress estimation
                    if let estimator = streamingProgressEstimator {
                        let estimatedProgress = estimator.estimateProgress(newChunk: chunk)
                        streamingState = .streaming(
                            progress: estimatedProgress, liveText: fullTranscriptionText)
                    }

                    // Break if transcription is complete
                    if chunk.isComplete {
                        break
                    }
                }

                // Phase 4: Finalization
                streamingState = .finalizing

                // Clean up the text
                var finalText = fullTranscriptionText.trimmingCharacters(
                    in: .whitespacesAndNewlines)

                // Apply word replacements if enabled
                if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                    finalText = WordReplacementService.shared.applyReplacements(to: finalText)
                }

                // Create permanent copy of the audio file
                let recordingsDirectory = FileManager.default.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("com.prakashjoshipax.VoiceInk")
                    .appendingPathComponent("Recordings")

                let fileName = "transcribed_\(UUID().uuidString).wav"
                let permanentURL = recordingsDirectory.appendingPathComponent(fileName)

                try FileManager.default.createDirectory(
                    at: recordingsDirectory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: audioURL, to: permanentURL)

                // Handle enhancement if enabled
                var enhancedText: String? = nil
                if let enhancementService = whisperState.enhancementService,
                    enhancementService.isEnhancementEnabled,
                    enhancementService.isConfigured
                {

                    do {
                        enhancedText = try await enhancementService.enhance(finalText)
                    } catch {
                        loggingService.warning(
                            "Enhancement failed during streaming transcription",
                            category: .enhancement,
                            context: [
                                "session_id": sessionId,
                                "error": error.localizedDescription,
                            ]
                        )
                    }
                }

                // Get the actual selected model name
                let aiService = AIService()
                let selectedModel = aiService.currentModel

                // Save transcription
                if isRetranscription, let original = originalTranscription {
                    // Create new version for existing transcription
                    let newVersion = TranscriptionVersion(
                        text: finalText,
                        transcriptionMethod: selectedModel,
                        promptUsed: prompt,
                        isMainVersion: false,
                        confidence: nil
                    )
                    original.transcriptionVersions.append(newVersion)

                    // Create enhancement version if enhanced text exists
                    if let enhanced = enhancedText,
                        let enhancementService = whisperState.enhancementService,
                        let activePrompt = enhancementService.activePrompt
                    {

                        let enhancementVersion = EnhancementVersion(
                            enhancedText: enhanced,
                            enhancementMethod: activePrompt.title,  // e.g., "Grammar Correction"
                            baseVersionId: newVersion.id,
                            enhancementPrompt: activePrompt.promptText
                        )
                        original.enhancementVersions.append(enhancementVersion)
                    }

                    try modelContext.save()
                    currentTranscription = original
                } else {
                    // Create new transcription (V2 FORMAT)
                    let transcription = Transcription(
                        text: "",  // Empty - text goes in versions
                        duration: duration,
                        enhancedText: nil,  // Empty - enhanced text goes in enhancement versions
                        audioFileURL: permanentURL.absoluteString
                    )

                    // Create main transcription version
                    let mainVersion = TranscriptionVersion(
                        text: finalText,
                        transcriptionMethod: selectedModel,  // Dynamic model name (e.g., "gemini-2.0-flash-exp")
                        promptUsed: prompt,
                        isMainVersion: true,
                        confidence: nil
                    )
                    transcription.addTranscriptionVersion(mainVersion)

                    // Create enhancement version if enhanced text exists
                    if let enhanced = enhancedText,
                        let enhancementService = whisperState.enhancementService,
                        let activePrompt = enhancementService.activePrompt
                    {

                        let enhancementVersion = EnhancementVersion(
                            enhancedText: enhanced,
                            enhancementMethod: activePrompt.title,  // e.g., "Grammar Correction"
                            baseVersionId: mainVersion.id,
                            enhancementPrompt: activePrompt.promptText
                        )
                        transcription.addEnhancementVersion(enhancementVersion)
                    }

                    modelContext.insert(transcription)
                    try modelContext.save()
                    currentTranscription = transcription
                }

                // Cleanup uploaded file
                if let uploadedFile = uploadedFile {
                    try? await geminiStreamingService.deleteFile(uri: uploadedFile.uri)
                }

                // Complete
                streamingState = .complete

                let totalTime = Date().timeIntervalSince(startTime)
                loggingService.info(
                    "Streaming transcription completed successfully",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "total_time": String(format: "%.2f", totalTime),
                        "text_length": "\(finalText.count)",
                        "enhanced": "\(enhancedText != nil)",
                    ]
                )

                // Remove from active re-transcriptions
                if isRetranscription, let id = transcriptionId {
                    activeRetranscriptions.remove(id)
                }

                // Wait a moment to show completion, then finish
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await finishStreamingProcessing()

            } catch {
                // Remove from active re-transcriptions on error
                if isRetranscription, let id = transcriptionId {
                    activeRetranscriptions.remove(id)
                }
                await handleStreamingError(error, sessionId: sessionId)
            }
        }
    }

    /// Cancels streaming processing and cleans up resources
    func cancelStreamingProcessing() {
        currentTask?.cancel()

        // Cleanup uploaded file if exists
        if let uploadedFile = uploadedFile {
            Task {
                try? await geminiStreamingService.deleteFile(uri: uploadedFile.uri)
            }
        }

        // Clear all active re-transcriptions
        activeRetranscriptions.removeAll()

        finishStreamingProcessing()
    }

    /// Determines if streaming mode should be used for a given file
    func shouldUseStreamingMode(for url: URL) -> Bool {
        print(
            "🔍 [AudioTranscriptionManager] shouldUseStreamingMode called for: \(url.lastPathComponent)"
        )

        // Check if streaming is enabled in settings
        let streamingEnabled = StreamingConfiguration.streamingEnabled
        print(
            "🔍 [AudioTranscriptionManager] StreamingConfiguration.streamingEnabled: \(streamingEnabled)"
        )
        guard streamingEnabled else {
            print("❌ [AudioTranscriptionManager] Streaming DISABLED in settings - returning false")
            return false
        }

        // Check if Gemini is configured
        print("🔍 [AudioTranscriptionManager] Checking Gemini configuration...")
        do {
            try geminiStreamingService.validateConfiguration()
            print("✅ [AudioTranscriptionManager] Gemini configuration is VALID - returning TRUE")
            return true
        } catch {
            print(
                "❌ [AudioTranscriptionManager] Gemini configuration INVALID: \(error.localizedDescription)"
            )
            return false
        }
    }

    // MARK: - Private Streaming Helpers

    private func finishStreamingProcessing() {
        isProcessing = false
        isStreamingMode = false
        streamingState = .idle
        currentTask = nil
        cleanupResources()
    }

    private func handleStreamingError(_ error: Error, sessionId: String) {
        loggingService.error(
            "Streaming transcription failed",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "error": error.localizedDescription,
            ],
            error: error
        )

        // Cleanup uploaded file if exists
        if let uploadedFile = uploadedFile {
            Task {
                try? await geminiStreamingService.deleteFile(uri: uploadedFile.uri)
            }
        }

        // Check if we should fallback to traditional transcription
        if let streamingError = error as? StreamingError,
            streamingError.shouldFallbackToTraditional
        {
            streamingState = .error(
                "Streaming failed. Falling back to traditional transcription...")

            // TODO: Implement fallback to traditional transcription
            // For now, just show the error
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.streamingState = .error(streamingError.localizedDescription)
            }
        } else {
            streamingState = .error(error.localizedDescription)
        }

        errorMessage = error.localizedDescription
        isProcessing = false
        isStreamingMode = false
        currentTask = nil
    }

    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    /// Determines MIME type based on file extension
    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "aiff":
            return "audio/aiff"
        case "aac":
            return "audio/aac"
        case "flac":
            return "audio/flac"
        default:
            return "audio/mpeg"
        }
    }
}

enum TranscriptionError: Error, LocalizedError {
    case noModelSelected
    case transcriptionCancelled

    var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No transcription model selected"
        case .transcriptionCancelled:
            return "Transcription was cancelled"
        }
    }
}
