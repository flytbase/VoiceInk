import Foundation

// MARK: - Gemini SSE Response Models

/// Root response object for Gemini SSE streaming
struct GeminiSSEResponse: Codable {
    let candidates: [GeminiCandidate]
    let usageMetadata: GeminiUsageMetadata?
    let modelVersion: String?
    let responseId: String?
}

/// Individual candidate in Gemini response
struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
}

/// Content wrapper with parts and role
struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String
}

/// Text container part
struct GeminiPart: Codable {
    let text: String
}

/// Usage metadata for token counting
struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
    let promptTokensDetails: [GeminiTokenDetail]?
    let candidatesTokensDetails: [GeminiTokenDetail]?
}

/// Token detail for specific modality
struct GeminiTokenDetail: Codable {
    let modality: String
    let tokenCount: Int
}

// MARK: - Core Data Models

/// Represents an uploaded file in Gemini's Files API
struct UploadedFile {
    let name: String
    let uri: String        // Format: "files/{fileId}"
    let mimeType: String
    let sizeBytes: String
    let uploadTimestamp: Date
}

/// Represents a chunk of transcription text received during streaming
struct TranscriptionChunk {
    let text: String
    let isComplete: Bool
    let timestamp: String?
    let confidence: Double?
    let chunkIndex: Int
    let usageMetadata: GeminiUsageMetadata?
    
    init(
        text: String,
        isComplete: Bool,
        timestamp: String? = nil,
        confidence: Double? = nil,
        chunkIndex: Int,
        usageMetadata: GeminiUsageMetadata? = nil
    ) {
        self.text = text
        self.isComplete = isComplete
        self.timestamp = timestamp
        self.confidence = confidence
        self.chunkIndex = chunkIndex
        self.usageMetadata = usageMetadata
    }
}

/// Analysis results for audio file characteristics
struct AudioAnalysis {
    let originalSize: Int64
    let duration: TimeInterval
    let sampleRate: Int
    let channels: Int
    let bitrate: Int
    let needsOptimization: Bool
    let estimatedOptimizedSize: Int64
    let compressionRatio: Double
    
    /// Human-readable description of the analysis
    var description: String {
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useMB, .useKB]
        sizeFormatter.countStyle = .file
        
        let originalSizeStr = sizeFormatter.string(fromByteCount: originalSize)
        let optimizedSizeStr = sizeFormatter.string(fromByteCount: estimatedOptimizedSize)
        
        return """
        Original: \(originalSizeStr), \(Int(duration))s, \(sampleRate)Hz, \(channels)ch
        Optimized: \(optimizedSizeStr) (\(Int(compressionRatio * 100))% of original)
        """
    }
}

// MARK: - Progress Tracking

/// Detailed progress information for streaming transcription
struct StreamingProgress {
    let currentChunk: Int
    let totalChunks: Int
    let overallProgress: Double
    let estimatedTimeRemaining: Double
    let currentText: String
    let processingSpeed: Double
    
    init(
        currentChunk: Int = 0,
        totalChunks: Int = 0,
        overallProgress: Double = 0.0,
        estimatedTimeRemaining: Double = 0.0,
        currentText: String = "",
        processingSpeed: Double = 0.0
    ) {
        self.currentChunk = currentChunk
        self.totalChunks = totalChunks
        self.overallProgress = max(0.0, min(1.0, overallProgress))
        self.estimatedTimeRemaining = max(0.0, estimatedTimeRemaining)
        self.currentText = currentText
        self.processingSpeed = max(0.0, processingSpeed)
    }
}

/// Represents the current state of streaming transcription process
enum StreamingState: Equatable {
    case idle
    case preprocessing(progress: Double)
    case uploading(progress: Double)
    case streaming(progress: Double, liveText: String)
    case finalizing
    case complete
    case error(String)
    
    /// User-friendly message for the current progress state
    var message: String {
        switch self {
        case .idle:
            return ""
        case .preprocessing(let progress):
            return "Optimizing audio for Gemini (16kbps mono)... \(Int(progress * 100))%"
        case .uploading(let progress):
            return "Uploading to Gemini Files API... \(Int(progress * 100))%"
        case .streaming(let progress, _):
            return "Streaming transcription with Gemini 2.5 Pro... \(Int(progress * 100))%"
        case .finalizing:
            return "Finalizing and cleaning up..."
        case .complete:
            return "Transcription completed!"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    /// Whether the process is currently active
    var isProcessing: Bool {
        switch self {
        case .idle, .complete, .error:
            return false
        default:
            return true
        }
    }
    
    /// Overall progress as a percentage (0.0 to 1.0)
    var overallProgress: Double {
        switch self {
        case .idle:
            return 0.0
        case .preprocessing(let progress):
            return progress * 0.2  // Preprocessing is 20% of total
        case .uploading(let progress):
            return 0.2 + (progress * 0.2)  // Upload is 20% of total
        case .streaming(let progress, _):
            return 0.4 + (progress * 0.5)  // Streaming is 50% of total
        case .finalizing:
            return 0.9  // Finalizing is 10% of total
        case .complete:
            return 1.0
        case .error:
            return 0.0
        }
    }
}

// MARK: - Error Types

/// Comprehensive error types for streaming transcription
enum StreamingError: LocalizedError {
    case preprocessingFailed(String)
    case uploadFailed(String)
    case streamingFailed(String)
    case cleanupFailed(String)
    case invalidAudioFormat
    case fileTooLarge(Int64)
    case networkError(Error)
    case apiKeyInvalid
    case rateLimited
    case quotaExceeded
    case modelUnavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .preprocessingFailed(let message):
            return "Audio preprocessing failed: \(message)"
        case .uploadFailed(let message):
            return "File upload failed: \(message)"
        case .streamingFailed(let message):
            return "Streaming transcription failed: \(message)"
        case .cleanupFailed(let message):
            return "File cleanup failed: \(message)"
        case .invalidAudioFormat:
            return "Unsupported audio format"
        case .fileTooLarge(let size):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return "File too large: \(formatter.string(fromByteCount: size))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiKeyInvalid:
            return "Invalid Gemini API key"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .quotaExceeded:
            return "API quota exceeded. Please check your Gemini usage."
        case .modelUnavailable:
            return "Gemini 2.5 Pro model is currently unavailable"
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
    
    /// Suggested recovery action for the user
    var recoveryAction: String? {
        switch self {
        case .preprocessingFailed:
            return "Try a different audio format or check file integrity"
        case .uploadFailed, .networkError:
            return "Check internet connection and try again"
        case .streamingFailed:
            return "Try again or use traditional transcription mode"
        case .invalidAudioFormat:
            return "Convert to supported format (WAV, MP3, M4A, AIFF)"
        case .fileTooLarge:
            return "Compress audio file or split into smaller segments"
        case .apiKeyInvalid:
            return "Check Gemini API key in settings"
        case .rateLimited:
            return "Wait a few minutes before trying again"
        case .quotaExceeded:
            return "Check your Gemini API usage and billing"
        case .modelUnavailable:
            return "Try again later or use traditional transcription"
        case .timeout:
            return "Check connection and try again"
        case .cleanupFailed:
            return "File may remain on Gemini servers temporarily"
        }
    }
    
    /// Whether this error should trigger automatic fallback to traditional transcription
    var shouldFallbackToTraditional: Bool {
        switch self {
        case .apiKeyInvalid, .quotaExceeded, .modelUnavailable, .rateLimited:
            return true
        case .fileTooLarge, .invalidAudioFormat:
            return false
        case .preprocessingFailed, .uploadFailed, .streamingFailed, .networkError, .timeout:
            return true
        case .cleanupFailed:
            return false  // Cleanup failure doesn't affect transcription
        }
    }
}

// MARK: - Configuration

/// Configuration options for streaming transcription
struct StreamingConfiguration {
    // streamingThreshold removed - streaming used for all Gemini transcriptions when enabled
    
    /// Maximum file size supported by streaming (in bytes)
    static var maxFileSize: Int64 {
        let maxFileSizeMB = UserDefaults.standard.double(forKey: "streamingMaxFileSize")
        let defaultValue = maxFileSizeMB > 0 ? maxFileSizeMB : 500.0
        return Int64(defaultValue * 1024 * 1024)
    }
    
    /// Target bitrate for audio optimization (bits per second) - hardcoded
    static let targetBitrate: Int = 16000  // 16kbps
    
    /// Target sample rate for audio optimization (Hz) - hardcoded
    static let targetSampleRate: Int = 16000  // 16kHz
    
    /// Target channel count for audio optimization - hardcoded
    static let targetChannels: Int = 1  // Mono
    
    /// Timeout for file upload (seconds)
    static var uploadTimeout: TimeInterval {
        let timeout = UserDefaults.standard.double(forKey: "streamingUploadTimeout")
        return timeout > 0 ? timeout : 300.0
    }
    
    /// Timeout for streaming transcription (seconds)
    static var streamingTimeout: TimeInterval {
        let timeout = UserDefaults.standard.double(forKey: "streamingTranscriptionTimeout")
        return timeout > 0 ? timeout : 600.0
    }
    
    /// Timeout for file cleanup (seconds) - hardcoded
    static let cleanupTimeout: TimeInterval = 30  // 30 seconds
    
    /// Whether to show live text during streaming
    static var showLiveText: Bool {
        // Check if the key exists, if not return default value of true
        if UserDefaults.standard.object(forKey: "streamingShowLiveText") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "streamingShowLiveText")
    }
    
    /// Whether to use streaming mode
    static var streamingEnabled: Bool {
        // Check if the key exists, if not return default value of true
        let keyExists = UserDefaults.standard.object(forKey: "streamingEnabled") != nil
        let value: Bool
        
        if keyExists {
            value = UserDefaults.standard.bool(forKey: "streamingEnabled")
            print("🔧 [StreamingConfiguration] streamingEnabled key EXISTS, value: \(value)")
        } else {
            value = true
            print("🔧 [StreamingConfiguration] streamingEnabled key MISSING, using default: \(value)")
        }
        
        return value
    }
    
    /// Whether to preprocess audio before streaming
    static var preprocessAudio: Bool {
        // Check if the key exists, if not return default value of true
        if UserDefaults.standard.object(forKey: "streamingPreprocessAudio") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "streamingPreprocessAudio")
    }
    
    /// Progress update interval for UI updates
    static var progressUpdateInterval: TimeInterval {
        let interval = UserDefaults.standard.double(forKey: "streamingProgressUpdateInterval")
        return interval > 0 ? interval : 0.1
    }
}

// MARK: - Helper Extensions

extension StreamingState {
    /// Creates a preprocessing progress state
    static func preprocessing(_ progress: Double) -> StreamingState {
        return .preprocessing(progress: max(0.0, min(1.0, progress)))
    }
    
    /// Creates an uploading progress state
    static func uploading(_ progress: Double) -> StreamingState {
        return .uploading(progress: max(0.0, min(1.0, progress)))
    }
    
    /// Creates a streaming progress state with live text
    static func streaming(_ progress: Double, _ liveText: String) -> StreamingState {
        return .streaming(progress: max(0.0, min(1.0, progress)), liveText: liveText)
    }
}

extension AudioAnalysis {
    /// Determines if the audio file would benefit from optimization
    static func shouldOptimize(
        fileSize: Int64,
        sampleRate: Int,
        channels: Int,
        duration: TimeInterval
    ) -> Bool {
        // Optimize if:
        // 1. File is larger than 10MB
        // 2. Sample rate is higher than 16kHz
        // 3. More than 1 channel (stereo)
        // 4. Estimated bitrate is higher than 32kbps
        
        let fileSizeThreshold: Int64 = 10 * 1024 * 1024 // 10MB
        let estimatedBitrate = duration > 0 ? (fileSize * 8) / Int64(duration) : 0 // bits per second
        
        return fileSize > fileSizeThreshold ||
               sampleRate > StreamingConfiguration.targetSampleRate ||
               channels > StreamingConfiguration.targetChannels ||
               estimatedBitrate > 32000
    }
    
    /// Calculates estimated file size after optimization
    static func estimateOptimizedSize(duration: TimeInterval, targetBitrate: Int) -> Int64 {
        // Calculate size for target bitrate audio
        return Int64((Double(targetBitrate) * duration) / 8.0)
    }
}
