import Foundation
import AVFoundation
import os

/// Service responsible for analyzing and optimizing audio files for Gemini streaming
class AudioPreprocessingService {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioPreprocessing")
    private let loggingService = LoggingService.shared
    
    // MARK: - Public Interface
    
    /// Analyzes an audio file to determine its characteristics and optimization needs
    /// - Parameter url: URL of the audio file to analyze
    /// - Returns: AudioAnalysis containing file characteristics and optimization recommendations
    func analyzeAudio(url: URL) async throws -> AudioAnalysis {
        let asset = AVAsset(url: url)
        
        // Load audio properties
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
            throw StreamingError.invalidAudioFormat
        }
        
        // Get detailed audio information
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        
        // Calculate file size
        let fileSize = try getFileSize(url)
        
        // Analyze format characteristics
        var sampleRate = 44100
        var channels = 2
        var bitrate = 128000
        
        if let formatDescription = formatDescriptions.first {
            let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
            if let description = audioStreamBasicDescription {
                sampleRate = Int(description.pointee.mSampleRate)
                channels = Int(description.pointee.mChannelsPerFrame)
            }
        }
        
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Calculate actual bitrate from file size and duration
        if durationSeconds > 0 {
            bitrate = Int((fileSize * 8) / Int64(durationSeconds))
        }
        
        // Determine if optimization is needed
        let needsOptimization = AudioAnalysis.shouldOptimize(
            fileSize: fileSize,
            sampleRate: sampleRate,
            channels: channels,
            duration: durationSeconds
        )
        
        let estimatedOptimizedSize = AudioAnalysis.estimateOptimizedSize(
            duration: durationSeconds,
            targetBitrate: StreamingConfiguration.targetBitrate
        )
        
        let compressionRatio = fileSize > 0 ? Double(estimatedOptimizedSize) / Double(fileSize) : 1.0
        
        return AudioAnalysis(
            originalSize: fileSize,
            duration: durationSeconds,
            sampleRate: sampleRate,
            channels: channels,
            bitrate: bitrate,
            needsOptimization: needsOptimization,
            estimatedOptimizedSize: estimatedOptimizedSize,
            compressionRatio: compressionRatio
        )
    }
    
    /// Preprocesses an audio file for optimal Gemini streaming performance
    /// - Parameters:
    ///   - inputURL: URL of the input audio file
    ///   - progressCallback: Callback to report progress (0.0 to 1.0)
    /// - Returns: URL of the optimized audio file (may be the same as input if no optimization needed)
    func preprocessForGemini(
        inputURL: URL,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> URL {
        let sessionId = UUID().uuidString
        
        loggingService.info(
            "Starting audio preprocessing for Gemini",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "input_file": inputURL.lastPathComponent
            ]
        )
        
        // Analyze input audio
        let analysis = try await analyzeAudio(url: inputURL)
        
        loggingService.debug(
            "Audio analysis completed",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "original_size": "\(analysis.originalSize)",
                "duration": "\(analysis.duration)s",
                "sample_rate": "\(analysis.sampleRate)",
                "channels": "\(analysis.channels)",
                "bitrate": "\(analysis.bitrate)",
                "needs_optimization": "\(analysis.needsOptimization)"
            ]
        )
        
        // Return original if no optimization needed
        guard analysis.needsOptimization else {
            loggingService.info(
                "Audio already optimized, skipping preprocessing",
                category: .transcription,
                context: ["session_id": sessionId]
            )
            progressCallback(1.0)
            return inputURL
        }
        
        // Create optimized version
        let optimizedURL = createTempOptimizedURL()
        
        try await compressToGeminiOptimal(
            inputURL: inputURL,
            outputURL: optimizedURL,
            progressCallback: progressCallback
        )
        
        // Verify the optimized file
        let optimizedAnalysis = try await analyzeAudio(url: optimizedURL)
        
        loggingService.info(
            "Audio preprocessing completed",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "output_file": optimizedURL.lastPathComponent,
                "original_size": "\(analysis.originalSize)",
                "optimized_size": "\(optimizedAnalysis.originalSize)",
                "compression_ratio": String(format: "%.2f", analysis.compressionRatio),
                "actual_compression": String(format: "%.2f", Double(optimizedAnalysis.originalSize) / Double(analysis.originalSize))
            ]
        )
        
        return optimizedURL
    }
    
    // MARK: - Private Implementation
    
    /// Compresses audio to Gemini's optimal format (16kbps mono)
    private func compressToGeminiOptimal(
        inputURL: URL,
        outputURL: URL,
        progressCallback: @escaping (Double) -> Void
    ) async throws {
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw StreamingError.preprocessingFailed("Could not create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Configure for Gemini's optimal format
        exportSession.audioMix = createGeminiOptimalAudioMix(asset: asset)
        
        // Set up progress monitoring
        let progressTimer = Timer.scheduledTimer(withTimeInterval: StreamingConfiguration.progressUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                progressCallback(Double(exportSession.progress))
            }
        }
        
        // Perform export
        await exportSession.export()
        progressTimer.invalidate()
        
        // Check result
        switch exportSession.status {
        case .completed:
            progressCallback(1.0)
            logger.notice("✅ Audio compression completed successfully")
            
        case .failed:
            let error = exportSession.error?.localizedDescription ?? "Unknown export error"
            logger.error("❌ Audio compression failed: \(error)")
            throw StreamingError.preprocessingFailed(error)
            
        case .cancelled:
            logger.warning("⚠️ Audio compression was cancelled")
            throw StreamingError.preprocessingFailed("Export was cancelled")
            
        default:
            let statusDescription = exportSessionStatusDescription(exportSession.status)
            logger.error("❌ Audio compression failed with status: \(statusDescription)")
            throw StreamingError.preprocessingFailed("Export failed with status: \(statusDescription)")
        }
    }
    
    /// Creates an audio mix optimized for Gemini (mono, reduced bitrate)
    private func createGeminiOptimalAudioMix(asset: AVAsset) -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        let audioTracks = asset.tracks(withMediaType: .audio)
        
        var audioMixInputParameters: [AVMutableAudioMixInputParameters] = []
        
        for track in audioTracks {
            let audioMixInputParameter = AVMutableAudioMixInputParameters(track: track)
            
            // Configure for mono output (mix down stereo to mono)
            // This reduces file size and matches Gemini's processing preferences
            audioMixInputParameter.setVolume(0.7, at: .zero) // Slightly reduce volume to prevent clipping
            
            audioMixInputParameters.append(audioMixInputParameter)
        }
        
        audioMix.inputParameters = audioMixInputParameters
        return audioMix
    }
    
    /// Creates a temporary URL for the optimized audio file
    private func createTempOptimizedURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "gemini_optimized_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(fileName)
    }
    
    /// Gets the file size in bytes
    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Provides human-readable description of export session status
    private func exportSessionStatusDescription(_ status: AVAssetExportSession.Status) -> String {
        switch status {
        case .unknown:
            return "unknown"
        case .waiting:
            return "waiting"
        case .exporting:
            return "exporting"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        case .cancelled:
            return "cancelled"
        @unknown default:
            return "unknown status (\(status.rawValue))"
        }
    }
}

// MARK: - Utility Extensions

extension AudioPreprocessingService {
    /// Estimates processing time based on audio duration and file size
    func estimateProcessingTime(for analysis: AudioAnalysis) -> TimeInterval {
        guard analysis.needsOptimization else { return 0.1 }
        
        // Base processing time: roughly 1/10th of audio duration
        let baseTime = analysis.duration * 0.1
        
        // Add time based on file size (larger files take longer)
        let sizeMultiplier = Double(analysis.originalSize) / (50 * 1024 * 1024) // 50MB baseline
        let sizeTime = max(0, sizeMultiplier * 5) // Up to 5 extra seconds for very large files
        
        return max(1.0, baseTime + sizeTime) // Minimum 1 second
    }
    
    /// Checks if the input file format is supported
    func isSupportedFormat(_ url: URL) -> Bool {
        let supportedExtensions = ["wav", "mp3", "m4a", "aiff", "aac", "flac"]
        let fileExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(fileExtension)
    }
    
    /// Gets recommended optimization settings for a given audio analysis
    func getOptimizationRecommendations(for analysis: AudioAnalysis) -> [String] {
        var recommendations: [String] = []
        
        if analysis.sampleRate > StreamingConfiguration.targetSampleRate {
            recommendations.append("Reduce sample rate to \(StreamingConfiguration.targetSampleRate)Hz")
        }
        
        if analysis.channels > StreamingConfiguration.targetChannels {
            recommendations.append("Convert to mono audio")
        }
        
        if analysis.bitrate > StreamingConfiguration.targetBitrate * 2 {
            recommendations.append("Reduce bitrate to \(StreamingConfiguration.targetBitrate)bps")
        }
        
        if analysis.originalSize > StreamingConfiguration.maxFileSize / 10 {
            let compressionPercent = Int((1.0 - analysis.compressionRatio) * 100)
            recommendations.append("Compress file size by ~\(compressionPercent)%")
        }
        
        return recommendations
    }
}
