import Foundation
import SwiftData

@Model
final class Transcription {
    var id: UUID
    var text: String
    var enhancedText: String?
    var timestamp: Date
    var duration: TimeInterval
    var audioFileURL: String?
    var audioContext: String?
    
    // Version Management Properties
    var transcriptionVersions: [TranscriptionVersion] = []
    var enhancementVersions: [EnhancementVersion] = []
    var mainVersionId: UUID?
    
    init(text: String, duration: TimeInterval, enhancedText: String? = nil, audioFileURL: String? = nil, audioContext: String? = nil) {
        self.id = UUID()
        self.text = text
        self.enhancedText = enhancedText
        self.timestamp = Date()
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.audioContext = audioContext
    }
    
    // MARK: - Computed Properties
    
    var mainVersion: TranscriptionVersion? {
        return transcriptionVersions.first { $0.isMainVersion } ?? transcriptionVersions.first
    }
    
    var latestVersion: TranscriptionVersion? {
        return transcriptionVersions.max { $0.createdAt < $1.createdAt }
    }
    
    var hasMultipleVersions: Bool {
        return transcriptionVersions.count > 1
    }
    
    var latestEnhancement: EnhancementVersion? {
        return enhancementVersions.max { $0.createdAt < $1.createdAt }
    }
    
    // MARK: - Helper Methods
    
    func addTranscriptionVersion(_ version: TranscriptionVersion) {
        transcriptionVersions.append(version)
        
        // If this is the first version or marked as main, update mainVersionId
        if transcriptionVersions.count == 1 || version.isMainVersion {
            mainVersionId = version.id
            // Ensure only one main version
            transcriptionVersions.forEach { $0.isMainVersion = ($0.id == version.id) }
        }
    }
    
    func addEnhancementVersion(_ version: EnhancementVersion) {
        enhancementVersions.append(version)
    }
    
    func setMainVersion(_ versionId: UUID) {
        transcriptionVersions.forEach { $0.isMainVersion = ($0.id == versionId) }
        mainVersionId = versionId
    }
}
