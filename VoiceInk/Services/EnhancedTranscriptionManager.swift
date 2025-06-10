import Foundation
import SwiftData
import SwiftUI
import os
import AVFoundation

class EnhancedTranscriptionManager: ObservableObject {
    static let shared = EnhancedTranscriptionManager()
    
    // Legacy properties for backward compatibility
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage = ""
    @Published var errorMessage: String?
    
    // New re-transcription specific state
    @Published var isRetranscribing = false
    
    private let loggingService: LoggingService
    private let audioTranscriptionManager = AudioTranscriptionManager.shared
    
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
            "Starting re-transcription with versioning (delegated to AudioTranscriptionManager)",
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
        
        // Set re-transcription state
        isRetranscribing = true
        isProcessing = true
        errorMessage = nil
        
        defer {
            isRetranscribing = false
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
        }
        
        do {
            // Delegate to AudioTranscriptionManager for actual transcription
            // This will use the same rich progress states as the main transcription flow
            await audioTranscriptionManager.transcribeWithStreaming(
                audioURL: audioURL,
                modelContext: modelContext,
                whisperState: whisperState,
                isRetranscription: true,
                originalTranscription: transcription
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            loggingService.info(
                "Re-transcription with versioning completed successfully",
                category: .transcription,
                context: [
                    "transcription_id": transcriptionId,
                    "processing_time": String(format: "%.2f", processingTime),
                    "new_versions_count": "\(transcription.transcriptionVersions.count)",
                    "total_enhancements": "\(transcription.enhancementVersions.count)",
                    "source": "EnhancedTranscriptionManager"
                ]
            )
            
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
            let enhancementMethod = enhancementService.activePrompt?.title ?? "AI Enhancement"
            let enhancementPrompt = enhancementService.activePrompt?.promptText
            
            let enhancementVersion = EnhancementVersion(
                enhancedText: enhancedText,
                enhancementMethod: enhancementMethod,  // Dynamic method name
                baseVersionId: version.id,
                enhancementPrompt: enhancementPrompt
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
    
    // MARK: - Cancellation Support
    
    @MainActor
    func cancelRetranscription() {
        if isRetranscribing {
            audioTranscriptionManager.cancelStreamingProcessing()
            isRetranscribing = false
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
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
