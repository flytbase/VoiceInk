import Foundation
import SwiftData
import SwiftUI

// MARK: - ViewModel Pool Manager

@MainActor
class ViewModelPool: ObservableObject {
    static let shared = ViewModelPool()

    private var pool: [UUID: TranscriptionCardViewModel] = [:]
    private var inUse: Set<UUID> = []
    private let maxPoolSize = 20  // Limit pool size to prevent memory bloat

    private init() {}

    // MARK: - Pool Management

    func getViewModel(
        for transcription: Transcription,
        modelContext: ModelContext,
        enhancementService: AIEnhancementService
    ) -> TranscriptionCardViewModel {
        let id = transcription.id

        // Check if we already have a ViewModel for this transcription
        if let existingViewModel = pool[id] {
            inUse.insert(id)
            return existingViewModel
        }

        // Create new ViewModel
        let viewModel = TranscriptionCardViewModel(
            transcription: transcription,
            modelContext: modelContext,
            enhancementService: enhancementService
        )

        // Add to pool if we have space
        if pool.count < maxPoolSize {
            pool[id] = viewModel
        }

        inUse.insert(id)
        return viewModel
    }

    func releaseViewModel(for transcriptionId: UUID) {
        inUse.remove(transcriptionId)

        // Clean up unused ViewModels periodically
        if inUse.count < pool.count / 2 {
            cleanupUnusedViewModels()
        }
    }

    private func cleanupUnusedViewModels() {
        let unusedIds = Set(pool.keys).subtracting(inUse)

        // Keep some unused ViewModels for quick reuse, but not too many
        let toRemove = Array(unusedIds).prefix(max(0, unusedIds.count - 5))

        for id in toRemove {
            pool.removeValue(forKey: id)
        }
    }

    func clearPool() {
        pool.removeAll()
        inUse.removeAll()
    }
}

// MARK: - Lightweight Card Preview

struct TranscriptionCardPreview: View {
    let transcription: Transcription
    let isSelected: Bool
    let onTap: () -> Void

    private var previewText: String {
        // Use latest transcription version for preview, not the base text
        let text = transcription.latestVersion?.text ?? transcription.text
        let lines = text.components(separatedBy: .newlines)
        let previewLines = Array(lines.prefix(2))
        let preview = previewLines.joined(separator: "\n")
        return preview.count > 150 ? String(preview.prefix(150)) + "..." : preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lightweight header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transcription.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if transcription.duration > 0 {
                        Text(formatDuration(transcription.duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Header indicators - matching expanded state
                HStack(spacing: 8) {
                    // Version indicator
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(transcription.transcriptionVersions.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                    
                    // Enhancement indicator
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("\(transcription.enhancementVersions.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
                    
                }
            }

            // Preview text
            Text(previewText)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Action buttons for collapsed state
            HStack(spacing: 12) {
                ActionButton(
                    icon: "doc.on.doc",
                    label: "Copy Raw",
                    color: .primary
                ) {
                    copyRawText()
                }

                ActionButton(
                    icon: "sparkles",
                    label: "Copy Enhanced",
                    color: .purple,
                    isDisabled: transcription.enhancementVersions.isEmpty
                ) {
                    copyEnhancedText()
                }

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.blue : Color.primary.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1.2)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func copyRawText() {
        let text = transcription.latestVersion?.text ?? transcription.text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyEnhancedText() {
        guard
            let latestEnhancement = transcription.enhancementVersions.sorted(by: {
                $0.createdAt > $1.createdAt
            }).first
        else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestEnhancement.enhancedText, forType: .string)
    }
}

// MARK: - Optimized Card Container

struct OptimizedTranscriptionCard: View {
    let transcription: Transcription
    let isExpanded: Bool
    let isSelected: Bool
    let modelContext: ModelContext
    let enhancementService: AIEnhancementService
    let onTap: () -> Void

    @StateObject private var viewModelPool = ViewModelPool.shared
    @StateObject private var audioManager = AudioTranscriptionManager.shared
    @State private var viewModel: TranscriptionCardViewModel?

    var body: some View {
        ZStack {
            // Main card content
            cardContent
            
            // Progress overlay (only when this transcription is being re-transcribed)
            if audioManager.activeRetranscriptions.contains(transcription.id) {
                retranscriptionProgressOverlay
            }
        }
    }
    
    private var cardContent: some View {
        Group {
            if isExpanded {
                // Full card with ViewModel
                if let pooledViewModel = viewModel {
                    TranscriptionCardV2(
                        transcription: transcription,
                        isExpanded: true,
                        isSelected: isSelected,
                        viewModel: pooledViewModel
                    )
                    .environmentObject(enhancementService)
                } else {
                    // Loading state
                    TranscriptionCardPreview(
                        transcription: transcription,
                        isSelected: isSelected,
                        onTap: onTap
                    )
                    .redacted(reason: .placeholder)
                }
            } else {
                // Lightweight preview
                TranscriptionCardPreview(
                    transcription: transcription,
                    isSelected: isSelected,
                    onTap: onTap
                )
            }
        }
        .onAppear {
            if isExpanded && viewModel == nil {
                loadViewModel()
            }
        }
        .onDisappear {
            if !isExpanded {
                releaseViewModel()
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                loadViewModel()
            } else {
                releaseViewModel()
            }
        }
    }
    
    private var retranscriptionProgressOverlay: some View {
        StreamingProgressView(
            streamingState: audioManager.streamingState,
            liveText: audioManager.liveTranscriptionText,
            context: .reTranscription,
            variant: isExpanded ? .full : .compact,
            onCancel: {
                audioManager.cancelStreamingProcessing()
            }
        )
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 12 : 8)
                .fill(Color.black.opacity(0.3))
        )
        .animation(.easeInOut(duration: 0.3), value: audioManager.activeRetranscriptions.contains(transcription.id))
    }

    private func loadViewModel() {
        viewModel = viewModelPool.getViewModel(
            for: transcription,
            modelContext: modelContext,
            enhancementService: enhancementService
        )
    }

    private func releaseViewModel() {
        if viewModel != nil {
            viewModelPool.releaseViewModel(for: transcription.id)
            self.viewModel = nil
        }
    }
}
