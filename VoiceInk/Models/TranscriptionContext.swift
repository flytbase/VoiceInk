import Foundation

/// Context information for transcription operations to differentiate UI messaging and behavior
enum TranscriptionContext {
    case newTranscription
    case reTranscription
    
    /// User-friendly title for progress displays
    var progressTitle: String {
        switch self {
        case .newTranscription:
            return "Transcribing"
        case .reTranscription:
            return "Re-transcribing"
        }
    }
    
    /// Subtitle for progress displays
    var progressSubtitle: String {
        switch self {
        case .newTranscription:
            return "Processing audio file"
        case .reTranscription:
            return "Creating new version"
        }
    }
    
    /// Completion message
    var completionMessage: String {
        switch self {
        case .newTranscription:
            return "Transcription completed!"
        case .reTranscription:
            return "Re-transcription completed!"
        }
    }
    
    /// Enhancement message
    var enhancementMessage: String {
        switch self {
        case .newTranscription:
            return "Enhancing transcription with AI..."
        case .reTranscription:
            return "Enhancing new version with AI..."
        }
    }
    
    /// Context-aware streaming message
    func streamingMessage(for method: String) -> String {
        switch self {
        case .newTranscription:
            return "Transcribing with \(method)..."
        case .reTranscription:
            return "Re-transcribing with \(method)..."
        }
    }
}
