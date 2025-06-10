import SwiftUI
import AppKit
import Foundation

/// A comprehensive view for displaying streaming transcription progress following macOS design patterns
struct StreamingProgressView: View {
    let streamingState: StreamingState
    let liveText: String
    let context: TranscriptionContext
    let variant: ProgressVariant
    let onCancel: () -> Void
    
    enum ProgressVariant {
        case full     // Modal/standalone (480-640px)
        case compact  // History card (280-350px)
    }
    
    // Default initializer for backward compatibility
    init(
        streamingState: StreamingState,
        liveText: String,
        onCancel: @escaping () -> Void
    ) {
        self.streamingState = streamingState
        self.liveText = liveText
        self.context = .newTranscription
        self.variant = .full
        self.onCancel = onCancel
    }
    
    // Full initializer with all options
    init(
        streamingState: StreamingState,
        liveText: String,
        context: TranscriptionContext,
        variant: ProgressVariant,
        onCancel: @escaping () -> Void
    ) {
        self.streamingState = streamingState
        self.liveText = liveText
        self.context = context
        self.variant = variant
        self.onCancel = onCancel
    }
    
    var body: some View {
        Group {
            switch variant {
            case .full:
                fullLayout
            case .compact:
                compactLayout
            }
        }
    }
    
    // MARK: - Layout Variants
    
    private var fullLayout: some View {
        VStack(spacing: 16) {
            // Header with icon and title (macOS-style)
            headerSection
            
            // Progress content
            progressContent
            
            // Live text display (macOS-style)
            if !liveText.isEmpty {
                liveTextSection
            }
            
            // Action buttons (macOS-style)
            actionButtons
        }
        .padding(20)
        .frame(minWidth: 480, maxWidth: 640)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    private var compactLayout: some View {
        VStack(spacing: 8) {
            // Compact header with inline cancel
            compactHeaderSection
            
            // Progress bar
            ProgressView(value: streamingState.overallProgress)
                .progressViewStyle(MacOSProgressViewStyle())
                .frame(height: 6)
            
            // Live text (compact)
            if !liveText.isEmpty {
                compactLiveTextSection
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: progressIcon)
                .font(.title2)
                .foregroundColor(progressColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(progressTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(progressSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress percentage (macOS-style monospaced)
            if streamingState.overallProgress > 0 {
                Text("\(Int(streamingState.overallProgress * 100))%")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Progress Content
    
    private var progressContent: some View {
        VStack(spacing: 12) {
            // Main progress bar (macOS-style)
            ProgressView(value: streamingState.overallProgress)
                .progressViewStyle(MacOSProgressViewStyle())
                .frame(height: 8)
            
            // Status message
            if !statusMessage.isEmpty {
                HStack {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Live Text Section
    
    private var liveTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Transcription")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Streaming indicator (macOS-style)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: liveText)
                    
                    Text("Live")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Text content with macOS-style background
            ScrollView {
                Text(liveText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Compact Sections
    
    private var compactHeaderSection: some View {
        HStack(spacing: 8) {
            Image(systemName: progressIcon)
                .font(.subheadline)
                .foregroundColor(progressColor)
                .frame(width: 16, height: 16)
            
            Text(contextualProgressTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Progress percentage
            if streamingState.overallProgress > 0 {
                Text("\(Int(streamingState.overallProgress * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Inline cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var compactLiveTextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Live Text")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Compact streaming indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: liveText)
            }
            
            // Compact text display
            Text(liveText)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack {
            Spacer()
            
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(MacOSSecondaryButtonStyle())
            .keyboardShortcut(.escape)
        }
    }
    
    // MARK: - Computed Properties
    
    private var progressIcon: String {
        switch streamingState {
        case .idle:
            return "waveform.path.ecg"
        case .preprocessing:
            return "waveform.path.ecg"
        case .uploading:
            return "icloud.and.arrow.up"
        case .streaming:
            return "text.bubble"
        case .finalizing:
            return "checkmark.circle"
        case .complete:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    private var progressColor: Color {
        switch streamingState {
        case .idle:
            return .secondary
        case .preprocessing:
            return .orange
        case .uploading:
            return .blue
        case .streaming:
            return .green
        case .finalizing:
            return .purple
        case .complete:
            return .green
        case .error:
            return .red
        }
    }
    
    private var progressTitle: String {
        switch streamingState {
        case .idle:
            return "Preparing"
        case .preprocessing:
            return "Optimizing Audio"
        case .uploading:
            return "Uploading to Gemini"
        case .streaming:
            return "Streaming Transcription"
        case .finalizing:
            return "Finalizing"
        case .complete:
            return "Complete"
        case .error:
            return "Error"
        }
    }
    
    private var progressSubtitle: String {
        switch streamingState {
        case .idle:
            return "Getting ready..."
        case .preprocessing:
            return "Optimizing audio for Gemini processing"
        case .uploading:
            return "Uploading audio file to Gemini Files API"
        case .streaming:
            return "Processing with Gemini"
        case .finalizing:
            return "Completing transcription and cleanup"
        case .complete:
            return "Transcription completed successfully"
        case .error(let message):
            return message
        }
    }
    
    private var statusMessage: String {
        switch streamingState {
        case .uploading(let progress):
            return "Upload progress: \(Int(progress * 100))%"
        case .streaming(let progress, _):
            return "Transcription progress: \(Int(progress * 100))%"
        default:
            return ""
        }
    }
    
    private var contextualProgressTitle: String {
        // Use context-aware titles for compact display
        switch streamingState {
        case .idle:
            return context.progressTitle
        case .preprocessing:
            return "Optimizing Audio"
        case .uploading:
            return "Uploading"
        case .streaming:
            return context.progressTitle
        case .finalizing:
            return "Finalizing"
        case .complete:
            return context.completionMessage
        case .error:
            return "Error"
        }
    }
}

// MARK: - macOS-specific Button Styles

struct MacOSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
            .foregroundColor(.primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MacOSProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 8)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(
                        width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
                        height: 8
                    )
                    .animation(.easeInOut(duration: 0.3), value: configuration.fractionCompleted)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Upload state
        StreamingProgressView(
            streamingState: .uploading(progress: 0.4),
            liveText: "",
            onCancel: {}
        )
        
        // Streaming state
        StreamingProgressView(
            streamingState: .streaming(progress: 0.6, liveText: "This is a sample transcription..."),
            liveText: "This is a sample transcription that appears in real-time as the audio is being processed by Gemini. The text updates continuously as new chunks are processed.",
            onCancel: {}
        )
    }
    .padding()
    .frame(width: 700, height: 600)
    .background(Color(NSColor.windowBackgroundColor))
}
