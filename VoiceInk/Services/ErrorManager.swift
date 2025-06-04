import SwiftUI
import Foundation

// MARK: - Error Types

enum VoiceInkError: LocalizedError, Equatable {
    case transcriptionFailed(String)
    case enhancementFailed(String)
    case audioNotFound
    case audioDownloadFailed(String)
    case viewModelInitializationFailed
    case searchIndexingFailed
    case migrationFailed(String)
    case networkError(String)
    case fileSystemError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .enhancementFailed(let message):
            return "Enhancement failed: \(message)"
        case .audioNotFound:
            return "Audio file not found. The file may have been moved or deleted."
        case .audioDownloadFailed(let message):
            return "Audio download failed: \(message)"
        case .viewModelInitializationFailed:
            return "Failed to initialize component. Please try again."
        case .searchIndexingFailed:
            return "Search indexing failed. Search functionality may be limited."
        case .migrationFailed(let message):
            return "Data migration failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .transcriptionFailed:
            return "Check your audio file and try re-transcribing."
        case .enhancementFailed:
            return "Verify your AI enhancement settings and try again."
        case .audioNotFound:
            return "Check if the audio file exists and try downloading it again."
        case .audioDownloadFailed:
            return "Check your internet connection and try downloading again."
        case .viewModelInitializationFailed:
            return "Restart the application if the problem persists."
        case .searchIndexingFailed:
            return "Restart the application to rebuild the search index."
        case .migrationFailed:
            return "Contact support if this error persists."
        case .networkError:
            return "Check your internet connection and try again."
        case .fileSystemError:
            return "Check available storage space and file permissions."
        case .unknown:
            return "Try restarting the application."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .transcriptionFailed, .enhancementFailed:
            return .medium
        case .audioNotFound, .audioDownloadFailed:
            return .medium
        case .viewModelInitializationFailed, .migrationFailed:
            return .high
        case .searchIndexingFailed:
            return .low
        case .networkError, .fileSystemError:
            return .medium
        case .unknown:
            return .high
        }
    }
}

enum ErrorSeverity {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "exclamationmark.triangle"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.circle.fill"
        }
    }
}

// MARK: - Error Manager

@MainActor
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: VoiceInkError?
    @Published var showingError = false
    @Published var errorHistory: [ErrorEntry] = []
    
    private let maxHistoryCount = 50
    
    private init() {}
    
    // MARK: - Error Handling
    
    func handle(_ error: Error, context: String = "") {
        let voiceInkError = mapToVoiceInkError(error, context: context)
        handle(voiceInkError)
    }
    
    func handle(_ error: VoiceInkError) {
        currentError = error
        showingError = true
        
        // Add to history
        let entry = ErrorEntry(
            error: error,
            timestamp: Date(),
            context: getCurrentContext()
        )
        errorHistory.insert(entry, at: 0)
        
        // Limit history size
        if errorHistory.count > maxHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxHistoryCount))
        }
        
        // Log error for debugging
        logError(error, entry: entry)
    }
    
    func clearCurrentError() {
        currentError = nil
        showingError = false
    }
    
    func clearHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Error Mapping
    
    private func mapToVoiceInkError(_ error: Error, context: String) -> VoiceInkError {
        if let voiceInkError = error as? VoiceInkError {
            return voiceInkError
        }
        
        // Map common system errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return .networkError(nsError.localizedDescription)
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError {
                    return .audioNotFound
                }
                return .fileSystemError(nsError.localizedDescription)
            default:
                return .unknown("\(context): \(error.localizedDescription)")
            }
        }
        
        return .unknown("\(context): \(error.localizedDescription)")
    }
    
    // MARK: - Context & Logging
    
    private func getCurrentContext() -> String {
        // Simple context detection - could be enhanced with more sophisticated tracking
        return "VoiceInk App"
    }
    
    private func logError(_ error: VoiceInkError, entry: ErrorEntry) {
        print("🚨 VoiceInk Error [\(error.severity)]:")
        print("   Error: \(error.localizedDescription)")
        print("   Context: \(entry.context)")
        print("   Time: \(entry.timestamp)")
        if let suggestion = error.recoverySuggestion {
            print("   Suggestion: \(suggestion)")
        }
        print("---")
    }
}

// MARK: - Error Entry

struct ErrorEntry: Identifiable {
    let id = UUID()
    let error: VoiceInkError
    let timestamp: Date
    let context: String
}

// MARK: - Error Display Components

struct ErrorAlert: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorManager.showingError) {
                Button("OK") {
                    errorManager.clearCurrentError()
                }
                
                if let error = errorManager.currentError,
                   error.recoverySuggestion != nil {
                    Button("Help") {
                        // Could open help documentation
                    }
                }
            } message: {
                if let error = errorManager.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription)
                        
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }
}

struct ErrorBanner: View {
    let error: VoiceInkError
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.severity.icon)
                .foregroundColor(error.severity.color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(error.localizedDescription)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(error.severity.color.opacity(0.1))
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - View Extensions

extension View {
    func errorHandling(_ errorManager: ErrorManager = ErrorManager.shared) -> some View {
        self.modifier(ErrorAlert(errorManager: errorManager))
    }
}

// MARK: - Error History View

struct ErrorHistoryView: View {
    @ObservedObject var errorManager = ErrorManager.shared
    
    var body: some View {
        NavigationView {
            List {
                if errorManager.errorHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("No Errors")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Everything is working smoothly!")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(errorManager.errorHistory) { entry in
                        ErrorHistoryRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Error History")
            .toolbar {
                if !errorManager.errorHistory.isEmpty {
                    Button("Clear") {
                        errorManager.clearHistory()
                    }
                }
            }
        }
    }
}

struct ErrorHistoryRow: View {
    let entry: ErrorEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.error.severity.icon)
                    .foregroundColor(entry.error.severity.color)
                
                Text(entry.error.localizedDescription)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let suggestion = entry.error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            }
            
            Text("Context: \(entry.context)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(.vertical, 4)
    }
}
