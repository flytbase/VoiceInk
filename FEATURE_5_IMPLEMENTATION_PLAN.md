# Feature 5: Enhanced History Management - Complete Implementation Plan

## 🎯 Overview

This document provides detailed step-by-step instructions for implementing Feature 5: Enhanced History Management in VoiceInk. This feature adds version tracking, re-transcription capabilities, audio downloads, and enhanced UI to the existing transcription history.

### **Current State Analysis**
- ✅ Audio files already stored locally in `~/Library/Application Support/com.prakashjoshipax.VoiceInk/Recordings/`
- ✅ Transcription model has `audioFileURL` field
- ✅ Basic re-transcribe functionality exists in AudioPlayerView
- ✅ TranscriptionHistoryView with search, selection, and basic actions
- ✅ Audio playback with waveform visualization

### **Target State**
- ✅ Version tracking for multiple transcriptions per audio file
- ✅ Enhanced re-transcription with version management
- ✅ Audio download functionality
- ✅ Historical enhancement triggers
- ✅ Version comparison UI
- ✅ Storage management with 30-day retention
- ✅ Migration of existing data

### **Key Design Principle: Copy, Don't Modify**
**Important**: We will NOT modify existing history files. Instead, we will:
1. **Copy existing files** to create V2 versions (TranscriptionHistoryViewV2.swift, TranscriptionCardV2.swift)
2. **Show both versions** side-by-side during development
3. **Test V2 thoroughly** while V1 remains functional
4. **Replace V1 with V2** only when V2 is stable and tested
5. **Delete V1 files cleanly** after successful migration

This approach ensures:
- ✅ **Zero risk** to existing functionality
- ✅ **Easy rollback** if issues arise
- ✅ **Side-by-side testing** during development
- ✅ **Clean deletion** when ready

---

## 🎨 UI Structure Reference

### **Enhanced UI Layout (V2)**
Based on our discussion, here's the complete UI structure we're implementing:

```
┌─ History V2 ─────────────────────────────────────────────────┐
│                                                              │
│  🔍 [Search transcriptions and versions...]                 │
│                                                              │
│  ┌─ Dec 3, 2024 • 2:30 PM • 3:45 ──── 🔄 2 📁 ✨ ─────────┐│
│  │                                                         ││
│  │  📝 Latest: "Meeting notes about project updates..."   ││
│  │  🤖 Enhanced with Gemini 2.5 Pro                      ││
│  │                                                         ││
│  │  [▶️ Play Audio] [🔄 Re-transcribe] [📥 Download]      ││
│  │  [✨ Enhance] [📋 Copy] [⚙️ Actions ▼]                ││
│  │                                                         ││
│  │  ▼ Versions (2):                                       ││
│  │    • V2: Gemini 2.5 Pro (3:15 PM) ⭐                  ││
│  │    • V1: Whisper Tiny (2:30 PM)                       ││
│  │                                                         ││
│  │  [Compare Versions Side-by-Side ▼]                     ││
│  │  ┌─ V2 (Latest) ─────────┬─ V1 (Original) ─────────┐  ││
│  │  │ "Meeting notes about  │ "Meeting note about     │  ││
│  │  │ project updates and   │ project update and      │  ││
│  │  │ next quarter goals"   │ next quarter goal"      │  ││
│  │  │ (Gemini 2.5 Pro)      │ (Whisper Tiny)          │  ││
│  │  └───────────────────────┴─────────────────────────┘  ││
│  │                                                         ││
│  │  📅 Dec 3, 2024 at 2:30:45 PM                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ Dec 2, 2024 • 4:15 PM • 1:23 ──────────── 📁 ─────────┐│
│  │                                                         ││
│  │  📝 "Quick voice note about..."                        ││
│  │  ❌ No audio file available                            ││
│  │                                                         ││
│  │  [📋 Copy] [✨ Enhance] [⚙️ Actions ▼]                ││
│  │                                                         ││
│  │  📅 Dec 2, 2024 at 4:15:22 PM                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─ Selection Toolbar (when items selected) ─────────────────┐│
│  │  📊 3 selected    [🗑️ Delete] [Select All] [Deselect]   ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

### **Context Menu (Right-click)**
```
Context Menu:
├─ 🔄 Re-transcribe with current settings
├─ ✨ Enhance transcription  
├─ 📥 Download original audio
├─ 📋 Copy original text
├─ 📋 Copy enhanced text (if available)
├─ 🗂️ Show all versions
├─ 📊 Compare versions
└─ 🗑️ Delete
```

### **Visual Indicators**
- **🔄 Version badge** - Shows number of versions (e.g., "🔄 2")
- **📁 Audio available** - Green folder icon when audio file exists
- **❌ No audio** - Red X when audio file missing/deleted
- **✨ Enhanced** - Yellow sparkles when AI enhancement available
- **⭐ Main version** - Star indicator for the primary version

---

## 🏗️ Architecture Overview

### **Data Model Enhancement**
```
Transcription (Enhanced)
├── transcriptionVersions: [TranscriptionVersion]
├── enhancementVersions: [EnhancementVersion]
├── mainVersionId: UUID?
└── (existing fields...)

TranscriptionVersion (New)
├── id: UUID
├── text: String
├── createdAt: Date
├── transcriptionMethod: String
├── promptUsed: String?
├── isMainVersion: Bool
└── parentTranscription: Transcription

EnhancementVersion (New)
├── id: UUID
├── enhancedText: String
├── createdAt: Date
├── enhancementMethod: String
├── baseVersionId: UUID
└── parentTranscription: Transcription
```

### **Service Layer**
```
AudioStorageService (New)
├── downloadAudio(transcription) -> URL
├── cleanupExpiredFiles()
└── getStorageUsage() -> StorageInfo

VersionMigrationService (New)
├── migrateExistingTranscriptions()
└── createInitialVersions()

EnhancedTranscriptionManager (New)
├── retranscribeWithVersioning()
├── enhanceHistoricalTranscription()
└── createNewVersion()
```

### **UI Components (V2 - Copied from V1)**
```
TranscriptionHistoryViewV2 (Copy of V1)
├── Enhanced search across all versions
├── Version management UI
└── Migration handling

TranscriptionCardV2 (Copy of V1)
├── Version indicators and badges
├── Enhanced action buttons
├── Version comparison view
└── Audio download functionality

VersionManagementView (New)
├── Version list display
├── Comparison interface
└── Version selection controls
```

---

## 📋 Implementation Phases

### **Phase 1: Data Model Enhancement (Foundation)**
**Duration**: 2-3 hours  
**Goal**: Create new data models and migration system

### **Phase 2: Core Services Development**
**Duration**: 3-4 hours  
**Goal**: Build backend services for version management and audio handling

### **Phase 3: UI Components Creation**
**Duration**: 4-5 hours  
**Goal**: Create enhanced UI components with version management

### **Phase 4: Integration & Testing**
**Duration**: 2-3 hours  
**Goal**: Integrate all components and test thoroughly

---

## 🔧 Phase 1: Data Model Enhancement

### **Step 1.1: Create TranscriptionVersion Model**

#### **What We're Doing:**
Create a new model to track multiple versions of transcriptions for the same audio file. Each version will store:
- The transcribed text
- Which transcription method was used (Whisper Tiny, Gemini 2.5 Pro, etc.)
- When it was created
- Whether it's the main/primary version
- Optional confidence score and prompt used

#### **Why This Approach:**
- Allows users to try different transcription models on the same audio
- Keeps history of all attempts for comparison
- Enables rollback to previous versions
- Tracks which method produced which result

#### **Implementation:**

**File**: `VoiceInk/Models/TranscriptionVersion.swift`

```swift
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
    
    // Relationship
    var parentTranscription: Transcription?
    
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
```

**Testing Criteria**:
- [ ] Model compiles without errors
- [ ] Can create TranscriptionVersion instances
- [ ] All properties are accessible
- [ ] Relationships work correctly

### **Step 1.2: Create EnhancementVersion Model**

#### **What We're Doing:**
Create a model to track AI enhancements applied to transcriptions. This allows:
- Multiple enhancement attempts on the same transcription
- Tracking which enhancement method was used
- Linking enhancements to specific transcription versions
- History of enhancement attempts

#### **Why This Approach:**
- Users can try different enhancement prompts
- Keeps history of all enhancement attempts
- Links enhancements to specific transcription versions
- Enables comparison of enhancement results

#### **Implementation:**

**File**: `VoiceInk/Models/EnhancementVersion.swift`

```swift
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
    
    // Relationship
    var parentTranscription: Transcription?
    
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
```

**Testing Criteria**:
- [ ] Model compiles without errors
- [ ] Can create EnhancementVersion instances
- [ ] Relationships work correctly
- [ ] Can link to specific transcription versions

### **Step 1.3: Enhance Existing Transcription Model**

#### **What We're Doing:**
Add version management capabilities to the existing Transcription model WITHOUT breaking existing functionality. We'll add:
- Arrays to hold transcription and enhancement versions
- Computed properties to easily access main/latest versions
- Helper methods to manage versions
- Backward compatibility with existing code

#### **Why This Approach:**
- Maintains all existing functionality
- Adds new capabilities without breaking changes
- Provides convenient access to version data
- Ensures smooth migration path

#### **Implementation:**

**File**: `VoiceInk/Models/Transcription.swift` (Modify existing)

**Add these properties to the existing Transcription class**:

```swift
// Add these new properties to existing Transcription model
var transcriptionVersions: [TranscriptionVersion] = []
var enhancementVersions: [EnhancementVersion] = []
var mainVersionId: UUID?

// Add these computed properties
var mainVersion: TranscriptionVersion? {
    return transcriptionVersions.first { $0.isMainVersion } ?? transcriptionVersions.first
}

var latestVersion: TranscriptionVersion? {
    return transcriptionVersions.max { $0.createdAt < $1.createdAt }
}

var hasMultipleVersions: Bool {
    return transcriptionVersions.count > 1
}

var latestEnhancement: EnhancementVersion? {
    return enhancementVersions.max { $0.createdAt < $1.createdAt }
}

// Add these helper methods
func addTranscriptionVersion(_ version: TranscriptionVersion) {
    version.parentTranscription = self
    transcriptionVersions.append(version)
    
    // If this is the first version or marked as main, update mainVersionId
    if transcriptionVersions.count == 1 || version.isMainVersion {
        mainVersionId = version.id
        // Ensure only one main version
        transcriptionVersions.forEach { $0.isMainVersion = ($0.id == version.id) }
    }
}

func addEnhancementVersion(_ version: EnhancementVersion) {
    version.parentTranscription = self
    enhancementVersions.append(version)
}

func setMainVersion(_ versionId: UUID) {
    transcriptionVersions.forEach { $0.isMainVersion = ($0.id == versionId) }
    mainVersionId = versionId
}
```

**Testing Criteria**:
- [ ] Existing Transcription functionality still works
- [ ] New properties are accessible
- [ ] Computed properties return correct values
- [ ] Helper methods work correctly
- [ ] No breaking changes to existing code

### **Step 1.4: Create Migration Service**

#### **What We're Doing:**
Create a service to safely migrate existing transcriptions to the new version system. This will:
- Detect transcriptions that need migration
- Convert existing text to initial TranscriptionVersion
- Convert existing enhancedText to EnhancementVersion
- Preserve all existing data
- Handle migration errors gracefully

#### **Why This Approach:**
- Ensures no data loss during upgrade
- Provides smooth transition to new system
- Handles edge cases and errors
- Can be run multiple times safely

#### **Implementation:**

**File**: `VoiceInk/Services/VersionMigrationService.swift`

```swift
import Foundation
import SwiftData
import os

class VersionMigrationService {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "VersionMigration")
    
    static func migrateExistingTranscriptions(modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<Transcription>()
        let transcriptions = try modelContext.fetch(descriptor)
        
        logger.info("Starting migration of \(transcriptions.count) transcriptions")
        
        for transcription in transcriptions {
            // Skip if already migrated (has versions)
            if !transcription.transcriptionVersions.isEmpty {
                continue
            }
            
            // Create initial version from existing text
            let initialVersion = TranscriptionVersion(
                text: transcription.text,
                transcriptionMethod: "Legacy", // We don't know the original method
                isMainVersion: true
            )
            
            transcription.addTranscriptionVersion(initialVersion)
            
            // If there's enhanced text, create enhancement version
            if let enhancedText = transcription.enhancedText {
                let enhancementVersion = EnhancementVersion(
                    enhancedText: enhancedText,
                    enhancementMethod: "Legacy Enhancement",
                    baseVersionId: initialVersion.id
                )
                
                transcription.addEnhancementVersion(enhancementVersion)
            }
        }
        
        try modelContext.save()
        logger.info("Migration completed successfully")
    }
    
    static func needsMigration(modelContext: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Transcription>()
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate<Transcription> { transcription in
            transcription.transcriptionVersions.isEmpty
        }
        
        let unmigrated = try modelContext.fetch(descriptor)
        return !unmigrated.isEmpty
    }
}
```

**Testing Criteria**:
- [ ] Migration service compiles
- [ ] Can detect unmigrated transcriptions
- [ ] Migration creates appropriate versions
- [ ] No data loss during migration
- [ ] Can run multiple times safely

---

## 🔧 Phase 2: Core Services Development

### **Step 2.1: Create Audio Storage Service**

#### **What We're Doing:**
Create a service to handle audio file operations including:
- Downloading audio files to user-chosen locations
- Generating smart filenames based on transcription content
- Managing storage cleanup (30-day retention)
- Calculating storage usage statistics
- Handling file system errors gracefully

#### **Why This Approach:**
- Centralizes all audio file operations
- Provides consistent file naming
- Enables storage management features
- Handles edge cases and errors
- Supports future audio-related features

#### **Implementation:**

**File**: `VoiceInk/Services/AudioStorageService.swift`

```swift
import Foundation
import AppKit
import os

class AudioStorageService: ObservableObject {
    static let shared = AudioStorageService()
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioStorage")
    
    private init() {}
    
    // MARK: - Audio Download
    
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
        let words = transcription.mainVersion?.text.components(separatedBy: .whitespaces).prefix(5) ?? []
        let textPart = words.joined(separator: "_").replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)
        
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
```

**Testing Criteria**:
- [ ] Can generate appropriate filenames
- [ ] Save panel appears and works correctly
- [ ] File copying works without errors
- [ ] Storage cleanup functions correctly
- [ ] Storage usage calculation is accurate

### **Step 2.2: Create Enhanced Transcription Manager**

#### **What We're Doing:**
Create a service to handle enhanced transcription operations including:
- Re-transcribing audio with version management
- Enhancing historical transcriptions
- Managing transcription progress and status
- Handling both Whisper and Gemini transcription
- Creating appropriate version records

#### **Why This Approach:**
- Centralizes all transcription logic
- Provides consistent version management
- Handles progress tracking and errors
- Supports both local and cloud transcription
- Enables future transcription features

#### **Implementation:**

**File**: `VoiceInk/Services/EnhancedTranscriptionManager.swift`

```swift
import Foundation
import SwiftData
import os

@MainActor
class EnhancedTranscriptionManager: ObservableObject {
    static let shared = EnhancedTranscriptionManager()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage = ""
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "EnhancedTranscription")
    
    private init() {}
    
    // MARK: - Re-transcription with Versioning
    
    func retranscribeWithVersioning(
        transcription: Transcription,
        modelContext: ModelContext,
        whisperState: WhisperState
    ) async throws {
        guard let audioURLString = transcription.audioFileURL,
              let audioURL = URL(string: audioURLString),
              FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        isProcessing = true
        processingProgress = 0.0
        processingMessage = "Starting re-transcription..."
        errorMessage = nil
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
        }
        
        do {
            // Determine current transcription method
            let transcriptionMethod = getCurrentTranscriptionMethod()
            processingMessage = "Transcribing with \(transcriptionMethod)..."
            processingProgress = 0.3
            
            // Perform transcription
            let newText = try await performTranscription(audioURL: audioURL, whisperState: whisperState)
            processingProgress = 0.8
            
            // Create new version
            let newVersion = TranscriptionVersion(
                text: newText,
                transcriptionMethod: transcriptionMethod,
                promptUsed: getCurrentPrompt(),
                isMainVersion: true // New version becomes main
            )
            
            transcription.addTranscriptionVersion(newVersion)
            
            // Handle enhancement if enabled
            if let enhancementService = whisperState.enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                
                processingMessage = "Enhancing transcription..."
                processingProgress = 0.9
                
                do {
                    let enhancedText = try await enhancementService.enhance(newText)
                    let enhancementVersion = EnhancementVersion(
                        enhancedText: enhancedText,
                        enhancementMethod: "AI Enhancement",
                        baseVersionId: newVersion.id
                    )
                    transcription.addEnhancementVersion(enhancementVersion)
                } catch {
                    logger.warning("Enhancement failed: \(error.localizedDescription)")
                    // Continue without enhancement
                }
            }
            
            try modelContext.save()
            processingProgress = 1.0
            processingMessage = "Re-transcription completed!"
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingMessage = ""
            }
            
        } catch {
            logger.error("Re-transcription failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Historical Enhancement
    
    func enhanceHistoricalTranscription(
        transcription: Transcription,
        versionId: UUID? = nil,
        modelContext: ModelContext,
        enhancementService: AIEnhancementService
    ) async throws {
        guard enhancementService.isConfigured else {
            throw TranscriptionError.enhancementNotConfigured
        }
        
        // Use specified version or main version
        let targetVersion = versionId != nil 
            ? transcription.transcriptionVersions.first { $0.id == versionId }
            : transcription.mainVersion
        
        guard let version = targetVersion else {
            throw TranscriptionError.noVersionFound
        }
        
        isProcessing = true
        processingMessage = "Enhancing transcription..."
        errorMessage = nil
        
        defer {
            isProcessing = false
            processingMessage = ""
        }
        
        do {
            let enhancedText = try await enhancementService.enhance(version.text)
            
            let enhancementVersion = EnhancementVersion(
                enhancedText: enhancedText,
                enhancementMethod: enhancementService.currentProvider.displayName,
                baseVersionId: version.id
            )
            
            transcription.addEnhancementVersion(enhancementVersion)
            try modelContext.save()
            
            processingMessage = "Enhancement completed!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.processingMessage = ""
            }
            
        } catch {
            logger.error("Enhancement failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTranscriptionMethod() -> String {
        let geminiTranscription = GeminiAudioTranscription.shared
        if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
            return "Gemini 2.5 Pro"
        } else {
            // Get current Whisper model name
            return UserDefaults.standard.string(forKey: "CurrentWhisperModel") ?? "Whisper"
        }
    }
    
    private func getCurrentPrompt() -> String? {
        let geminiTranscription = GeminiAudioTranscription.shared
        if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
            // Get current transcription prompt if using cloud
            return TranscriptionPromptService().selectedPrompt?.prompt
        }
        return nil
    }
    
    private func performTranscription(audioURL: URL, whisperState: WhisperState) async throws -> String {
        let geminiTranscription = GeminiAudioTranscription.shared
        
        if geminiTranscription.isEnabled && geminiTranscription.isConfigured {
            // Use Gemini transcription
            let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "auto"
            var text = try await geminiTranscription.transcribe(audioURL: audioURL, language: selectedLanguage)
            
            // Apply word replacements if enabled
            if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                text = WordReplacementService.shared.applyReplacements(to: text)
            }
            
            return text
        } else {
            // Use Whisper transcription
            guard let currentModel = whisperState.currentModel else {
                throw TranscriptionError.noModelSelected
            }
            
            let whisperContext = try await WhisperContext.createContext(path: currentModel.url.path)
            let audioProcessor = AudioProcessor()
            let samples = try await audioProcessor.processAudioToSamples(audioURL)
            
            await whisperContext.setPrompt(whisperState.whisperPrompt.transcriptionPrompt)
            try await whisperContext.fullTranscribe(samples: samples)
            var text = await whisperContext.getTranscription()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = WhisperTextFormatter.format(text)
            
            // Apply word replacements if enabled
            if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                text = WordReplacementService.shared.applyReplacements(to: text)
            }
            
            return text
        }
    }
}

enum TranscriptionError: LocalizedError {
    case audioFileNotFoun
    case noModelSelected
    case enhancementNotConfigured
    case noVersionFound
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "Audio file not found"
        case .noModelSelected:
            return "No transcription model selected"
        case .enhancementNotConfigured:
            return "Enhancement service not configured"
        case .noVersionFound:
            return "No transcription version found"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
```

**Testing Criteria**:
- [ ] Re-transcription creates new versions correctly
- [ ] Main version is updated appropriately
- [ ] Enhancement works for historical transcriptions
- [ ] Error handling works correctly
- [ ] Progress updates are accurate

---

## 🔧 Phase 3: UI Components Creation

### **Step 3.1: Create Version Management View**

#### **What We're Doing:**
Create a new UI component to display and manage transcription versions. This will:
- Show a list of all versions for a transcription
- Display version details (method, timestamp, preview)
- Allow setting which version is the main version
- Provide side-by-side comparison of versions
- Handle version selection and management

#### **Why This Approach:**
- Provides clear visual representation of versions
- Enables easy comparison between versions
- Allows users to choose their preferred version
- Integrates seamlessly with existing UI
- Supports future version management features

#### **Implementation:**

**File**: `VoiceInk/Views/VersionManagementView.swift`

```swift
import SwiftUI

struct VersionManagementView: View {
    let transcription: Transcription
    @State private var showComparison = false
    @State private var selectedVersions: Set<UUID> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Version count header
            HStack {
                Text("Versions (\(transcription.transcriptionVersions.count))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if transcription.hasMultipleVersions {
                    Button(action: { showComparison.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showComparison ? "eye.slash" : "eye")
                            Text(showComparison ? "Hide Comparison" : "Compare Versions")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // Version list
            VStack(spacing: 8) {
                ForEach(transcription.transcriptionVersions.sorted { $0.createdAt > $1.createdAt }) { version in
                    VersionRowView(
                        version: version,
                        isMain: version.isMainVersion,
                        isSelected: selectedVersions.contains(version.id),
                        onToggleSelection: { toggleSelection(version.id) },
                        onSetAsMain: { setAsMain(version.id) }
                    )
                }
            }
            
            // Comparison view
            if showComparison && transcription.hasMultipleVersions {
                Divider()
                    .padding(.vertical, 8)
                
                VersionComparisonView(
                    versions: transcription.transcriptionVersions.sorted { $0.createdAt > $1.createdAt }
                )
            }
        }
    }
    
    private func toggleSelection(_ versionId: UUID) {
        if selectedVersions.contains(versionId) {
            selectedVersions.remove(versionId)
        } else {
            selectedVersions.insert(versionId)
        }
    }
    
    private func setAsMain(_ versionId: UUID) {
        transcription.setMainVersion(versionId)
    }
}

struct VersionRowView: View {
    let version: TranscriptionVersion
    let isMain: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onSetAsMain: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Version indicator
            Circle()
                .fill(isMain ? Color.blue : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(version.transcriptionMethod)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isMain ? .primary : .secondary)
                    
                    if isMain {
                        Text("⭐")
                            .font(.system(size: 12))
                    }
                    
                    Spacer()
                    
                    Text(version.createdAt, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text(version.text.prefix(100) + (version.text.count > 100 ? "..." : ""))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if !isMain {
                Button("Set as Main") {
                    onSetAsMain()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isMain ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isMain ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct VersionComparisonView: View {
    let versions: [TranscriptionVersion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Version Comparison")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            if versions.count >= 2 {
                HStack(alignment: .top, spacing: 16) {
                    // Latest version
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Latest")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            Text("(\(versions[0].transcriptionMethod))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            Text(versions[0].text)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(6)
                    }
                    
                    // Previous version
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Previous")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("(\(versions[1].transcriptionMethod))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            Text(versions[1].text)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
}
```

**Testing Criteria**:
- [ ] Version list displays correctly
- [ ] Main version is highlighted appropriately
- [ ] Comparison view shows differences
- [ ] Set as main functionality works
- [ ] UI is responsive and clean

### **Step 3.2: Copy and Enhance TranscriptionCard (Create V2)**

#### **What We're Doing:**
Copy the existing TranscriptionCard.swift to create TranscriptionCardV2.swift and enhance it with:
- Version indicators and badges
- Enhanced action buttons (Re-transcribe, Download, Enhance)
- Integration with new services
- Version management UI integration
- Audio download functionality
- Context menu with all new actions

#### **Why This Approach:**
- Preserves existing functionality completely
- Allows side-by-side testing
- Enables easy rollback if needed
- Provides clean migration path
- Supports incremental development

#### **Implementation Steps:**

1. **Copy the file**: `cp VoiceInk/Views/TranscriptionCard.swift VoiceInk/Views/TranscriptionCardV2.swift`
2. **Rename the struct**: Change `TranscriptionCard` to `TranscriptionCardV2`
3. **Add version indicators** in the header section
4. **Add enhanced action buttons** for new functionality
5. **Integrate with new services** (AudioStorageService, EnhancedTranscriptionManager)
6. **Add version management integration** with VersionManagementView
7. **Enhance context menu** with new actions

**Key Enhancements to Add:**
- Version badge display (🔄 2)
- Audio availability indicator (📁 or ❌)
- Enhancement indicator (✨)
- Re-transcribe button with progress
- Download audio button
- Enhance button for historical transcriptions
- Show/hide versions toggle
- Integration with VersionManagementView

**Testing Criteria**:
- [ ] All existing functionality preserved
- [ ] Version indicators display correctly
- [ ] Action buttons work as expected
- [ ] Context menu appears with all options
- [ ] Audio download functionality works
- [ ] Re-transcription creates new versions
- [ ] Enhancement works for historical transcriptions

### **Step 3.3: Copy and Enhance TranscriptionHistoryView (Create V2)**

#### **What We're Doing:**
Copy the existing TranscriptionHistoryView.swift to create TranscriptionHistoryViewV2.swift and enhance it with:
- Enhanced search across all versions
- Migration detection and handling
- Integration with TranscriptionCardV2
- Version management features
- Side-by-side development support

#### **Why This Approach:**
- Preserves existing history view completely
- Allows thorough testing of new features
- Enables easy comparison between versions
- Provides safe development environment
- Supports clean migration when ready

#### **Implementation Steps:**

1. **Copy the file**: `cp VoiceInk/Views/TranscriptionHistoryView.swift VoiceInk/Views/TranscriptionHistoryViewV2.swift`
2. **Rename the struct**: Change `TranscriptionHistoryView` to `TranscriptionHistoryViewV2`
3. **Add V2 header indicator** to show this is the enhanced version
4. **Enhance search functionality** to search across all versions
5. **Add migration detection** and alert handling
6. **Replace TranscriptionCard** with TranscriptionCardV2
7. **Add integration** with new services

**Key Enhancements to Add:**
- Enhanced search predicate for versions
- Migration status checking
- Migration alert and process
- V2 header with version indicator
- Integration with new services
- Use of TranscriptionCardV2

**Testing Criteria**:
- [ ] All existing functionality preserved
- [ ] Enhanced search works across all versions
- [ ] Migration alert appears when needed
- [ ] Migration process completes successfully
- [ ] V2 header displays correctly
- [ ] Integration with V2 components works

---

## 🔧 Phase 4: Integration & Testing

### **Step 4.1: Update ContentView for Side-by-Side Development**

#### **What We're Doing:**
Modify ContentView to show both V1 and V2 history views side-by-side during development. This will:
- Add tabs for both versions
- Enable easy comparison
- Allow testing of both versions
- Provide safe development environment
- Support gradual migration

#### **Why This Approach:**
- Enables thorough testing
- Allows easy comparison
- Provides fallback option
- Supports incremental development
- Reduces risk of breaking changes

#### **Implementation:**

**File**: `VoiceInk/Views/ContentView.swift` (Modify existing)

```swift
// In the ContentView where history is displayed, replace with:
TabView {
    TranscriptionHistoryView()
        .tabItem {
            Label("History V1", systemImage: "doc.text")
        }
    
    TranscriptionHistoryViewV2()
        .tabItem {
            Label("History V2", systemImage: "doc.text.fill")
        }
        .environmentObject(whisperState)
}
```

**Testing Criteria**:
- [ ] Both tabs appear correctly
- [ ] V1 functionality unchanged
- [ ] V2 functionality works
- [ ] Easy switching between versions
- [ ] No interference between versions

### **Step 4.2: Comprehensive Testing Plan**

#### **Data Model Testing**

**What We're Testing:**
- All new models compile and work correctly
- Relationships between models function properly
- Migration preserves all existing data
- No breaking changes to existing functionality

**Test Cases:**
- [ ] TranscriptionVersion model works correctly
- [ ] EnhancementVersion model works correctly
- [ ] Enhanced Transcription model maintains backward compatibility
- [ ] Migration service migrates existing data without loss
- [ ] Relationships between models work correctly
- [ ] Computed properties return correct values
- [ ] Helper methods function as expected

#### **Service Testing**

**What We're Testing:**
- All services function correctly
- Error handling works properly
- Progress tracking is accurate
- File operations are safe
- Integration points work correctly

**Test Cases:**
- [ ] AudioStorageService downloads files correctly
- [ ] File naming generation works properly
- [ ] Storage cleanup functions correctly
- [ ] EnhancedTranscriptionManager creates versions properly
- [ ] Re-transcription with different models works
- [ ] Historical enhancement works
- [ ] Progress updates are accurate
- [ ] Error handling works correctly

#### **UI Testing**

**What We're Testing:**
- All UI components display correctly
- User interactions work as expected
- Visual indicators are accurate
- Performance is acceptable
- Accessibility is maintained

**Test Cases:**
- [ ] Version indicators display correctly
- [ ] Action buttons work as expected
- [ ] Context menus appear with all options
- [ ] Version comparison view works
- [ ] Search works across all versions
- [ ] Migration alert and process work
- [ ] Audio download functionality works
- [ ] Re-transcription creates new versions
- [ ] Enhancement works for historical transcriptions

#### **Integration Testing**

**What We're Testing:**
- V1 and V2 can coexist
- Data flows correctly between components
- No conflicts between versions
- Performance is acceptable
- Memory usage is reasonable

**Test Cases:**
- [ ] V1 and V2 can run side-by-side
- [ ] Data created in V1 works in V2 after migration
- [ ] All existing functionality is preserved
- [ ] Performance is acceptable with version data
- [ ] Memory usage is reasonable
- [ ] No conflicts between V1 and V2

### **Step 4.3: Performance Optimization**

#### **Database Optimization**

**What We're Optimizing:**
- Query performance for version data
- Search performance across versions
- Memory usage with large datasets
- Pagination efficiency

**Optimization Tasks:**
- [ ] Add indexes for version queries
- [ ] Optimize search across versions
- [ ] Implement efficient pagination
- [ ] Monitor memory usage with large datasets
- [ ] Profile query performance
- [ ] Optimize relationship loading

#### **UI Optimization**

**What We're Optimizing:**
- Rendering performance with many versions
- Animation smoothness
- Responsiveness during processing
- Memory usage in UI components

**Optimization Tasks:**
- [ ] Lazy loading of version data
- [ ] Efficient rendering of large version lists
- [ ] Smooth animations and transitions
- [ ] Responsive UI during processing
- [ ] Optimize image and icon loading
- [ ] Minimize view updates

### **Step 4.4: Error Handling & Edge Cases**

#### **Error Scenarios**

**What We're Handling:**
- Missing or corrupted audio files
- Network failures during cloud transcription
- Insufficient storage space
- Migration failures
- Concurrent access issues

**Error Handling Tasks:**
- [ ] Missing audio files
- [ ] Corrupted transcription data
- [ ] Network failures during cloud transcription
- [ ] Insufficient storage space
- [ ] Migration failures
- [ ] Concurrent access to same transcription
- [ ] App termination during processing

#### **Edge Cases**

**What We're Testing:**
- Very large transcription texts
- Many versions per transcription
- Concurrent operations
- Resource constraints
- Unusual user behaviors

**Edge Case Testing:**
- [ ] Very large transcription texts
- [ ] Many versions per transcription
- [ ] Concurrent access to same transcription
- [ ] App termination during processing
- [ ] Low memory conditions
- [ ] Disk space limitations
- [ ] Network connectivity issues

---

## 📋 Implementation Checklist

### **Phase 1: Data Models ✅**
- [ ] Create TranscriptionVersion.swift
- [ ] Create EnhancementVersion.swift
- [ ] Enhance Transcription.swift
- [ ] Create VersionMigrationService.swift
- [ ] Test all models and migration
- [ ] Verify backward compatibility
- [ ] Test migration with real data

### **Phase 2: Services ✅**
- [ ] Create AudioStorageService.swift
- [ ] Create EnhancedTranscriptionManager.swift
- [ ] Test audio download functionality
- [ ] Test re-transcription with versioning
- [ ] Test historical enhancement
- [ ] Test error handling
- [ ] Test progress tracking

### **Phase 3: UI Components ✅**
- [ ] Create VersionManagementView.swift
- [ ] Copy and enhance TranscriptionCard → TranscriptionCardV2.swift
- [ ] Copy and enhance TranscriptionHistoryView → TranscriptionHistoryViewV2.swift
- [ ] Test all UI components
- [ ] Verify responsive design
- [ ] Test accessibility
- [ ] Test visual indicators

### **Phase 4: Integration ✅**
- [ ] Update ContentView for side-by-side testing
- [ ] Perform comprehensive testing
- [ ] Optimize performance
- [ ] Handle edge cases and errors
- [ ] Document any issues or limitations
- [ ] Prepare for production deployment

---

## 🚀 Deployment Strategy

### **Development Phase**
1. **Build all components** following this implementation plan
2. **Test side-by-side** with existing V1 functionality
3. **Gather feedback** on new features and UI
4. **Iterate and improve** based on testing results
5. **Document any issues** and create fixes

### **Migration Phase**
1. **Ensure migration works** for all existing data
2. **Test with real user data** (backup first)
3. **Verify performance** with large datasets
4. **Prepare rollback plan** if issues arise
5. **Monitor migration process** for errors

### **Replacement Phase**
1. **Replace V1 with V2** in ContentView
2. **Remove V1 files** cleanly
3. **Update documentation** and user guides
4. **Monitor for issues** post-deployment
5. **Gather user feedback** on new features

---

## 📝 Notes & Considerations

### **Technical Debt**
- Consider refactoring existing AudioPlayerView to use new services
- Evaluate if existing TranscriptionCard can be deprecated
- Plan for future features like version diffing
- Consider performance implications of version storage

### **User Experience**
- Provide clear migration messaging to users
- Consider onboarding for new version management features
- Ensure backward compatibility for user workflows
- Monitor user adoption of new features

### **Future Enhancements**
- Text diffing between versions
- Version branching and merging
- Export of version history
- Analytics on transcription accuracy improvements
- Batch operations on versions
- Version tagging and notes

---

## 🎯 Quick Start Guide

### **To Begin Implementation:**

1. **Start with Phase 1** - Create the data models first
2. **Test each model** thoroughly before moving to next phase
3. **Build services incrementally** in Phase 2
4. **Create UI components** one at a time in Phase 3
5. **Integrate and test** everything in Phase 4

### **Key Files to Create:**
```
VoiceInk/Models/
├── TranscriptionVersion.swift
└── EnhancementVersion.swift

VoiceInk/Services/
├── AudioStorageService.swift
├── EnhancedTranscriptionManager.swift
└── VersionMigrationService.swift

VoiceInk/Views/
├── VersionManagementView.swift
├── TranscriptionCardV2.swift (copy from TranscriptionCard.swift)
└── TranscriptionHistoryViewV2.swift (copy from TranscriptionHistoryView.swift)
```

### **Key Files to Modify:**
```
VoiceInk/Models/Transcription.swift (enhance existing)
VoiceInk/Views/ContentView.swift (add V2 tab)
```

### **Development Order:**
1. **Phase 1**: Data models and migration
2. **Phase 2**: Core services
3. **Phase 3**: UI components (copy then enhance)
4. **Phase 4**: Integration and testing

---

*This implementation plan provides a comprehensive roadmap for building Feature 5: Enhanced History Management. Follow each step carefully and test thoroughly at each phase to ensure a successful implementation.*
