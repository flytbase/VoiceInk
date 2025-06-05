import SwiftData
import SwiftUI

// MARK: - Constants

private enum Constants {
    static let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60
    static let longDurationThreshold: Double = 60.0
    static let animationDuration: Double = 0.2
    static let headerSpacing: CGFloat = 4
    static let cardSpacing: CGFloat = 12
    static let badgePadding: CGFloat = 6
    static let badgeVerticalPadding: CGFloat = 2
    static let cornerRadius: CGFloat = 8
    static let emptyStateIconSize: CGFloat = 48
    static let emptyStateHorizontalPadding: CGFloat = 32
}

// MARK: - View Model

@MainActor
final class TranscriptionHistoryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFilter: SearchFilter = .all
    @Published var selectedTranscriptions = Set<Transcription>()
    @Published var expandedTranscription: Transcription?
    @Published var showingDeleteAlert = false
    @Published var showingMigrationAlert = false
    @Published var isMigrating = false
    @Published var isMultiSelectMode = false
    
    private let modelContext: ModelContext
    private let enhancedManager: EnhancedTranscriptionManager
    private let searchService: OptimizedSearchService
    private let loggingService: LoggingService
    
    var enhancementService: AIEnhancementService?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.enhancedManager = EnhancedTranscriptionManager.shared
        self.searchService = OptimizedSearchService.shared
        self.loggingService = LoggingService.shared
        self.enhancementService = AIEnhancementService(modelContext: modelContext)
    }
    
    func displayedTranscriptions(from transcriptions: [Transcription]) -> [Transcription] {
        let baseResults = searchText.isEmpty ? transcriptions : searchService.searchResults
        return applyFilter(to: baseResults)
    }
    
    private func applyFilter(to transcriptions: [Transcription]) -> [Transcription] {
        switch selectedFilter {
        case .all:
            return transcriptions
        case .hasVersions:
            return transcriptions.filter { !$0.transcriptionVersions.isEmpty }
        case .hasEnhancements:
            return transcriptions.filter { !$0.enhancementVersions.isEmpty }
        case .recent:
            let sevenDaysAgo = Date().addingTimeInterval(-Constants.sevenDaysInSeconds)
            return transcriptions.filter { $0.timestamp >= sevenDaysAgo }
        case .longDuration:
            return transcriptions.filter { $0.duration > Constants.longDurationThreshold }
        }
    }
    
    func toggleSelection(_ transcription: Transcription) {
        expandedTranscription = transcription
        
        if isMultiSelectMode {
            if selectedTranscriptions.contains(transcription) {
                selectedTranscriptions.remove(transcription)
            } else {
                selectedTranscriptions.insert(transcription)
            }
        } else {
            selectedTranscriptions = [transcription]
        }
    }
    
    func selectAll(from transcriptions: [Transcription]) {
        selectedTranscriptions = Set(transcriptions)
    }
    
    func deselectAll() {
        selectedTranscriptions.removeAll()
    }
    
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode, let first = selectedTranscriptions.first {
            selectedTranscriptions = [first]
        }
    }
}

// MARK: - Main View

struct TranscriptionHistoryViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: TranscriptionHistoryViewModel
    @StateObject private var migrationService = VersionMigrationService()
    @StateObject private var loggingService = LoggingService.shared
    @Query(sort: \Transcription.timestamp, order: .reverse) private var transcriptions: [Transcription]
    
    init() {
        // Note: We'll initialize viewModel in onAppear since we need modelContext
        self._viewModel = StateObject(wrappedValue: TranscriptionHistoryViewModel(modelContext: ModelContext(try! ModelContainer(for: Transcription.self))))
    }
    
    private var displayedTranscriptions: [Transcription] {
        viewModel.displayedTranscriptions(from: transcriptions)
    }
    
    private var statisticsData: StatisticsData {
        StatisticsData(
            totalCount: transcriptions.count,
            totalVersions: transcriptions.reduce(0) { $0 + $1.transcriptionVersions.count },
            enhancedCount: transcriptions.filter { !$0.enhancementVersions.isEmpty }.count
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                statisticsData: statisticsData,
                isDevModeEnabled: loggingService.isDevModeEnabled
            )
            
            if viewModel.showingMigrationAlert {
                MigrationAlertView(
                    isMigrating: viewModel.isMigrating,
                    onMigrate: performMigration,
                    onDismiss: { viewModel.showingMigrationAlert = false }
                )
            }
            
            SearchBarSection(
                searchText: $viewModel.searchText,
                selectedFilter: $viewModel.selectedFilter
            )
            
            ContentSection(
                transcriptions: displayedTranscriptions,
                viewModel: viewModel,
                modelContext: modelContext
            )
            
            if !viewModel.selectedTranscriptions.isEmpty {
                SelectionToolbarView(
                    selectedCount: viewModel.selectedTranscriptions.count,
                    isMultiSelectMode: viewModel.isMultiSelectMode,
                    onSelectAll: { viewModel.selectAll(from: displayedTranscriptions) },
                    onDeselectAll: viewModel.deselectAll,
                    onToggleMultiSelect: viewModel.toggleMultiSelectMode,
                    onDelete: { viewModel.showingDeleteAlert = true }
                )
            }
        }
        .background(Color(.controlBackgroundColor).opacity(1.25))
        .navigationTitle("History")
        .onAppear {
            setupView()
        }
        .onChange(of: transcriptions) { _, newTranscriptions in
            OptimizedSearchService.shared.buildSearchIndex(from: newTranscriptions)
        }
        .alert("Delete Transcriptions", isPresented: $viewModel.showingDeleteAlert) {
            deleteAlert
        } message: {
            deleteAlertMessage
        }
    }
    
    // MARK: - Alert Components
    
    private var deleteAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
        }
    }
    
    private var deleteAlertMessage: some View {
        Text("Are you sure you want to delete \(viewModel.selectedTranscriptions.count) transcription(s)? This action cannot be undone.")
    }
    
    // MARK: - Setup and Actions
    
    private func setupView() {
        // Reinitialize viewModel with correct modelContext
        let newViewModel = TranscriptionHistoryViewModel(modelContext: modelContext)
        // Transfer state if needed
        newViewModel.searchText = viewModel.searchText
        newViewModel.selectedFilter = viewModel.selectedFilter
        
        checkMigrationStatus()
        OptimizedSearchService.shared.buildSearchIndex(from: transcriptions)
    }
    
    private func checkMigrationStatus() {
        do {
            let needsMigration = try VersionMigrationService.needsMigration(modelContext: modelContext)
            viewModel.showingMigrationAlert = needsMigration
        } catch {
            loggingService.error("Failed to check migration status", category: .general, error: error)
        }
    }
    
    private func performMigration() {
        viewModel.isMigrating = true
        
        Task {
            do {
                try await VersionMigrationService.migrateExistingTranscriptions(modelContext: modelContext)
                await MainActor.run {
                    viewModel.isMigrating = false
                    viewModel.showingMigrationAlert = false
                }
            } catch {
                await MainActor.run {
                    viewModel.isMigrating = false
                    loggingService.error("Migration failed", category: .general, error: error)
                }
            }
        }
    }
    
    private func deleteSelectedTranscriptions() {
        let transcriptionsToDelete = Array(viewModel.selectedTranscriptions)
        
        for transcription in transcriptionsToDelete {
            modelContext.delete(transcription)
        }
        
        do {
            try modelContext.save()
            viewModel.selectedTranscriptions.removeAll()
            loggingService.info("Deleted \(transcriptionsToDelete.count) transcriptions", category: .general)
        } catch {
            loggingService.error("Failed to delete transcriptions", category: .general, error: error)
        }
    }
}

// MARK: - Supporting Data Structures

struct StatisticsData {
    let totalCount: Int
    let totalVersions: Int
    let enhancedCount: Int
}

// MARK: - Header View

struct HeaderView: View {
    let statisticsData: StatisticsData
    let isDevModeEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                titleSection
                subtitleSection
            }
            
            Spacer()
            
            statisticsSection
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("History header with statistics")
    }
    
    private var titleSection: some View {
        HStack {
            Text("History")
                .font(.title2)
                .fontWeight(.bold)
            
            BadgeView(text: "V2", color: .blue)
            
            if isDevModeEnabled {
                BadgeView(text: "DEV", color: .orange)
            }
        }
    }
    
    private var subtitleSection: some View {
        Text("Advanced version management and AI enhancements")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatBadge(title: "Total", value: "\(statisticsData.totalCount)", color: .blue)
            StatBadge(title: "Versions", value: "\(statisticsData.totalVersions)", color: .green)
            StatBadge(title: "Enhanced", value: "\(statisticsData.enhancedCount)", color: .purple)
            
            if isDevModeEnabled {
                DevConsoleButton()
            }
        }
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, Constants.badgePadding)
            .padding(.vertical, Constants.badgeVerticalPadding)
            .background(color)
            .cornerRadius(4)
    }
}

// MARK: - Dev Console Button

struct DevConsoleButton: View {
    var body: some View {
        Button(action: {
            DeveloperConsoleWindowManager.shared.toggleConsole()
        }) {
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
        .accessibilityLabel("Open developer console")
    }
}

// MARK: - Migration Alert View

struct MigrationAlertView: View {
    let isMigrating: Bool
    let onMigrate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                Text("Migration Available")
                    .font(.headline)
                
                Text("Your existing transcriptions can be upgraded to support version management.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            actionButtons
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(Constants.cornerRadius)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Migration alert")
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        if isMigrating {
            ProgressView()
                .scaleEffect(0.8)
                .accessibilityLabel("Migration in progress")
        } else {
            HStack {
                Button("Migrate Now", action: onMigrate)
                    .buttonStyle(.borderedProminent)
                
                Button("Later", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Search Bar Section

struct SearchBarSection: View {
    @Binding var searchText: String
    @Binding var selectedFilter: SearchFilter
    
    var body: some View {
        OptimizedSearchBar(
            searchText: $searchText,
            selectedFilter: $selectedFilter,
            searchService: OptimizedSearchService.shared
        )
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Content Section

struct ContentSection: View {
    let transcriptions: [Transcription]
    @ObservedObject var viewModel: TranscriptionHistoryViewModel
    let modelContext: ModelContext
    
    var body: some View {
        if transcriptions.isEmpty {
            HistoryEmptyStateView(hasSearchText: !viewModel.searchText.isEmpty)
        } else {
            TranscriptionsList(
                transcriptions: transcriptions,
                viewModel: viewModel,
                modelContext: modelContext
            )
        }
    }
}

// MARK: - History Empty State View

struct HistoryEmptyStateView: View {
    let hasSearchText: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: Constants.emptyStateIconSize))
                .foregroundColor(.secondary)
            
            Text("No Transcriptions Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.emptyStateHorizontalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(emptyStateMessage)
    }
    
    private var emptyStateMessage: String {
        hasSearchText
            ? "No transcriptions match your search criteria."
            : "Start recording to see your transcriptions here with enhanced version management."
    }
}

// MARK: - Transcriptions List

struct TranscriptionsList: View {
    let transcriptions: [Transcription]
    @ObservedObject var viewModel: TranscriptionHistoryViewModel
    let modelContext: ModelContext
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Constants.cardSpacing) {
                ForEach(transcriptions) { transcription in
                    OptimizedTranscriptionCard(
                        transcription: transcription,
                        isExpanded: viewModel.expandedTranscription == transcription,
                        isSelected: viewModel.selectedTranscriptions.contains(transcription),
                        modelContext: modelContext,
                        enhancementService: viewModel.enhancementService ?? AIEnhancementService(modelContext: modelContext),
                        onTap: { viewModel.toggleSelection(transcription) }
                    )
                    .animation(.easeInOut(duration: Constants.animationDuration), value: viewModel.expandedTranscription == transcription)
                    .clipped()
                }
            }
            .padding(.horizontal)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Selection Toolbar

struct SelectionToolbarView: View {
    let selectedCount: Int
    let isMultiSelectMode: Bool
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onToggleMultiSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text("\(selectedCount) selected")
                .font(.headline)
            
            Spacer()
            
            Button("Select All", action: onSelectAll)
                .buttonStyle(.bordered)
            
            Button(action: onToggleMultiSelect) {
                HStack(spacing: 4) {
                    Image(systemName: isMultiSelectMode ? "checkmark.square" : "square")
                    Text("Multi-Select")
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(isMultiSelectMode ? .blue : .primary)
            
            Button("Deselect", action: onDeselectAll)
                .buttonStyle(.bordered)
            
            Button("Delete", role: .destructive, action: onDelete)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection toolbar with \(selectedCount) items selected")
    }
}


// MARK: - Stat Badge Component

struct StatBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transcription.self, configurations: config)

    TranscriptionHistoryViewV2()
        .modelContainer(container)
}
