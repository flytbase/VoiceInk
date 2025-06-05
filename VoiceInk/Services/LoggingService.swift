import SwiftUI
import Foundation
import OSLog

// Import existing error handling for backward compatibility
// Note: This creates a temporary dependency that will be resolved as we migrate

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

// MARK: - Enhanced Logging Service
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
        setupApplicationMonitoring()
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
        
        // Process logging on background queue for performance
        logQueue.async {
            // Log to system logger (can be done on background thread)
            self.logToSystem(entry)
            
            // Handle errors specially
            if level == .error {
                self.handleError(entry)
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.logs.insert(entry, at: 0)
                
                // Limit log count
                if self.logs.count > self.maxLogCount {
                    self.logs = Array(self.logs.prefix(self.maxLogCount))
                }
            }
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
        // TODO: Integrate with ErrorManager for backward compatibility
        // For now, just log to console in dev mode
        if isDevModeEnabled {
            print("ERROR: [\(entry.category.rawValue)] \(entry.message)")
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
    
    private func setupApplicationMonitoring() {
        // Monitor app lifecycle for logging
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.info("App became active", category: .general)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.info("App resigned active", category: .general)
        }
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
