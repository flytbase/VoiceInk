import Foundation

struct TranscriptionPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var prompt: String
    var isDefault: Bool
    
    init(id: UUID = UUID(), name: String, prompt: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.isDefault = isDefault
    }
    
    // Default transcription prompts
    static let defaultPrompts: [TranscriptionPrompt] = [
        TranscriptionPrompt(
            name: "Basic Transcription",
            prompt: "Please transcribe the following audio file accurately in the original language. Provide only the transcribed text without any additional commentary or formatting.",
            isDefault: true
        ),
        TranscriptionPrompt(
            name: "Translate to English",
            prompt: "Please transcribe the following audio file accurately and translate the transcription to English. Always provide the output in English regardless of the original audio language. Provide only the English transcribed text without any additional commentary, formatting, or language indicators.",
            isDefault: true
        ),
        TranscriptionPrompt(
            name: "Meeting Notes",
            prompt: "Please transcribe the following audio file and format it as structured meeting notes. Translate to English and organize the content with key points, decisions, and action items. Provide clear, readable meeting notes format.",
            isDefault: true
        ),
        TranscriptionPrompt(
            name: "Technical Documentation",
            prompt: "Please transcribe the following audio file with focus on technical accuracy. Pay special attention to technical terms, acronyms, and precise terminology. Translate to English while preserving technical accuracy and context.",
            isDefault: true
        )
    ]
    
    // Default selected prompt (Translate to English)
    static var defaultSelectedPrompt: TranscriptionPrompt {
        return defaultPrompts.first { $0.name == "Translate to English" } ?? defaultPrompts[0]
    }
}
