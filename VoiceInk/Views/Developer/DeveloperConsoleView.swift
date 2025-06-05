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
        VStack(spacing: 0) {
            // Header with title and controls
            consoleHeader
            
            // Search and filter toolbar
            consoleToolbar
            
            // Log display
            logListView
            
            // Bottom controls
            consoleControls
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
    
    // MARK: - Console Header
    private var consoleHeader: some View {
        HStack {
            Text("Developer Console")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
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
                    .font(.title2)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .bottom
        )
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
                        LogFilterChip(
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
                        LogFilterChip(
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


// MARK: - Log Filter Chip Component
struct LogFilterChip: View {
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

// MARK: - Preview
#Preview {
    DeveloperConsoleView()
}
