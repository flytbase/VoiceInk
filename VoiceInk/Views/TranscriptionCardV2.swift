import SwiftData
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let copyFeedbackDuration: UInt64 = 2_000_000_000  // 2 seconds
    static let successMessageDuration: UInt64 = 3_000_000_000  // 3 seconds
    static let previewTextLimit = 150
    static let previewLineLimit = 2
}



struct TranscriptionCardV2: View {
    let transcription: Transcription
    let isExpanded: Bool
    let isSelected: Bool
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var enhancementService: AIEnhancementService
    
    @StateObject private var viewModel: TranscriptionCardViewModel
    
    init(transcription: Transcription, isExpanded: Bool, isSelected: Bool = false, viewModel: TranscriptionCardViewModel? = nil) {
        self.transcription = transcription
        self.isExpanded = isExpanded
        self.isSelected = isSelected
        
        if let providedViewModel = viewModel {
            // Use the provided ViewModel (from pool)
            self._viewModel = StateObject(wrappedValue: providedViewModel)
        } else {
            // Create a new ViewModel (fallback) with safe error handling
            do {
                let container = try ModelContainer(for: Transcription.self)
                let modelContext = ModelContext(container)
                let enhancementService = AIEnhancementService(modelContext: modelContext)
                
                self._viewModel = StateObject(wrappedValue: TranscriptionCardViewModel(
                    transcription: transcription,
                    modelContext: modelContext,
                    enhancementService: enhancementService,
                    loggingService: LoggingService.shared
                ))
            } catch {
                // Fallback to a minimal ViewModel that handles the error gracefully
                print("Failed to create ModelContainer: \(error.localizedDescription)")
                // Create a minimal fallback ViewModel
                self._viewModel = StateObject(wrappedValue: TranscriptionCardViewModel.fallback(
                    transcription: transcription,
                    error: error
                ))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 16 : 12) {
            // Header with metadata and indicators (always visible)
            headerView

            if isExpanded {
                // Dual-pane text display with show more/less
                expandedTextView
                    .onAppear {
                        // Set default selections if none are set
                        // ViewModel handles default selections automatically
                    }
                    .onChange(of: viewModel.selectionState.selectedTranscriptionVersionId) { _, newVersionId in
                        // ViewModel handles auto-selection of enhancements
                    }

                // Audio Player with waveform (optimized for smooth scrolling)
                if let urlString = transcription.audioFileURL,
                    let url = URL(string: urlString),
                    FileManager.default.fileExists(atPath: url.path)
                {
                    Divider()
                        .padding(.vertical, 8)

                    AudioPlayerView(url: url)
                        // Safe performance optimizations only
                        .clipped()  // Prevent rendering outside bounds (safe)
                        .padding(.horizontal, 4)
                }

                // All action buttons (expanded only)
                expandedActionButtonsView
            } else {
                // Text preview (collapsed only)
                collapsedTextPreview

                // Essential action buttons (collapsed only)
                collapsedActionButtonsView
            }
        }
        .padding(16)
        // Improved tonal contrast for card background
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.75))
        )
        // Enhanced border with selected state
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.8) : Color.primary.opacity(0.15), lineWidth: isSelected ? 2.0 : 1.2)
        )
        // Simple static shadow for better performance
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)

        .alert("Delete Transcription", isPresented: $viewModel.feedbackState.showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTranscription()
            }
        } message: {
            Text("This action cannot be undone. All versions and enhancements will be deleted.")
        }
        .alert("Error", isPresented: $viewModel.feedbackState.showingError) {
            Button("OK") {}
        } message: {
            Text(viewModel.feedbackState.errorMessage)
        }
        .overlay(
            // Success/Error notifications
            VStack {
                if viewModel.processingState.showRetranscribeSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Re-transcription successful")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }

                if viewModel.feedbackState.showCopyFeedback {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundColor(.blue)
                        Text(viewModel.feedbackState.copyFeedbackMessage)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }

                Spacer()
            }
            .padding(.top, 16)
        )
    }

    // MARK: - Computed Properties (delegated to ViewModel)
    
    private var selectedTranscriptionVersion: TranscriptionVersion? {
        viewModel.selectedTranscriptionVersion
    }
    
    private var hasEnhancements: Bool {
        viewModel.hasEnhancements
    }
    
    private var selectedEnhancementVersion: EnhancementVersion? {
        viewModel.selectedEnhancementVersion
    }
    
    private var previewText: String {
        viewModel.previewText
    }

    // MARK: - Header View

    private var headerView: some View {
        TranscriptionCardHeader(transcription: transcription)
    }

    // MARK: - Collapsed Text Preview

    private var collapsedTextPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(previewText)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(Constants.previewLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Expanded Text View

    private var expandedTextView: some View {
        HStack(spacing: 16) {
            // Raw Transcription Panel
            VStack(alignment: .leading, spacing: 8) {
                // Header with title and show more button
                HStack {
                    Text("Raw Transcription")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(viewModel.uiState.showMoreRawText ? "Show Less" : "Show More") {
                        viewModel.toggleRawTextExpansion()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)

                }

                // Version selection chips
                VersionSelectionChips(
                    transcription: transcription,
                    selectedTranscriptionVersionId: viewModel.selectionState.selectedTranscriptionVersionId,
                    selectedEnhancementVersionId: viewModel.selectionState.selectedEnhancementVersionId,
                    onSelectTranscriptionVersion: { versionId in
                        viewModel.selectTranscriptionVersion(versionId)
                    },
                    onSelectEnhancementVersion: { enhancementId in
                        viewModel.selectEnhancementVersion(enhancementId)
                    }
                )

                // Text content with show more/less
                Text(selectedTranscriptionVersion?.text ?? transcription.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .lineLimit(viewModel.uiState.showMoreRawText ? nil : 3)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.textBackgroundColor))
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            }

            // Enhanced Text Panel
            VStack(alignment: .leading, spacing: 8) {
                // Header with title and show more button
                HStack {
                    Text("Enhanced Text")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    if let selectedVersion = selectedTranscriptionVersion {
                        let enhancements = viewModel.enhancementsForVersion(selectedVersion.id)
                        if !enhancements.isEmpty {
                            Button(viewModel.uiState.showMoreEnhancedText ? "Show Less" : "Show More") {
                                viewModel.toggleEnhancedTextExpansion()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Beautiful chip selection for enhancement versions
                if let selectedVersion = selectedTranscriptionVersion {
                    let enhancements = viewModel.enhancementsForVersion(selectedVersion.id)
                    if !enhancements.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(enhancements.enumerated()), id: \.element.id) {
                                    index, enhancement in
                                    let versionIndex =
                                        viewModel.sortedTranscriptionVersions.firstIndex {
                                            $0.id == selectedVersion.id
                                        } ?? 0
                                    let transcriptionNumber =
                                        viewModel.sortedTranscriptionVersions.count - versionIndex

                                    EnhancementChip(
                                        label:
                                            "\(enhancement.enhancementMethod) • E\(transcriptionNumber).\(enhancements.count - index) • \(enhancement.createdAt.formatted(date: .omitted, time: .shortened))",
                                        isSelected: selectedEnhancementVersion?.id
                                            == enhancement.id,
                                        method: enhancement.enhancementMethod
                                    ) {
                                        viewModel.selectEnhancementVersion(enhancement.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    } else {
                        Text("No enhancements available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                // Enhanced text content
                Group {
                    if let selectedVersion = selectedTranscriptionVersion {
                        let enhancements = viewModel.enhancementsForVersion(selectedVersion.id)
                        if !enhancements.isEmpty {
                            if let selectedId = viewModel.selectionState.selectedEnhancementVersionId,
                                let enhancement = transcription.enhancementVersions.first(where: {
                                    $0.id == selectedId
                                })
                            {
                                Text(enhancement.enhancedText)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(
                                        maxWidth: .infinity, maxHeight: .infinity,
                                        alignment: .topLeading
                                    )
                                    .lineLimit(viewModel.uiState.showMoreEnhancedText ? nil : 3)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.purple.opacity(0.05))
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            } else if let latestEnhancement = enhancements.first {
                                Text(latestEnhancement.enhancedText)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(
                                        maxWidth: .infinity, maxHeight: .infinity,
                                        alignment: .topLeading
                                    )
                                    .lineLimit(viewModel.uiState.showMoreEnhancedText ? nil : 3)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.purple.opacity(0.05))
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundColor(.secondary)

                                Text("No enhancements available")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.05))
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            Text("No enhancements available")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.05))
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Collapsed Action Buttons

    private var collapsedActionButtonsView: some View {
        TranscriptionCardActions(
            transcription: transcription,
            isExpanded: false,
            hasEnhancements: hasEnhancements,
            isRetranscribing: viewModel.processingState.isRetranscribing,
            isEnhancing: viewModel.processingState.isEnhancing,
            onCopyRaw: copyRawText,
            onCopyEnhanced: copyEnhancedText,
            onRetranscribe: performRetranscribeAction,
            onEnhance: performEnhanceAction,
            onDownload: downloadAudio,
            onDelete: { viewModel.showDeleteAlert() }
        )
    }

    // MARK: - Expanded Action Buttons

    private var expandedActionButtonsView: some View {
        TranscriptionCardActions(
            transcription: transcription,
            isExpanded: true,
            hasEnhancements: hasEnhancements,
            isRetranscribing: viewModel.processingState.isRetranscribing,
            isEnhancing: viewModel.processingState.isEnhancing,
            onCopyRaw: copyRawText,
            onCopyEnhanced: copyEnhancedText,
            onRetranscribe: performRetranscribeAction,
            onEnhance: performEnhanceAction,
            onDownload: downloadAudio,
            onDelete: { viewModel.showDeleteAlert() }
        )
    }



    // MARK: - Helper Functions

    // MARK: - Actions

    private func copyRawText() {
        viewModel.copyRawText()
    }

    private func copyEnhancedText() {
        viewModel.copyEnhancedText()
    }



    private func performRetranscribeAction() {
        print("🔄 [DEBUG] performRetranscribeAction() called")
        print("🔄 [DEBUG] Current isRetranscribing: \(viewModel.processingState.isRetranscribing)")
        
        Task {
            await viewModel.performRetranscription()
            print("🔄 [DEBUG] performRetranscription() completed")
        }
    }

    private func performEnhanceAction() {
        Task {
            await viewModel.performEnhancement()
        }
    }

    private func downloadAudio() {
        Task {
            await viewModel.downloadAudio()
        }
    }

    private func deleteTranscription() {
        viewModel.deleteTranscription()
    }
}



#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transcription.self, configurations: config)
    let enhancementService = AIEnhancementService(modelContext: container.mainContext)

    let sampleTranscription = Transcription(
        text:
            "This is a sample transcription that demonstrates the new collapsed/expanded layout with version management features. This text is long enough to show the preview functionality.",
        duration: 15.0
    )

    TranscriptionCardV2(transcription: sampleTranscription, isExpanded: false)
        .modelContainer(container)
        .environmentObject(enhancementService)
        .padding()
        .frame(width: 800, height: 600)
}
