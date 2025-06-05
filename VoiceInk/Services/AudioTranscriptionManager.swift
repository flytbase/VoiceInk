import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import os

@MainActor
class AudioTranscriptionManager: ObservableObject {
    static let shared = AudioTranscriptionManager()
    
    @Published var isProcessing = false
    @Published var processingPhase: ProcessingPhase = .idle
    @Published var currentTranscription: Transcription?
    @Published var messageLog: String = ""
    @Published var errorMessage: String?
    
    private var currentTask: Task<Void, Error>?
    private var whisperContext: WhisperContext?
    private let audioProcessor = AudioProcessor()
    private let loggingService: LoggingService
    
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
    
    func startProcessing(url: URL, modelContext: ModelContext, whisperState: WhisperState) {
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
                "source": "AudioTranscriptionManager"
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
                // Check if Gemini transcription is enabled and configured
                let geminiTranscription = GeminiAudioTranscription.shared
                if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
                    loggingService.debug(
                        "Using Gemini transcription path",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "method": "Gemini",
                            "source": "AudioTranscriptionManager"
                        ]
                    )
                    
                    // Use Gemini instead of Whisper
                    processingPhase = .transcribing
                    let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "auto"
                    var text = try await geminiTranscription.transcribe(audioURL: url, language: selectedLanguage)
                    
                    // Get audio duration
                    let audioAsset = AVURLAsset(url: url)
                    let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))
                    
                    loggingService.debug(
                        "Audio metadata extracted",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "duration": "\(duration)s",
                            "text_length": "\(text.count)",
                            "source": "AudioTranscriptionManager"
                        ]
                    )
                    
                    // Create permanent copy of the audio file
                    let recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("com.prakashjoshipax.VoiceInk")
                        .appendingPathComponent("Recordings")
                    
                    let fileName = "transcribed_\(UUID().uuidString).wav"
                    let permanentURL = recordingsDirectory.appendingPathComponent(fileName)
                    
                    try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: permanentURL)
                    
                    loggingService.debug(
                        "Audio file copied to permanent storage",
                        category: .fileSystem,
                        context: [
                            "session_id": sessionId,
                            "permanent_path": permanentURL.path,
                            "source": "AudioTranscriptionManager"
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
                                "source": "AudioTranscriptionManager"
                            ]
                        )
                    }
                    
                    // Handle enhancement if enabled
                    if let enhancementService = whisperState.enhancementService,
                       enhancementService.isEnhancementEnabled,
                       enhancementService.isConfigured {
                        
                        loggingService.debug(
                            "Starting AI enhancement",
                            category: .enhancement,
                            context: [
                                "session_id": sessionId,
                                "text_length": "\(text.count)",
                                "source": "AudioTranscriptionManager"
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
                                "Transcription with enhancement completed successfully",
                                category: .enhancement,
                                context: [
                                    "session_id": sessionId,
                                    "transcription_id": transcription.id.uuidString,
                                    "enhanced_text_length": "\(enhancedText.count)",
                                    "source": "AudioTranscriptionManager"
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
                                    "source": "AudioTranscriptionManager"
                                ]
                            )
                            messageLog += "Enhancement failed: \(error.localizedDescription). Using original transcription.\n"
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
                            "Transcription completed successfully (no enhancement)",
                            category: .transcription,
                            context: [
                                "session_id": sessionId,
                                "transcription_id": transcription.id.uuidString,
                                "text_length": "\(text.count)",
                                "source": "AudioTranscriptionManager"
                            ]
                        )
                    }
                    
                    processingPhase = .completed
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await finishProcessing()
                    
                    let totalProcessingTime = Date().timeIntervalSince(startTime)
                    loggingService.info(
                        "Gemini transcription session completed",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "total_processing_time": String(format: "%.2f", totalProcessingTime),
                            "method": "Gemini",
                            "source": "AudioTranscriptionManager"
                        ]
                    )
                    return
                }
                
                // Continue with Whisper transcription
                loggingService.debug(
                    "Using Whisper transcription path",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "method": "Whisper",
                        "source": "AudioTranscriptionManager"
                    ]
                )
                
                guard let currentModel = whisperState.currentModel else {
                    loggingService.error(
                        "Whisper transcription failed: No model selected",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "source": "AudioTranscriptionManager"
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
                        "source": "AudioTranscriptionManager"
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
                        "source": "AudioTranscriptionManager"
                    ]
                )
                
                // Get audio duration
                let audioAsset = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))
                
                // Create permanent copy of the audio file
                let recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("com.prakashjoshipax.VoiceInk")
                    .appendingPathComponent("Recordings")
                
                let fileName = "transcribed_\(UUID().uuidString).wav"
                let permanentURL = recordingsDirectory.appendingPathComponent(fileName)
                
                try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: url, to: permanentURL)
                
                loggingService.debug(
                    "Audio file copied to permanent storage",
                    category: .fileSystem,
                    context: [
                        "session_id": sessionId,
                        "permanent_path": permanentURL.path,
                        "source": "AudioTranscriptionManager"
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
                        "source": "AudioTranscriptionManager"
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
                            "source": "AudioTranscriptionManager"
                        ]
                    )
                }
                
                // Handle enhancement if enabled
                if let enhancementService = whisperState.enhancementService,
                   enhancementService.isEnhancementEnabled,
                   enhancementService.isConfigured {
                    
                    loggingService.debug(
                        "Starting AI enhancement",
                        category: .enhancement,
                        context: [
                            "session_id": sessionId,
                            "text_length": "\(text.count)",
                            "source": "AudioTranscriptionManager"
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
                                "source": "AudioTranscriptionManager"
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
                                "source": "AudioTranscriptionManager"
                            ]
                        )
                        messageLog += "Enhancement failed: \(error.localizedDescription). Using original transcription.\n"
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
                            "source": "AudioTranscriptionManager"
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
                        "source": "AudioTranscriptionManager"
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
                "source": "AudioTranscriptionManager"
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
