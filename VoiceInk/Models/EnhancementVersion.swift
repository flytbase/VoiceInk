import Foundation
import SwiftData

@Model
final class EnhancementVersion {
    var id: UUID
    var enhancedText: String
    var createdAt: Date
    var enhancementMethod: String // "GPT-4", "Gemini Pro", etc.
    var baseVersionId: UUID // Which transcription version was enhanced
    var enhancementPrompt: String?
    
    // Relationship will be handled by Transcription model
    // var parentTranscription: Transcription?
    
    init(
        enhancedText: String,
        enhancementMethod: String,
        baseVersionId: UUID,
        enhancementPrompt: String? = nil
    ) {
        self.id = UUID()
        self.enhancedText = enhancedText
        self.createdAt = Date()
        self.enhancementMethod = enhancementMethod
        self.baseVersionId = baseVersionId
        self.enhancementPrompt = enhancementPrompt
    }
}
