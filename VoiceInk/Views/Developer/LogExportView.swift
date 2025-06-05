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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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
struct ShareSheet: NSViewControllerRepresentable {
    let items: [Any]
    
    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: nsViewController.view, preferredEdge: .minY)
    }
}

// MARK: - Preview
#Preview {
    LogExportView()
}
