import Foundation
import SwiftData
import os

@MainActor
class EnhancedTranscriptionManager: ObservableObject {
    static let shared = EnhancedTranscriptionManager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage = ""
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "EnhancedTranscription")
    
    private init() {}
    
    // MARK: - Re-transcription with Versioning
    
    func retranscribeWithVersioning(
        transcription: Transcription,
        modelContext: ModelContext,
        whisperState: WhisperState
    ) async throws {
        guard let audioURLString = transcription.audioFileURL,
              let audioURL = URL(string: audioURLString),
              FileManager.default.fileExists(atPath: audioURL.path) else {
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
            processingMessage = "Transcribing with \(transcriptionMethod)..."
            processingProgress = 0.3
            
            // Perform transcription
            let newText = try await performTranscription(audioURL: audioURL, whisperState: whisperState)
            processingProgress = 0.8
            
            // Create new version
            let newVersion = TranscriptionVersion(
                text: newText,
                transcriptionMethod: transcriptionMethod,
                promptUsed: getCurrentPrompt(),
                isMainVersion: true // New version becomes main
            )
            
            transcription.addTranscriptionVersion(newVersion)
            
            // Handle enhancement if enabled
            if let enhancementService = whisperState.enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                
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
                } catch {
                    logger.warning("Enhancement failed: \(error.localizedDescription)")
                    // Continue without enhancement
                }
            }
            
            try modelContext.save()
            processingProgress = 1.0
            processingMessage = "Re-transcription completed!"
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingMessage = ""
            }
            
        } catch {
            logger.error("Re-transcription failed: \(error.localizedDescription)")
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
        guard enhancementService.isConfigured else {
            throw EnhancedTranscriptionError.enhancementNotConfigured
        }
        
        // Use specified version or main version
        let targetVersion = versionId != nil 
            ? transcription.transcriptionVersions.first { $0.id == versionId }
            : transcription.mainVersion
        
        guard let version = targetVersion else {
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
            let enhancedText = try await enhancementService.enhance(version.text)
            
            let enhancementVersion = EnhancementVersion(
                enhancedText: enhancedText,
                enhancementMethod: "AI Enhancement",
                baseVersionId: version.id
            )
            
            transcription.addEnhancementVersion(enhancementVersion)
            try modelContext.save()
            
            processingMessage = "Enhancement completed!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingMessage = ""
            }
            
        } catch {
            logger.error("Enhancement failed: \(error.localizedDescription)")
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
            guard let currentModel = whisperState.currentModel else {
                throw EnhancedTranscriptionError.noModelSelected
            }
            
            let whisperContext = try await WhisperContext.createContext(path: currentModel.url.path)
            let audioProcessor = AudioProcessor()
            let samples = try await audioProcessor.processAudioToSamples(audioURL)
            
            await whisperContext.setPrompt(whisperState.whisperPrompt.transcriptionPrompt)
            try await whisperContext.fullTranscribe(samples: samples)
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
