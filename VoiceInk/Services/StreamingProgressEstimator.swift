import Foundation

/// Service responsible for estimating progress during streaming transcription
class StreamingProgressEstimator {
    private let audioDuration: TimeInterval
    private let startTime: Date
    private var chunksReceived: Int = 0
    private var lastChunkTime: Date
    private var totalTextLength: Int = 0
    
    /// Initialize with the duration of the audio being transcribed
    /// - Parameter audioDuration: Duration of the audio file in seconds
    init(audioDuration: TimeInterval) {
        self.audioDuration = audioDuration
        self.startTime = Date()
        self.lastChunkTime = Date()
    }
    
    /// Estimates the current progress based on a new transcription chunk
    /// - Parameter newChunk: The latest transcription chunk received
    /// - Returns: Estimated progress as a value between 0.0 and 1.0
    func estimateProgress(newChunk: TranscriptionChunk) -> Double {
        chunksReceived += 1
        lastChunkTime = Date()
        totalTextLength += newChunk.text.count
        
        // If chunk indicates completion, return 100%
        if newChunk.isComplete {
            return 1.0
        }
        
        // Estimate progress based on multiple factors
        let timeBasedProgress = calculateTimeBasedProgress()
        let chunkBasedProgress = calculateChunkBasedProgress()
        let textLengthProgress = calculateTextLengthProgress()
        
        // Weighted average of different progress indicators
        // Time-based is most reliable, followed by chunk count, then text length
        let estimatedProgress = (timeBasedProgress * 0.5) + 
                               (chunkBasedProgress * 0.3) + 
                               (textLengthProgress * 0.2)
        
        // Cap at 95% until completion is confirmed to avoid showing 100% prematurely
        return min(estimatedProgress, 0.95)
    }
    
    /// Estimates remaining time based on current progress
    /// - Returns: Estimated remaining time in seconds
    func estimateRemainingTime() -> TimeInterval {
        let elapsedTime = Date().timeIntervalSince(startTime)
        let currentProgress = max(0.01, calculateTimeBasedProgress()) // Avoid division by zero
        
        let estimatedTotalTime = elapsedTime / currentProgress
        return max(0, estimatedTotalTime - elapsedTime)
    }
    
    /// Gets statistics about the current transcription session
    /// - Returns: Dictionary containing various metrics
    func getSessionStatistics() -> [String: Any] {
        let elapsedTime = Date().timeIntervalSince(startTime)
        let chunksPerSecond = elapsedTime > 0 ? Double(chunksReceived) / elapsedTime : 0
        let charactersPerSecond = elapsedTime > 0 ? Double(totalTextLength) / elapsedTime : 0
        
        return [
            "elapsed_time": elapsedTime,
            "chunks_received": chunksReceived,
            "total_text_length": totalTextLength,
            "chunks_per_second": chunksPerSecond,
            "characters_per_second": charactersPerSecond,
            "audio_duration": audioDuration,
            "processing_speed_ratio": audioDuration > 0 ? elapsedTime / audioDuration : 0
        ]
    }
    
    // MARK: - Private Progress Calculation Methods
    
    /// Calculates progress based on elapsed time vs estimated total time
    private func calculateTimeBasedProgress() -> Double {
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Estimate that transcription takes roughly 1/4 to 1/3 of audio duration
        // This varies based on audio complexity and model performance
        let estimatedTranscriptionTime = audioDuration * 0.3
        
        return min(elapsedTime / max(estimatedTranscriptionTime, 1.0), 1.0)
    }
    
    /// Calculates progress based on number of chunks received
    private func calculateChunkBasedProgress() -> Double {
        // Estimate chunks per minute of audio (empirical heuristic)
        // This can vary significantly based on speech rate and content
        let estimatedChunksPerMinute = 10.0
        let estimatedTotalChunks = max(1.0, (audioDuration / 60.0) * estimatedChunksPerMinute)
        
        return min(Double(chunksReceived) / estimatedTotalChunks, 1.0)
    }
    
    /// Calculates progress based on total text length received
    private func calculateTextLengthProgress() -> Double {
        // Estimate words per minute of audio (average speaking rate)
        let averageWordsPerMinute = 150.0
        let averageCharactersPerWord = 5.0
        
        let estimatedTotalCharacters = max(1.0, (audioDuration / 60.0) * averageWordsPerMinute * averageCharactersPerWord)
        
        return min(Double(totalTextLength) / estimatedTotalCharacters, 1.0)
    }
}

// MARK: - Utility Extensions

extension StreamingProgressEstimator {
    /// Creates a human-readable progress description
    /// - Parameter progress: Current progress value (0.0 to 1.0)
    /// - Returns: Formatted progress string
    static func formatProgress(_ progress: Double) -> String {
        let percentage = Int(progress * 100)
        return "\(percentage)%"
    }
    
    /// Creates a human-readable time description
    /// - Parameter timeInterval: Time in seconds
    /// - Returns: Formatted time string (e.g., "2m 30s")
    static func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Determines if progress estimation is reliable based on session data
    /// - Returns: True if estimates are likely to be accurate
    func isEstimationReliable() -> Bool {
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Need at least 5 seconds of data and 3 chunks for reliable estimation
        return elapsedTime >= 5.0 && chunksReceived >= 3
    }
    
    /// Gets the current processing speed ratio (processing time / audio duration)
    /// - Returns: Speed ratio where < 1.0 means faster than real-time
    func getProcessingSpeedRatio() -> Double {
        let elapsedTime = Date().timeIntervalSince(startTime)
        return audioDuration > 0 ? elapsedTime / audioDuration : 0
    }
}

// MARK: - Progress Smoothing

extension StreamingProgressEstimator {
    /// Smooths progress updates to avoid jumpy UI
    /// - Parameters:
    ///   - currentProgress: Current calculated progress
    ///   - previousProgress: Previous progress value
    ///   - maxJump: Maximum allowed progress jump per update
    /// - Returns: Smoothed progress value
    static func smoothProgress(
        current: Double,
        previous: Double,
        maxJump: Double = 0.05
    ) -> Double {
        // Don't allow progress to go backwards
        let forward = max(current, previous)
        
        // Limit the size of progress jumps for smoother UI
        let jump = forward - previous
        if jump > maxJump {
            return previous + maxJump
        }
        
        return forward
    }
}
