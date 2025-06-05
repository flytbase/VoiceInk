# Feature 4: Enhanced Logging System & Developer Console
## Implementation Document

### 📋 **Executive Summary**

#### **Feature Overview**
Transform VoiceInk's basic error handling into a comprehensive logging system with a powerful developer console. This feature enhances both user experience through better error transparency and developer productivity through advanced debugging capabilities.

#### **Key Objectives**
- **Enhanced Error Management**: Upgrade from basic error alerts to comprehensive logging
- **Developer Console**: Real-time log viewing with search, filtering, and export capabilities
- **History Integration**: Seamlessly integrate logging with the transcription history page
- **Privacy-First**: Ensure no sensitive data is logged while maintaining debugging utility

#### **Success Criteria**
- **Debug Time Reduction**: 60% faster issue identification and resolution
- **User Transparency**: Clear error messages with actionable recovery suggestions
- **Support Efficiency**: 50% reduction in support tickets through better self-service debugging
- **Developer Adoption**: 80% of developers use the console for troubleshooting

#### **Timeline & Resources**
- **Duration**: 6 weeks
- **Team**: 1-2 developers
- **Complexity**: Medium
- **Priority**: High (Q1 2025)

---

## 🏗️ **Technical Architecture**

### **System Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    VoiceInk Application                     │
├─────────────────────────────────────────────────────────────┤
│  UI Layer                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ History Page    │  │ Dev Console     │  │ Error Alerts│ │
│  │ - Error badges  │  │ - Log viewer    │  │ - Enhanced  │ │
│  │ - Quick access  │  │ - Search/filter │  │ - Contextual│ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Service Layer                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              LoggingService (Enhanced)                  │ │
│  │  - Multi-level logging (Debug/Info/Warn/Error)         │ │
│  │  - Category-based organization                         │ │
│  │  - Context metadata capture                            │ │
│  │  - Real-time log streaming                             │ │
│  │  - Export and persistence                              │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Integration Points                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────┐ │
│  │Transcription│ │Enhancement  │ │Search       │ │Network │ │
│  │Services     │ │Services     │ │Services     │ │Layer   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### **Component Relationships**

1. **LoggingService**: Central logging hub that replaces and extends ErrorManager
2. **DeveloperConsoleView**: Advanced UI for log viewing and management
3. **LogEntry Model**: Enhanced data structure for comprehensive log information
4. **Integration Layer**: Logging hooks throughout the application
5. **Export System**: Log export and sharing capabilities

---

## 📊 **Data Models & Interfaces**

### **Core Data Models**

```swift
// MARK: - Log Level Enumeration
enum LogLevel: String, CaseIterable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

// MARK: - Log Category Enumeration
enum LogCategory: String, CaseIterable, Codable {
    case transcription = "Transcription"
    case enhancement = "Enhancement"
    case search = "Search"
    case network = "Network"
    case fileSystem = "FileSystem"
    case ui = "UI"
    case general = "General"
    
    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .enhancement: return "sparkles"
        case .search: return "magnifyingglass"
        case .network: return "network"
        case .fileSystem: return "folder"
        case .ui: return "rectangle.on.rectangle"

        case .general: return "gear"
        }
    }
}

// MARK: - Enhanced Log Entry Model
struct LogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let context: [String: String]
    let stackTrace: String?
    let threadInfo: String
    let memoryUsage: Int64?
    
    // Computed properties for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var shortMessage: String {
        return message.count > 100 ? String(message.prefix(100)) + "..." : message
    }
    
    var hasContext: Bool {
        return !context.isEmpty || stackTrace != nil
    }
}

// MARK: - Log Filter Configuration
struct LogFilter {
    var levels: Set<LogLevel> = Set(LogLevel.allCases)
    var categories: Set<LogCategory> = Set(LogCategory.allCases)
    var searchText: String = ""
    var timeRange: DateInterval?
    
    func matches(_ entry: LogEntry) -> Bool {
        // Level filter
        guard levels.contains(entry.level) else { return false }
        
        // Category filter
        guard categories.contains(entry.category) else { return false }
        
        // Search text filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let messageMatch = entry.message.lowercased().contains(searchLower)
            let contextMatch = entry.context.values.joined().lowercased().contains(searchLower)
            guard messageMatch || contextMatch else { return false }
        }
        
        // Time range filter
        if let timeRange = timeRange {
            guard timeRange.contains(entry.timestamp) else { return false }
        }
        
        return true
    }
}
```

### **Service Interface**

```swift
// MARK: - Logging Service Protocol
protocol LoggingServiceProtocol: ObservableObject {
    var logs: [LogEntry] { get }
    var isDevModeEnabled: Bool { get set }
    var currentFilter: LogFilter { get set }
    
    func debug(_ message: String, category: LogCategory, context: [String: String])
    func info(_ message: String, category: LogCategory, context: [String: String])
    func warning(_ message: String, category: LogCategory, context: [String: String])
    func error(_ message: String, category: LogCategory, context: [String: String], error: Error?)
    
    func clearLogs()
    func exportLogs(format: LogExportFormat) async throws -> URL
    func enableDevMode(_ enabled: Bool)
}

// MARK: - Log Export Formats
enum LogExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case txt = "Plain Text"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .txt: return "txt"
        }
    }
}
```

---

## 🔧 **Implementation Phases**

### **Phase 1: Enhanced Logging Backend (Week 1-2)**

#### **1.1 Upgrade ErrorManager to LoggingService**

**File**: `VoiceInk/Services/LoggingService.swift`

```swift
import SwiftUI
import Foundation
import OSLog

// MARK: - Enhanced Logging Service
@MainActor
class LoggingService: ObservableObject, LoggingServiceProtocol {
    static let shared = LoggingService()
    
    // MARK: - Published Properties
    @Published var logs: [LogEntry] = []
    @Published var isDevModeEnabled: Bool = false
    @Published var currentFilter: LogFilter = LogFilter()
    
    // MARK: - Private Properties
    private let maxLogCount = 1000
    private let logQueue = DispatchQueue(label: "com.voiceink.logging", qos: .utility)
    private let osLogger = Logger(subsystem: "com.voiceink.app", category: "logging")
    
    // MARK: - Initialization
    private init() {
        loadDevModeState()
    }
    
    // MARK: - Public Logging Methods
    func debug(_ message: String, category: LogCategory = .general, context: [String: String] = [:]) {
        log(level: .debug, message: message, category: category, context: context)
    }
    
    func info(_ message: String, category: LogCategory = .general, context: [String: String] = [:]) {
        log(level: .info, message: message, category: category, context: context)
    }
    
    func warning(_ message: String, category: LogCategory = .general, context: [String: String] = [:]) {
        log(level: .warning, message: message, category: category, context: context)
    }
    
    func error(_ message: String, category: LogCategory = .general, context: [String: String] = [:], error: Error? = nil) {
        var enhancedContext = context
        
        if let error = error {
            enhancedContext["error_type"] = String(describing: type(of: error))
            enhancedContext["error_description"] = error.localizedDescription
        }
        
        let stackTrace = error != nil ? Thread.callStackSymbols.joined(separator: "\n") : nil
        
        log(level: .error, message: message, category: category, context: enhancedContext, stackTrace: stackTrace)
    }
    
    // MARK: - Core Logging Implementation
    private func log(
        level: LogLevel,
        message: String,
        category: LogCategory,
        context: [String: String] = [:],
        stackTrace: String? = nil
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            context: context,
            stackTrace: stackTrace,
            threadInfo: Thread.isMainThread ? "Main" : "Background",
            memoryUsage: getCurrentMemoryUsage()
        )
        
        // Add to logs array (main thread)
        logs.insert(entry, at: 0)
        
        // Limit log count
        if logs.count > maxLogCount {
            logs = Array(logs.prefix(maxLogCount))
        }
        
        // Log to system logger
        logToSystem(entry)
        
        // Handle errors specially
        if level == .error {
            handleError(entry)
        }
    }
    
    // MARK: - System Integration
    private func logToSystem(_ entry: LogEntry) {
        let logMessage = "[\(entry.category.rawValue)] \(entry.message)"
        
        switch entry.level {
        case .debug:
            osLogger.debug("\(logMessage)")
        case .info:
            osLogger.info("\(logMessage)")
        case .warning:
            osLogger.warning("\(logMessage)")
        case .error:
            osLogger.error("\(logMessage)")
        }
    }
    
    private func handleError(_ entry: LogEntry) {
        // Convert to VoiceInkError for backward compatibility
        let voiceInkError = VoiceInkError.unknown(entry.message)
        
        // Show error alert if not in dev mode
        if !isDevModeEnabled {
            ErrorManager.shared.handle(voiceInkError)
        }
    }
    
    // MARK: - Utility Methods
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func loadDevModeState() {
        isDevModeEnabled = UserDefaults.standard.bool(forKey: "VoiceInkDevModeEnabled")
    }
    
    // MARK: - Dev Mode Management
    func enableDevMode(_ enabled: Bool) {
        isDevModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "VoiceInkDevModeEnabled")
        
        info("Dev mode \(enabled ? "enabled" : "disabled")", category: .general)
    }
    
    // MARK: - Log Management
    func clearLogs() {
        logs.removeAll()
        info("Logs cleared", category: .general)
    }
    
    func exportLogs(format: LogExportFormat) async throws -> URL {
        let fileName = "voiceink_logs_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let exportData: Data
        
        switch format {
        case .json:
            exportData = try JSONEncoder().encode(logs)
        case .csv:
            exportData = generateCSV().data(using: .utf8) ?? Data()
        case .txt:
            exportData = generatePlainText().data(using: .utf8) ?? Data()
        }
        
        try exportData.write(to: fileURL)
        
        info("Logs exported to \(fileName)", category: .general, context: [
            "format": format.rawValue,
            "entry_count": "\(logs.count)"
        ])
        
        return fileURL
    }
    
    private func generateCSV() -> String {
        var csv = "Timestamp,Level,Category,Message,Context\n"
        
        for entry in logs {
            let contextString = entry.context.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            let escapedMessage = entry.message.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(entry.formattedTimestamp)\",\"\(entry.level.rawValue)\",\"\(entry.category.rawValue)\",\"\(escapedMessage)\",\"\(contextString)\"\n"
        }
        
        return csv
    }
    
    private func generatePlainText() -> String {
        return logs.map { entry in
            var text = "[\(entry.formattedTimestamp)] \(entry.level.rawValue) [\(entry.category.rawValue)] \(entry.message)"
            
            if !entry.context.isEmpty {
                text += "\n  Context: \(entry.context)"
            }
            
            if let stackTrace = entry.stackTrace {
                text += "\n  Stack Trace:\n\(stackTrace)"
            }
            
            return text
        }.joined(separator: "\n\n")
    }
}

// MARK: - Convenience Extensions
extension LoggingService {
    // Quick logging methods for common scenarios
    func logTranscriptionStart(fileName: String, duration: TimeInterval) {
        info("Transcription started", category: .transcription, context: [
            "file_name": fileName,
            "duration": "\(duration)s"
        ])
    }
    
    func logTranscriptionComplete(fileName: String, wordCount: Int, processingTime: TimeInterval) {
        info("Transcription completed", category: .transcription, context: [
            "file_name": fileName,
            "word_count": "\(wordCount)",
            "processing_time": "\(processingTime)s"
        ])
    }
    
    func logSearchQuery(query: String, resultCount: Int, processingTime: TimeInterval) {
        info("Search executed", category: .search, context: [
            "query": query,
            "result_count": "\(resultCount)",
            "processing_time": "\(processingTime)ms"
        ])
    }
    
    func logNetworkRequest(url: String, method: String, statusCode: Int?, responseTime: TimeInterval) {
        let level: LogLevel = (statusCode ?? 0) >= 400 ? .error : .info
        let message = "Network request: \(method) \(url)"
        
        log(level: level, message: message, category: .network, context: [
            "method": method,
            "url": url,
            "status_code": statusCode != nil ? "\(statusCode!)" : "unknown",
            "response_time": "\(responseTime)ms"
        ])
    }
}
```

#### **1.2 Integration Throughout Application**

**Update existing services to use logging:**

```swift
// Example: Enhanced TranscriptionService with logging
extension AudioTranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        let startTime = Date()
        let fileName = audioURL.lastPathComponent
        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0
        
        LoggingService.shared.info("Starting transcription", category: .transcription, context: [
            "file_name": fileName,
            "file_size": "\(fileSize) bytes"
        ])
        
        do {
            let result = try await performTranscription(audioURL)
            let processingTime = Date().timeIntervalSince(startTime)
            
            LoggingService.shared.info("Transcription completed successfully", category: .transcription, context: [
                "file_name": fileName,
                "word_count": "\(result.split(separator: " ").count)",
                "processing_time": "\(processingTime)s"
            ])
            
            return result
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            LoggingService.shared.error("Transcription failed", category: .transcription, context: [
                "file_name": fileName,
                "processing_time": "\(processingTime)s"
            ], error: error)
            
            throw error
        }
    }
}
```

### **Phase 2: Developer Console UI (Week 3-4)**

#### **2.1 Main Developer Console View**

**File**: `VoiceInk/Views/Developer/DeveloperConsoleView.swift`

```swift
import SwiftUI

struct DeveloperConsoleView: View {
    @StateObject private var loggingService = LoggingService.shared
    @State private var searchText = ""
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var selectedCategories: Set<LogCategory> = Set(LogCategory.allCases)
    @State private var showingExportSheet = false
    @State private var showingFilterSheet = false
    @State private var autoScroll = true
    
    private var filteredLogs: [LogEntry] {
        loggingService.logs.filter { entry in
            // Level filter
            guard selectedLevels.contains(entry.level) else { return false }
            
            // Category filter
            guard selectedCategories.contains(entry.category) else { return false }
            
            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let messageMatch = entry.message.lowercased().contains(searchLower)
                let contextMatch = entry.context.values.joined().lowercased().contains(searchLower)
                return messageMatch || contextMatch
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter toolbar
                consoleToolbar
                
                // Log display
                logListView
                
                // Bottom controls
                consoleControls
            }
            .navigationTitle("Developer Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Logs") {
                            showingExportSheet = true
                        }
                        
                        Button("Clear Logs") {
                            loggingService.clearLogs()
                        }
                        
                        Divider()
                        
                        Button("Filters") {
                            showingFilterSheet = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            LogExportView()
        }
        .sheet(isPresented: $showingFilterSheet) {
            LogFilterView(
                selectedLevels: $selectedLevels,
                selectedCategories: $selectedCategories
            )
        }
    }
    
    // MARK: - Console Toolbar
    private var consoleToolbar: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Quick filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        FilterChip(
                            title: level.rawValue,
                            icon: level.icon,
                            isSelected: selectedLevels.contains(level),
                            color: level.color
                        ) {
                            if selectedLevels.contains(level) {
                                selectedLevels.remove(level)
                            } else {
                                selectedLevels.insert(level)
                            }
                        }
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    ForEach(LogCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategories.contains(category),
                            color: .blue
                        ) {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Log List View
    private var logListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: filteredLogs.count) { _, _ in
                if autoScroll && !filteredLogs.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(filteredLogs.first?.id, anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - Console Controls
    private var consoleControls: some View {
        HStack {
            // Log count
            Text("\(filteredLogs.count) of \(loggingService.logs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Auto-scroll toggle
            Button(action: { autoScroll.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                    Text("Auto-scroll")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .foregroundColor(autoScroll ? .blue : .secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
```

#### **2.2 Log Entry Row Component**

**File**: `VoiceInk/Views/Developer/LogEntryRow.swift`

```swift
import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    @State private var showingCopyAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main log row
            logSummaryRow
            
            // Expanded details
            if isExpanded {
                logDetailsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .alert("Copied to Clipboard", isPresented: $showingCopyAlert) {
            Button("OK") { }
        }
    }
    
    // MARK: - Summary Row
    private var logSummaryRow: some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Level indicator
                Image(systemName: entry.level.icon)
                    .foregroundColor(entry.level.color)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                
                // Timestamp
                Text(entry.formattedTimestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                // Category
                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.caption)
                    Text(entry.category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
                .frame(width: 100, alignment: .leading)
                
                // Message
                Text(entry.shortMessage)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // Expansion indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Details View
    private var logDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // Full message
            VStack(alignment: .leading, spacing: 4) {
                Text("Message:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
            }
            
            // Context information
            if !entry.context.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Context:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(entry.context.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text("\(key):")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                
                                Text(entry.context[key] ?? "")
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                }
            }
            
            // Stack trace
            if let stackTrace = entry.stackTrace {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stack Trace:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(stackTrace)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                }
            }
            
            // Metadata
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thread: \(entry.threadInfo)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let memoryUsage = entry.memoryUsage {
                        Text("Memory: \(ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button("Copy") {
                        copyLogEntry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if entry.level == .error {
                        Button("Report") {
                            // Report error functionality
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    // MARK: - Actions
    private func copyLogEntry() {
        let logText = generateLogText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
        showingCopyAlert = true
    }
    
    private func generateLogText() -> String {
        var text = "[\(entry.formattedTimestamp)] \(entry.level.rawValue) [\(entry.category.rawValue)] \(entry.message)"
        
        if !entry.context.isEmpty {
            text += "\nContext:\n"
            for (key, value) in entry.context {
                text += "  \(key): \(value)\n"
            }
        }
        
        if let stackTrace = entry.stackTrace {
            text += "\nStack Trace:\n\(stackTrace)"
        }
        
        return text
    }
}
```

#### **2.3 Additional UI Components**

**File**: `VoiceInk/Views/Developer/LogExportView.swift`

```swift
import SwiftUI
import UniformTypeIdentifiers

struct LogExportView: View {
    @StateObject private var loggingService = LoggingService.shared
    @State private var selectedFormat: LogExportFormat = .json
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Export format selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.headline)
                    
                    ForEach(LogExportFormat.allCases, id: \.self) { format in
                        HStack {
                            Button(action: { selectedFormat = format }) {
                                HStack {
                                    Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedFormat == format ? .blue : .secondary)
                                    
                                    VStack(alignment: .leading) {
                                        Text(format.rawValue)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        Text(formatDescription(format))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Export info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Information")
                        .font(.headline)
                    
                    HStack {
                        Text("Total Logs:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(loggingService.logs.count)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("File Size (approx):")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(estimatedFileSize())
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
                
                // Export button
                Button(action: exportLogs) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Text(isExporting ? "Exporting..." : "Export Logs")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || loggingService.logs.isEmpty)
            }
            .padding()
            .navigationTitle("Export Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = exportedFileURL {
                ShareSheet(items: [fileURL])
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatDescription(_ format: LogExportFormat) -> String {
        switch format {
        case .json:
            return "Structured data format, best for programmatic analysis"
        case .csv:
            return "Spreadsheet format, good for data analysis"
        case .txt:
            return "Human-readable format, easy to view and share"
        }
    }
    
    private func estimatedFileSize() -> String {
        let avgLogSize = 200 // Estimated bytes per log entry
        let totalSize = loggingService.logs.count * avgLogSize
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    private func exportLogs() {
        isExporting = true
        
        Task {
            do {
                let fileURL = try await loggingService.exportLogs(format: selectedFormat)
                
                await MainActor.run {
                    exportedFileURL = fileURL
                    isExporting = false
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    // Handle error
                    LoggingService.shared.error("Failed to export logs", category: .general, error: error)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

### **Phase 3: History Page Integration (Week 5)**

#### **3.1 Enhanced TranscriptionHistoryViewV2 Integration**

**Update**: `VoiceInk/Views/TranscriptionHistoryViewV2.swift`

```swift
// Add to existing TranscriptionHistoryViewV2

// MARK: - Enhanced Header with Dev Mode
private var headerView: some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Enhanced History")
                    .font(.title2)
                    .fontWeight(.bold)

                // V2 Badge
                Text("V2")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
                    
                // Dev Mode Indicator
                if LoggingService.shared.isDevModeEnabled {
                    Text("DEV")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
            }

            Text("Advanced version management and AI enhancements")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        Spacer()

        // Stats and Dev Console Access
        HStack(spacing: 16) {
            StatBadge(
                title: "Total",
                value: "\(transcriptions.count)",
                color: .blue
            )

            StatBadge(
                title: "Versions",
                value: "\(totalVersions)",
                color: .green
            )

            StatBadge(
                title: "Enhanced",
                value: "\(enhancedCount)",
                color: .purple
            )
            
            // Dev Console Access
            if LoggingService.shared.isDevModeEnabled {
                Button(action: { showingDevConsole = true }) {
                    VStack(spacing: 2) {
                        Image(systemName: "terminal")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("Console")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    .padding()
    .background(Color(.controlBackgroundColor))
}

// Add state variable
@State private var showingDevConsole = false

// Add to body
.sheet(isPresented: $showingDevConsole) {
    DeveloperConsoleView()
}

// Add logging to operations
private func retranscribe(_ transcription: Transcription) {
    LoggingService.shared.info("Retranscription started", category: .transcription, context: [
        "transcription_id": transcription.id.uuidString,
        "original_duration": "\(transcription.duration)s"
    ])
    
    Task {
        do {
            try await enhancedManager.retranscribeWithVersioning(
                transcription: transcription,
                modelContext: modelContext,
                whisperState: WhisperState(modelContext: modelContext)
            )
            
            LoggingService.shared.info("Retranscription completed", category: .transcription, context: [
                "transcription_id": transcription.id.uuidString
            ])
        } catch {
            LoggingService.shared.error("Retranscription failed", category: .transcription, context: [
                "transcription_id": transcription.id.uuidString
            ], error: error)
        }
    }
}
```

#### **3.2 Error Indicators in Transcription Cards**

**Update**: `VoiceInk/Views/TranscriptionCardV2.swift`

```swift
// Add error indicator to card header
private var cardHeader: some View {
    HStack {
        // Existing header content...
        
        Spacer()
        
        // Error indicator
        if hasRecentErrors {
            Button(action: { showingErrorDetails = true }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
}

// Add computed property
private var hasRecentErrors: Bool {
    let recentErrors = LoggingService.shared.logs.filter { entry in
        entry.level == .error &&
        entry.context["transcription_id"] == transcription.id.uuidString &&
        Date().timeIntervalSince(entry.timestamp) < 300 // Last 5 minutes
    }
    return !recentErrors.isEmpty
}

// Add state and sheet
@State private var showingErrorDetails = false

.sheet(isPresented: $showingErrorDetails) {
    TranscriptionErrorDetailsView(transcriptionId: transcription.id)
}
```

### **Phase 4: Advanced Features & Testing (Week 6)**

#### **4.2 Testing Strategy**

**File**: `VoiceInkTests/LoggingServiceTests.swift`

```swift
import XCTest
@testable import VoiceInk

class LoggingServiceTests: XCTestCase {
    var loggingService: LoggingService!
    
    override func setUp() {
        super.setUp()
        loggingService = LoggingService.shared
        loggingService.clearLogs()
    }
    
    func testBasicLogging() {
        // Test basic logging functionality
        loggingService.info("Test message", category: .general)
        
        XCTAssertEqual(loggingService.logs.count, 1)
        XCTAssertEqual(loggingService.logs.first?.message, "Test message")
        XCTAssertEqual(loggingService.logs.first?.level, .info)
    }
    
    func testErrorLogging() {
        // Test error logging with context
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: nil)
        
        loggingService.error("Test error", category: .transcription, context: [
            "file_name": "test.wav"
        ], error: testError)
        
        XCTAssertEqual(loggingService.logs.count, 1)
        let logEntry = loggingService.logs.first!
        
        XCTAssertEqual(logEntry.level, .error)
        XCTAssertEqual(logEntry.category, .transcription)
        XCTAssertTrue(logEntry.context.keys.contains("file_name"))
        XCTAssertNotNil(logEntry.stackTrace)
    }
    
    func testLogFiltering() {
        // Test log filtering functionality
        loggingService.debug("Debug message", category: .general)
        loggingService.info("Info message", category: .transcription)
        loggingService.error("Error message", category: .network)
        
        var filter = LogFilter()
        filter.levels = [.error]
        
        let filteredLogs = loggingService.logs.filter { filter.matches($0) }
        
        XCTAssertEqual(filteredLogs.count, 1)
        XCTAssertEqual(filteredLogs.first?.level, .error)
    }
    
    func testLogExport() async throws {
        // Test log export functionality
        loggingService.info("Test export", category: .general)
        
        let fileURL = try await loggingService.exportLogs(format: .json)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let data = try Data(contentsOf: fileURL)
        let logs = try JSONDecoder().decode([LogEntry].self, from: data)
        
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.message, "Test export")
    }
}
```

---

## 📋 **Implementation Checklist**

### **Phase 1: Backend (Week 1-2)**
- [ ] Create LogLevel and LogCategory enums
- [ ] Implement LogEntry model with full metadata
- [ ] Create LoggingService to replace ErrorManager
- [ ] Add system logger integration (OSLog)
- [ ] Implement memory usage tracking
- [ ] Add convenience logging methods
- [ ] Integrate logging throughout existing services
- [ ] Test basic logging functionality

### **Phase 2: UI (Week 3-4)**
- [ ] Create DeveloperConsoleView with search/filter
- [ ] Implement LogEntryRow with expandable details
- [ ] Add FilterChip component for quick filtering
- [ ] Create LogExportView with format selection
- [ ] Implement ShareSheet for file sharing
- [ ] Add auto-scroll and real-time updates
- [ ] Test UI responsiveness with large log volumes
- [ ] Add accessibility support

### **Phase 3: Integration (Week 5)**
- [ ] Add dev mode toggle to TranscriptionHistoryViewV2
- [ ] Integrate error indicators in transcription cards
- [ ] Add logging to all transcription operations
- [ ] Add logging to search operations
- [ ] Add logging to enhancement operations
- [ ] Create TranscriptionErrorDetailsView
- [ ] Test integration with existing workflows

### **Phase 4: Polish (Week 6)**
- [ ] Add comprehensive unit tests
- [ ] Add UI tests for developer console
- [ ] Performance optimization for large log volumes
- [ ] Add crash reporting integration
- [ ] Documentation and user guides
- [ ] Final testing and bug fixes

---

## 🎯 **Success Metrics**

### **Technical Metrics**
- **Log Performance**: <1ms overhead per log entry
- **Memory Usage**: <50MB for 1000 log entries
- **Search Performance**: <100ms for 1000 entries
- **Export Speed**: <5 seconds for 1000 entries

### **User Experience Metrics**
- **Error Resolution Time**: 60% reduction
- **Support Ticket Volume**: 50% reduction
- **Developer Satisfaction**: >4.5/5 rating
- **Feature Adoption**: >70% of developers use console

### **Quality Metrics**
- **Bug Detection**: 80% of issues caught in logs
- **False Positives**: <5% of logged errors
- **Log Completeness**: 95% of operations logged
- **Privacy Compliance**: 100% sensitive data excluded

---

## 🔒 **Privacy & Security**

### **Data Protection**
- **No Audio Content**: Never log actual audio data or transcription text
- **Sanitized Context**: Remove personal information from context data
- **Local Storage**: All logs stored locally, never transmitted
- **Automatic Cleanup**: Logs expire after 7 days

### **Dev Mode Security**
- **Hidden by Default**: Requires manual activation
- **User Control**: Can be disabled at any time
- **No Remote Access**: Console only accessible locally
- **Audit Trail**: Log access is logged

---

## 📚 **Documentation & Training**

### **Developer Documentation**
- **API Reference**: Complete LoggingService API documentation
- **Integration Guide**: How to add logging to new features
- **Best Practices**: Guidelines for effective logging
- **Troubleshooting**: Common issues and solutions

### **User Guides**
- **Dev Mode Activation**: How to enable developer features
- **Console Usage**: Guide to using the developer console
- **Log Export**: How to export and share logs
- **Privacy Information**: What data is and isn't logged

---

*This implementation document provides a complete roadmap for implementing Feature 4: Enhanced Logging System & Developer Console. The modular approach allows for iterative development and testing, ensuring a robust and user-friendly debugging experience.*
