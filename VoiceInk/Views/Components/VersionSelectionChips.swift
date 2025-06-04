import SwiftData
import SwiftUI

struct VersionSelectionChips: View {
    let transcription: Transcription
    let selectedTranscriptionVersionId: UUID?
    let selectedEnhancementVersionId: UUID?
    let onSelectTranscriptionVersion: (UUID) -> Void
    let onSelectEnhancementVersion: (UUID) -> Void

    private var sortedTranscriptionVersions: [TranscriptionVersion] {
        transcription.transcriptionVersions.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private var selectedTranscriptionVersion: TranscriptionVersion? {
        if let selectedId = selectedTranscriptionVersionId {
            return transcription.transcriptionVersions.first { $0.id == selectedId }
        }
        return transcription.latestVersion ?? transcription.mainVersion
    }

    private func enhancementsForVersion(_ versionId: UUID) -> [EnhancementVersion] {
        return transcription.enhancementVersions
            .filter { $0.baseVersionId == versionId }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Transcription version chips
            if !sortedTranscriptionVersions.isEmpty {
                // Transcription version chips with proper labeling
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(sortedTranscriptionVersions.enumerated()), id: \.element.id) {
                            index, version in
                            let versionNumber = sortedTranscriptionVersions.count - index
                            VersionChip(
                                label:
                                    "\(version.transcriptionMethod) • T\(versionNumber) • \(version.createdAt.formatted(date: .omitted, time: .shortened))",
                                isSelected: selectedTranscriptionVersionId == version.id,
                                isMain: version.isMainVersion,
                                confidence: version.confidence,
                                method: version.transcriptionMethod
                            ) {
                                onSelectTranscriptionVersion(version.id)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // Enhancement chips removed - they belong in Enhanced Text panel only
        }
    }
}

// MARK: - Supporting Components

struct VersionChip: View {
    let label: String
    let isSelected: Bool
    let isMain: Bool
    let confidence: Double?
    let method: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isMain {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }

                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)

                if let confidence = confidence {
                    Text("\(Int(confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : Color(.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color(.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EnhancementChip: View {
    let label: String
    let isSelected: Bool
    let method: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.purple : Color.purple.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.purple : Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let sampleTranscription = Transcription(text: "Sample", duration: 125.0)

    VersionSelectionChips(
        transcription: sampleTranscription,
        selectedTranscriptionVersionId: nil,
        selectedEnhancementVersionId: nil,
        onSelectTranscriptionVersion: { _ in },
        onSelectEnhancementVersion: { _ in }
    )
    .padding()
}
