import Foundation
import AppKit
import SwiftData
import os

class AudioStorageService: ObservableObject {
    static let shared = AudioStorageService()
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioStorage")
    
    private init() {}
    
    // MARK: - Audio Download
    
    @MainActor
    func downloadAudio(from transcription: Transcription) async throws -> URL? {
        guard let audioURLString = transcription.audioFileURL,
              let audioURL = URL(string: audioURLString),
              FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AudioStorageError.audioFileNotFound
        }
        
        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Save Audio File"
        savePanel.nameFieldStringValue = generateFileName(for: transcription)
        savePanel.allowedContentTypes = [.audio]
        savePanel.canCreateDirectories = true
        
        let response = await savePanel.begin()
        guard response == .OK, let destinationURL = savePanel.url else {
            return nil // User cancelled
        }
        
        // Copy file to chosen location
        try FileManager.default.copyItem(at: audioURL, to: destinationURL)
        logger.info("Audio file downloaded to: \(destinationURL.path)")
        
        return destinationURL
    }
    
    private func generateFileName(for transcription: Transcription) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: transcription.timestamp)
        
        // Use first few words of transcription as filename
        let words = transcription.mainVersion?.text.components(separatedBy: CharacterSet.whitespaces).prefix(5) ?? []
        let textPart = words.joined(separator: "_").replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: NSString.CompareOptions.regularExpression)
        
        if textPart.isEmpty {
            return "VoiceInk_Recording_\(dateString).wav"
        } else {
            return "VoiceInk_\(textPart)_\(dateString).wav"
        }
    }
    
    // MARK: - Storage Management
    
    func cleanupExpiredFiles(olderThan days: Int = 30) async throws {
        let recordingsDirectory = getRecordingsDirectory()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        var deletedCount = 0
        
        for fileURL in contents {
            let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
            if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                try fileManager.removeItem(at: fileURL)
                deletedCount += 1
                logger.info("Deleted expired audio file: \(fileURL.lastPathComponent)")
            }
        }
        
        logger.info("Cleanup completed. Deleted \(deletedCount) expired files.")
    }
    
    func getStorageUsage() throws -> StorageInfo {
        let recordingsDirectory = getRecordingsDirectory()
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return StorageInfo(totalFiles: 0, totalSize: 0)
        }
        
        var totalSize: Int64 = 0
        
        for fileURL in contents {
            let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(attributes.fileSize ?? 0)
        }
        
        return StorageInfo(totalFiles: contents.count, totalSize: totalSize)
    }
    
    private func getRecordingsDirectory() -> URL {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.VoiceInk")
            .appendingPathComponent("Recordings")
    }
}

struct StorageInfo {
    let totalFiles: Int
    let totalSize: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

enum AudioStorageError: LocalizedError {
    case audioFileNotFound
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "Audio file not found or has been deleted"
        case .downloadFailed:
            return "Failed to download audio file"
        }
    }
}
