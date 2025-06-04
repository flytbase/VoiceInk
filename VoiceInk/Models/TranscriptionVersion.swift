import Foundation
import SwiftData

@Model
final class TranscriptionVersion {
    var id: UUID
    var text: String
    var createdAt: Date
    var transcriptionMethod: String // "Whisper Tiny", "Gemini 2.5 Pro", etc.
    var promptUsed: String?
    var isMainVersion: Bool
    var confidence: Double? // Optional confidence score
    
    // Relationship will be handled by Transcription model
    // var parentTranscription: Transcription?
    
    init(
        text: String,
        transcriptionMethod: String,
        promptUsed: String? = nil,
        isMainVersion: Bool = false,
        confidence: Double? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
        self.transcriptionMethod = transcriptionMethod
        self.promptUsed = promptUsed
        self.isMainVersion = isMainVersion
        self.confidence = confidence
    }
}
