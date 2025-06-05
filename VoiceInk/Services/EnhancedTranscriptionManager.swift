import Foundation
import SwiftData
import SwiftUI
import os

class EnhancedTranscriptionManager: ObservableObject {
    static let shared = EnhancedTranscriptionManager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage = ""
    @Published var errorMessage: String?
    
    private let loggingService: LoggingService
    
    private init(loggingService: LoggingService = LoggingService.shared) {
        self.loggingService = loggingService
    }
    
    // MARK: - Re-transcription with Versioning
    
    func retranscribeWithVersioning(
        transcription: Transcription,
        modelContext: ModelContext,
        whisperState: WhisperState
    ) async throws {
        let startTime = Date()
        let transcriptionId = transcription.id.uuidString
        
        // Log start of re-transcription
        loggingService.info(
            "Starting re-transcription with versioning",
            category: .transcription,
            context: [
                "transcription_id": transcriptionId,
                "original_text_length": "\(transcription.text.count)",
                "duration": "\(transcription.duration)s",
                "existing_versions": "\(transcription.transcriptionVersions.count)",
                "source": "EnhancedTranscriptionManager"
            ]
        )
        
        guard let audioURLString = transcription.audioFileURL,
              let audioURL = URL(string: audioURLString),
              FileManager.default.fileExists(atPath: audioURL.path) else {
            loggingService.error(
                "Re-transcription failed: Audio file not found",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "audio_url": transcription.audioFileURL ?? "nil",
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            throw EnhancedTranscriptionError.audioFileNotFound
        }
        
        isProcessing = true
        processingProgress = 0.0
        processingMessage = "Starting re-transcription..."
        errorMessage = nil
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
        }
        
        do {
            // Determine current transcription method
            let transcriptionMethod = getCurrentTranscriptionMethod()
            loggingService.debug(
                "Selected transcription method",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "method": transcriptionMethod,
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            
            processingMessage = "Transcribing with \(transcriptionMethod)..."
            processingProgress = 0.3
            
            // Perform transcription
            let newText = try await performTranscription(audioURL: audioURL, whisperState: whisperState)
            processingProgress = 0.8
            
            loggingService.debug(
                "Transcription completed, creating new version",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "new_text_length": "\(newText.count)",
                    "method": transcriptionMethod,
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            
            // Create new version
            let newVersion = TranscriptionVersion(
                text: newText,
                transcriptionMethod: transcriptionMethod,
                promptUsed: getCurrentPrompt(),
                isMainVersion: true // New version becomes main
            )
            
            transcription.addTranscriptionVersion(newVersion)
            
            // Handle enhancement if enabled
            if let enhancementService = await whisperState.enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                
                loggingService.debug(
                    "Starting AI enhancement for new version",
                    category: .enhancement,
                    context: [
                        "transcription_id": transcriptionId,
                        "version_id": newVersion.id.uuidString,
                        "text_length": "\(newText.count)",
                        "source": "EnhancedTranscriptionManager"
                    ]
                )
                
                processingMessage = "Enhancing transcription..."
                processingProgress = 0.9
                
                do {
                    let enhancedText = try await enhancementService.enhance(newText)
                    let enhancementVersion = EnhancementVersion(
                        enhancedText: enhancedText,
                        enhancementMethod: "AI Enhancement",
                        baseVersionId: newVersion.id
                    )
                    transcription.addEnhancementVersion(enhancementVersion)
                    
                    loggingService.info(
                        "Enhancement completed successfully",
                        category: .enhancement,
                        context: [
                            "transcription_id": transcriptionId,
                            "version_id": newVersion.id.uuidString,
                            "enhanced_text_length": "\(enhancedText.count)",
                            "source": "EnhancedTranscriptionManager"
                        ]
                    )
                } catch {
                    loggingService.warning(
                        "Enhancement failed, continuing without enhancement",
                        category: .enhancement,
                        context: [
                            "transcription_id": transcriptionId,
                            "version_id": newVersion.id.uuidString,
                            "error_domain": (error as NSError).domain,
                            "error_code": "\((error as NSError).code)",
                            "source": "EnhancedTranscriptionManager"
                        ]
                    )
                    // Continue without enhancement
                }
            }
            
            try modelContext.save()
            processingProgress = 1.0
            processingMessage = "Re-transcription completed!"
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.info(
                "Re-transcription with versioning completed successfully",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "method": transcriptionMethod,
                    "new_versions_count": "\(transcription.transcriptionVersions.count)",
                    "total_enhancements": "\(transcription.enhancementVersions.count)",
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingMessage = ""
            }
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.error(
                "Re-transcription with versioning failed",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)",
                    "source": "EnhancedTranscriptionManager"
                ],
                error: error
            )
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Historical Enhancement
    
    func enhanceHistoricalTranscription(
        transcription: Transcription,
        versionId: UUID? = nil,
        modelContext: ModelContext,
        enhancementService: AIEnhancementService
    ) async throws {
        let startTime = Date()
        let transcriptionId = transcription.id.uuidString
        
        loggingService.info(
            "Starting historical transcription enhancement",
            category: .enhancement,
            context: [
                "transcription_id": transcriptionId,
                "version_id": versionId?.uuidString ?? "main",
                "existing_enhancements": "\(transcription.enhancementVersions.count)",
                "source": "EnhancedTranscriptionManager"
            ]
        )
        
        guard enhancementService.isConfigured else {
            loggingService.error(
                "Enhancement failed: Service not configured",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            throw EnhancedTranscriptionError.enhancementNotConfigured
        }
        
        // Use specified version or main version
        let targetVersion = versionId != nil 
            ? transcription.transcriptionVersions.first { $0.id == versionId }
            : transcription.mainVersion
        
        guard let version = targetVersion else {
            loggingService.error(
                "Enhancement failed: No version found",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "requested_version_id": versionId?.uuidString ?? "main",
                    "available_versions": "\(transcription.transcriptionVersions.count)",
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            throw EnhancedTranscriptionError.noVersionFound
        }
        
        isProcessing = true
        processingMessage = "Enhancing transcription..."
        errorMessage = nil
        
        defer {
            isProcessing = false
            processingMessage = ""
        }
        
        do {
            loggingService.debug(
                "Starting enhancement process",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "version_id": version.id.uuidString,
                    "text_length": "\(version.text.count)",
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            
            let enhancedText = try await enhancementService.enhance(version.text)
            
            let enhancementVersion = EnhancementVersion(
                enhancedText: enhancedText,
                enhancementMethod: "AI Enhancement",
                baseVersionId: version.id
            )
            
            transcription.addEnhancementVersion(enhancementVersion)
            try modelContext.save()
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.info(
                "Historical transcription enhancement completed successfully",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "version_id": version.id.uuidString,
                    "enhanced_text_length": "\(enhancedText.count)",
                    "processing_time": String(format: "%.2f", processingTime),
                    "total_enhancements": "\(transcription.enhancementVersions.count)",
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            
            processingMessage = "Enhancement completed!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingMessage = ""
            }
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.error(
                "Historical transcription enhancement failed",
                category: .enhancement,
                context: [
                    "transcription_id": transcriptionId,
                    "version_id": version.id.uuidString,
                    "processing_time": String(format: "%.2f", processingTime),
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)",
                    "source": "EnhancedTranscriptionManager"
                ],
                error: error
            )
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTranscriptionMethod() -> String {
        let geminiTranscription = GeminiAudioTranscription.shared
        if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
            return "Gemini 2.5 Pro"
        } else {
            // Get current Whisper model name
            return UserDefaults.standard.string(forKey: "CurrentWhisperModel") ?? "Whisper"
        }
    }
    
    private func getCurrentPrompt() -> String? {
        let geminiTranscription = GeminiAudioTranscription.shared
        if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
            // Get current transcription prompt if using cloud
            return TranscriptionPromptService().selectedPrompt?.prompt
        }
        return nil
    }
    
    private func performTranscription(audioURL: URL, whisperState: WhisperState) async throws -> String {
        let geminiTranscription = GeminiAudioTranscription.shared
        
        if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
            // Use Gemini transcription
            let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "auto"
            var text = try await geminiTranscription.transcribe(audioURL: audioURL, language: selectedLanguage)
            
            // Apply word replacements if enabled
            if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                text = WordReplacementService.shared.applyReplacements(to: text)
            }
            
            return text
        } else {
            // Use Whisper transcription
            guard let currentModel = await whisperState.currentModel else {
                throw EnhancedTranscriptionError.noModelSelected
            }
            
            let whisperContext = try await WhisperContext.createContext(path: currentModel.url.path)
            let audioProcessor = AudioProcessor()
            let samples = try await audioProcessor.processAudioToSamples(audioURL)
            
            await whisperContext.setPrompt(whisperState.whisperPrompt.transcriptionPrompt)
            await whisperContext.fullTranscribe(samples: samples)
            var text = await whisperContext.getTranscription()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = WhisperTextFormatter.format(text)
            
            // Apply word replacements if enabled
            if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                text = WordReplacementService.shared.applyReplacements(to: text)
            }
            
            return text
        }
    }
}

enum EnhancedTranscriptionError: LocalizedError {
    case audioFileNotFound
    case noModelSelected
    case enhancementNotConfigured
    case noVersionFound
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "Audio file not found"
        case .noModelSelected:
            return "No transcription model selected"
        case .enhancementNotConfigured:
            return "Enhancement service not configured"
        case .noVersionFound:
            return "No transcription version found"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
