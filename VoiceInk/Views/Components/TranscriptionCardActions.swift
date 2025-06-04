import SwiftData
import SwiftUI

struct TranscriptionCardActions: View {
    let transcription: Transcription
    let isExpanded: Bool
    let hasEnhancements: Bool
    let isRetranscribing: Bool
    let isEnhancing: Bool

    let onCopyRaw: () -> Void
    let onCopyEnhanced: () -> Void
    let onRetranscribe: () -> Void
    let onEnhance: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if isExpanded {
            expandedActions
        } else {
            collapsedActions
        }
    }

    // MARK: - Collapsed Actions

    private var collapsedActions: some View {
        HStack(spacing: 12) {
            // Essential actions only
            ActionButton(
                icon: "doc.on.doc",
                label: "Copy Raw",
                color: .primary,
                action: onCopyRaw
            )

            ActionButton(
                icon: "sparkles",
                label: "Copy Enhanced",
                color: .purple,
                isDisabled: !hasEnhancements,
                action: onCopyEnhanced
            )

            Spacer()

            // Actions dropdown
            Menu {
                Button("Re-transcribe") {
                    onRetranscribe()
                }

                Button("Enhance") {
                    onEnhance()
                }

                if transcription.audioFileURL != nil {
                    Button("Download") {
                        onDownload()
                    }
                }

                Divider()

                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Actions")
                        .font(.caption)
                    Image(systemName: "ellipsis")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Expanded Actions

    private var expandedActions: some View {
        HStack(spacing: 12) {
            // Essential actions - Dual copy buttons
            ActionButton(
                icon: "doc.on.doc",
                label: "Copy Raw",
                color: .primary,
                action: onCopyRaw
            )

            ActionButton(
                icon: "sparkles",
                label: "Copy Enhanced",
                color: .purple,
                isDisabled: !hasEnhancements,
                action: onCopyEnhanced
            )

            ActionButton(
                icon: "arrow.clockwise",
                label: "Re-transcribe",
                color: .green,
                isLoading: isRetranscribing,
                action: onRetranscribe
            )

            ActionButton(
                icon: "wand.and.stars",
                label: "Enhance",
                color: .purple,
                isLoading: isEnhancing,
                action: onEnhance
            )

            Spacer()

            // Secondary actions
            if transcription.audioFileURL != nil {
                ActionButton(
                    icon: "arrow.down.circle",
                    label: "Download",
                    color: .blue,
                    action: onDownload
                )
            }

            ActionButton(
                icon: "trash",
                label: "Delete",
                color: .red,
                action: onDelete
            )
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var rotationAngle: Double = 0

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if isLoading {
                        // Use SwiftUI-native rotating icon instead of ProgressView
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .rotationEffect(.degrees(rotationAngle))
                            .onReceive(
                                Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
                            ) { _ in
                                if isLoading {
                                    rotationAngle += 36  // 10 steps per second = smooth rotation
                                }
                            }
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(buttonColor)

                Text(label)
                    .font(.caption)
                    .foregroundColor(textColor)
            }
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)

        .help(isDisabled ? "No enhancements available" : label)
    }

    private var buttonColor: Color {
        if isLoading {
            // Force original color during loading (don't grey out spinning animation)
            return color
        } else if isDisabled {
            return .secondary.opacity(0.5)
        } else {
            return color
        }
    }

    private var textColor: Color {
        if isDisabled {
            return .secondary
        } else {
            return .primary
        }
    }
}

#Preview {
    let sampleTranscription = Transcription(text: "Sample", duration: 125.0)

    VStack(spacing: 20) {
        TranscriptionCardActions(
            transcription: sampleTranscription,
            isExpanded: false,
            hasEnhancements: true,
            isRetranscribing: false,
            isEnhancing: false,
            onCopyRaw: {},
            onCopyEnhanced: {},
            onRetranscribe: {},
            onEnhance: {},
            onDownload: {},
            onDelete: {}
        )

        TranscriptionCardActions(
            transcription: sampleTranscription,
            isExpanded: true,
            hasEnhancements: false,
            isRetranscribing: true,
            isEnhancing: false,
            onCopyRaw: {},
            onCopyEnhanced: {},
            onRetranscribe: {},
            onEnhance: {},
            onDownload: {},
            onDelete: {}
        )
    }
    .padding()
}
