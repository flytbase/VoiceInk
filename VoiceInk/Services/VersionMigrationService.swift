import Foundation
import SwiftData
import os

class VersionMigrationService: ObservableObject {
    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "VersionMigration")
    
    static func migrateExistingTranscriptions(modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<Transcription>()
        let transcriptions = try modelContext.fetch(descriptor)
        
        logger.info("Starting migration of \(transcriptions.count) transcriptions")
        
        var migratedCount = 0
        
        for transcription in transcriptions {
            // Skip if already migrated (has versions)
            if !transcription.transcriptionVersions.isEmpty {
                logger.debug("Skipping already migrated transcription: \(transcription.id)")
                continue
            }
            
            do {
                // Create initial version from existing text
                let initialVersion = TranscriptionVersion(
                    text: transcription.text,
                    transcriptionMethod: "Legacy", // We don't know the original method
                    isMainVersion: true
                )
                
                transcription.addTranscriptionVersion(initialVersion)
                
                // If there's enhanced text, create enhancement version
                if let enhancedText = transcription.enhancedText, !enhancedText.isEmpty {
                    let enhancementVersion = EnhancementVersion(
                        enhancedText: enhancedText,
                        enhancementMethod: "Legacy Enhancement",
                        baseVersionId: initialVersion.id
                    )
                    
                    transcription.addEnhancementVersion(enhancementVersion)
                    logger.debug("Created enhancement version for transcription: \(transcription.id)")
                }
                
                migratedCount += 1
                logger.debug("Migrated transcription: \(transcription.id)")
                
                // Save periodically to avoid memory issues
                if migratedCount % 50 == 0 {
                    try modelContext.save()
                    logger.info("Saved batch of 50 migrations. Total migrated: \(migratedCount)")
                }
                
            } catch {
                logger.error("Failed to migrate transcription \(transcription.id): \(error.localizedDescription)")
                // Continue with other transcriptions instead of failing completely
            }
        }
        
        // Final save
        try modelContext.save()
        logger.info("Migration completed successfully. Migrated \(migratedCount) transcriptions")
    }
    
    static func needsMigration(modelContext: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<Transcription>()
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate<Transcription> { transcription in
            transcription.transcriptionVersions.isEmpty
        }
        
        let unmigrated = try modelContext.fetch(descriptor)
        let needsMigration = !unmigrated.isEmpty
        
        logger.debug("Migration check: needsMigration = \(needsMigration)")
        return needsMigration
    }
    
    static func getMigrationStats(modelContext: ModelContext) throws -> MigrationStats {
        let allDescriptor = FetchDescriptor<Transcription>()
        let allTranscriptions = try modelContext.fetch(allDescriptor)
        
        var unmigratedDescriptor = FetchDescriptor<Transcription>()
        unmigratedDescriptor.predicate = #Predicate<Transcription> { transcription in
            transcription.transcriptionVersions.isEmpty
        }
        let unmigratedTranscriptions = try modelContext.fetch(unmigratedDescriptor)
        
        return MigrationStats(
            totalTranscriptions: allTranscriptions.count,
            unmigratedTranscriptions: unmigratedTranscriptions.count,
            migratedTranscriptions: allTranscriptions.count - unmigratedTranscriptions.count
        )
    }
    
    // MARK: - Validation and Rollback
    
    static func validateMigration(modelContext: ModelContext) async throws -> Bool {
        let descriptor = FetchDescriptor<Transcription>()
        let transcriptions = try modelContext.fetch(descriptor)
        
        for transcription in transcriptions {
            // Skip validation for transcriptions that don't need migration
            if transcription.transcriptionVersions.isEmpty {
                continue
            }
            
            // Validate that migration was successful
            guard let mainVersion = transcription.mainVersion else {
                logger.error("Validation failed: No main version for transcription \(transcription.id)")
                return false
            }
            
            // Validate that original text is preserved
            if mainVersion.text != transcription.text {
                logger.error("Validation failed: Text mismatch for transcription \(transcription.id)")
                return false
            }
            
            // Validate enhancement versions if they exist
            for enhancement in transcription.enhancementVersions {
                if !transcription.transcriptionVersions.contains(where: { $0.id == enhancement.baseVersionId }) {
                    logger.error("Validation failed: Enhancement references non-existent version for transcription \(transcription.id)")
                    return false
                }
            }
        }
        
        logger.info("Migration validation passed successfully")
        return true
    }
    
    static func rollbackMigration(modelContext: ModelContext) async throws {
        logger.warning("Starting migration rollback")
        
        let descriptor = FetchDescriptor<Transcription>()
        let transcriptions = try modelContext.fetch(descriptor)
        
        for transcription in transcriptions {
            // Clear version data to rollback
            transcription.transcriptionVersions.removeAll()
            transcription.enhancementVersions.removeAll()
            transcription.mainVersionId = nil
        }
        
        try modelContext.save()
        logger.warning("Migration rollback completed")
    }
}

// MARK: - Supporting Types

struct MigrationStats {
    let totalTranscriptions: Int
    let unmigratedTranscriptions: Int
    let migratedTranscriptions: Int
    
    var migrationProgress: Double {
        guard totalTranscriptions > 0 else { return 1.0 }
        return Double(migratedTranscriptions) / Double(totalTranscriptions)
    }
    
    var isComplete: Bool {
        return unmigratedTranscriptions == 0
    }
}

enum MigrationError: LocalizedError {
    case validationFailed
    case migrationIncomplete
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Migration validation failed"
        case .migrationIncomplete:
            return "Migration was not completed successfully"
        case .dataCorruption:
            return "Data corruption detected during migration"
        }
    }
}
