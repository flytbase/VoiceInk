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

// MARK: - Preview
#Preview {
    LogEntryRow(entry: LogEntry(
        timestamp: Date(),
        level: .error,
        category: .transcription,
        message: "Failed to transcribe audio file due to network timeout",
        context: [
            "file_name": "recording_001.wav",
            "file_size": "2.5MB",
            "duration": "45s"
        ],
        stackTrace: "Stack trace would appear here...",
        threadInfo: "Main",
        memoryUsage: 1024 * 1024 * 50 // 50MB
    ))
    .padding()
}
