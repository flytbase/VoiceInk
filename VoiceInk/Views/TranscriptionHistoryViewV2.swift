import SwiftData
import SwiftUI

struct TranscriptionHistoryViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var enhancedManager = EnhancedTranscriptionManager.shared
    @StateObject private var migrationService = VersionMigrationService()
    @StateObject private var searchService = OptimizedSearchService.shared
    @Query(sort: \Transcription.timestamp, order: .reverse) private var transcriptions:
        [Transcription]

    @State private var enhancementService: AIEnhancementService?
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var selectedTranscriptions = Set<Transcription>()
    @State private var expandedTranscription: Transcription?
    @State private var showingDeleteAlert = false
    @State private var showingMigrationAlert = false
    @State private var isMigrating = false
    @State private var isMultiSelectMode = false

    private var displayedTranscriptions: [Transcription] {
        let baseResults = searchText.isEmpty ? transcriptions : searchService.searchResults

        // Apply filter
        switch selectedFilter {
        case .all:
            return baseResults
        case .hasVersions:
            return baseResults.filter { !$0.transcriptionVersions.isEmpty }
        case .hasEnhancements:
            return baseResults.filter { !$0.enhancementVersions.isEmpty }
        case .recent:
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            return baseResults.filter { $0.timestamp >= sevenDaysAgo }
        case .longDuration:
            return baseResults.filter { $0.duration > 60 }  // More than 1 minute
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with V2 indicator
            headerView

            // Migration alert if needed
            if showingMigrationAlert {
                migrationAlertView
            }

            // Optimized search bar with filters
            OptimizedSearchBar(
                searchText: $searchText,
                selectedFilter: $selectedFilter,
                searchService: searchService
            )
            .padding(.horizontal)
            .padding(.bottom)

            // Content
            if displayedTranscriptions.isEmpty {
                emptyStateView
            } else {
                optimizedTranscriptionsList
            }

            // Selection toolbar
            if !selectedTranscriptions.isEmpty {
                selectionToolbar
            }
        }
        // Enhanced page background for better card contrast
        .background(Color(.controlBackgroundColor).opacity(1.25))
        .navigationTitle("Enhanced History")
        .onAppear {
            checkMigrationStatus()
            if enhancementService == nil {
                enhancementService = AIEnhancementService(modelContext: modelContext)
            }
            // Build search index for optimized search
            searchService.buildSearchIndex(from: transcriptions)
        }
        .onChange(of: transcriptions) { _, newTranscriptions in
            // Update search index when transcriptions change
            searchService.buildSearchIndex(from: newTranscriptions)
        }
        // Search handling moved to OptimizedSearchBar to avoid duplicate onChange conflicts
        .alert("Delete Transcriptions", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
        } message: {
            Text(
                "Are you sure you want to delete \(selectedTranscriptions.count) transcription(s)? This action cannot be undone."
            )
        }
    }

    // MARK: - Header View

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
                }

                Text("Advanced version management and AI enhancements")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Stats
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
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Migration Alert View

    private var migrationAlertView: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Migration Available")
                    .font(.headline)

                Text("Your existing transcriptions can be upgraded to support version management.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isMigrating {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Migrate Now") {
                    performMigration()
                }
                .buttonStyle(.borderedProminent)

                Button("Later") {
                    showingMigrationAlert = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Search Bar View

    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search transcriptions and versions...", text: $searchText)
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
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Optimized Transcriptions List

    private var optimizedTranscriptionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(displayedTranscriptions) { transcription in
                    OptimizedTranscriptionCard(
                        transcription: transcription,
                        isExpanded: expandedTranscription == transcription,
                        isSelected: selectedTranscriptions.contains(transcription),
                        modelContext: modelContext,
                        enhancementService: enhancementService
                            ?? AIEnhancementService(modelContext: modelContext)
                    ) {
                        toggleSelection(transcription)
                    }
                    .contextMenu {
                        contextMenuItems(for: transcription)
                    }
                    // Safe performance optimizations
                    .clipped()  // Prevent rendering outside bounds
                }
            }
            .padding(.horizontal)
        }
        // Additional performance optimizations
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Transcriptions Found")
                .font(.title2)
                .fontWeight(.medium)

            Text(
                searchText.isEmpty
                    ? "Start recording to see your transcriptions here with enhanced version management."
                    : "No transcriptions match your search criteria."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        HStack {
            Text("\(selectedTranscriptions.count) selected")
                .font(.headline)

            Spacer()

            Button("Select All") {
                selectedTranscriptions = Set(displayedTranscriptions)
            }
            .buttonStyle(.bordered)

            // Multi-select toggle button
            Button(action: {
                isMultiSelectMode.toggle()
                if !isMultiSelectMode {
                    // When switching to single-select, keep only the first selected item
                    if let first = selectedTranscriptions.first {
                        selectedTranscriptions = [first]
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isMultiSelectMode ? "checkmark.square" : "square")
                    Text("Multi-Select")
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(isMultiSelectMode ? .blue : .primary)

            Button("Deselect") {
                selectedTranscriptions.removeAll()
            }
            .buttonStyle(.bordered)

            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for transcription: Transcription) -> some View {
        Button("Re-transcribe") {
            retranscribe(transcription)
        }

        Button("Enhance") {
            // This would open enhancement options
        }

        if transcription.audioFileURL != nil {
            Button("Download") {
                downloadAudio(transcription)
            }
        }

        Button("Copy") {
            copyText(transcription)
        }

        if transcription.hasMultipleVersions {
            Button("Versions") {
                // This would show version history
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            selectedTranscriptions = [transcription]
            showingDeleteAlert = true
        }
    }

    // MARK: - Computed Properties

    private var totalVersions: Int {
        transcriptions.reduce(0) { $0 + $1.transcriptionVersions.count }
    }

    private var enhancedCount: Int {
        transcriptions.filter { !$0.enhancementVersions.isEmpty }.count
    }

    // MARK: - Actions

    private func checkMigrationStatus() {
        do {
            let needsMigration = try VersionMigrationService.needsMigration(
                modelContext: modelContext)
            showingMigrationAlert = needsMigration
        } catch {
            print("Failed to check migration status: \(error)")
        }
    }

    private func performMigration() {
        isMigrating = true

        Task {
            do {
                try await VersionMigrationService.migrateExistingTranscriptions(
                    modelContext: modelContext)

                await MainActor.run {
                    isMigrating = false
                    showingMigrationAlert = false
                }
            } catch {
                await MainActor.run {
                    isMigrating = false
                    // Show error alert
                    print("Migration failed: \(error)")
                }
            }
        }
    }

    private func toggleSelection(_ transcription: Transcription) {
        // Always expand the clicked card and select it
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedTranscription = transcription
        }

        if isMultiSelectMode {
            // Multi-select mode: toggle selection
            if selectedTranscriptions.contains(transcription) {
                selectedTranscriptions.remove(transcription)
            } else {
                selectedTranscriptions.insert(transcription)
            }
        } else {
            // Single-select mode: select only this item, deselect others
            selectedTranscriptions = [transcription]
        }
    }

    private func deleteSelectedTranscriptions() {
        for transcription in selectedTranscriptions {
            modelContext.delete(transcription)
        }

        do {
            try modelContext.save()
            selectedTranscriptions.removeAll()
        } catch {
            print("Failed to delete transcriptions: \(error)")
        }
    }

    private func retranscribe(_ transcription: Transcription) {
        Task {
            do {
                try await enhancedManager.retranscribeWithVersioning(
                    transcription: transcription,
                    modelContext: modelContext,
                    whisperState: WhisperState(modelContext: modelContext)
                )
            } catch {
                print("Re-transcription failed: \(error)")
            }
        }
    }

    private func downloadAudio(_ transcription: Transcription) {
        Task {
            do {
                _ = try await AudioStorageService.shared.downloadAudio(from: transcription)
            } catch {
                print("Audio download failed: \(error)")
            }
        }
    }

    private func copyText(_ transcription: Transcription) {
        let text = transcription.mainVersion?.text ?? transcription.text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transcription.self, configurations: config)

    TranscriptionHistoryViewV2()
        .modelContainer(container)
}
