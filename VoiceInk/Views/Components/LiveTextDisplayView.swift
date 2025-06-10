import SwiftUI
import AppKit

/// A view for displaying live transcription text with macOS-style design patterns
struct LiveTextDisplayView: View {
    let text: String
    let isStreaming: Bool
    let confidence: Double
    
    init(text: String, isStreaming: Bool = true, confidence: Double = 1.0) {
        self.text = text
        self.isStreaming = isStreaming
        self.confidence = confidence
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with streaming indicator
            headerSection
            
            // Text content area
            textContentArea
            
            // Footer with confidence and word count
            footerSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(streamingBorderColor, lineWidth: isStreaming ? 1.5 : 0.5)
                        .animation(.easeInOut(duration: 0.3), value: isStreaming)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Live Transcription")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Streaming status indicator
            streamingIndicator
        }
    }
    
    // MARK: - Text Content Area
    
    private var textContentArea: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    Text(text.isEmpty ? placeholderText : text)
                        .font(.body)
                        .foregroundColor(text.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("textContent")
                        .opacity(confidenceOpacity)
                        .animation(.easeInOut(duration: 0.2), value: confidence)
                }
                .onChange(of: text) { _, newText in
                    // Auto-scroll to bottom when new text arrives
                    if isStreaming && !newText.isEmpty {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("textContent", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 80, maxHeight: 200)
        .background(Color.clear)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            // Word count
            if !text.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.123")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Confidence indicator
            if confidence < 1.0 && !text.isEmpty {
                confidenceIndicator
            }
        }
    }
    
    // MARK: - Streaming Indicator
    
    private var streamingIndicator: some View {
        HStack(spacing: 6) {
            if isStreaming {
                // Animated streaming dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(streamingOpacity)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: streamingOpacity
                    )
                
                Text("Streaming")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Confidence Indicator
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon)
                .font(.caption)
                .foregroundColor(confidenceColor)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .help("Transcription confidence level")
    }
    
    // MARK: - Computed Properties
    
    private var placeholderText: String {
        isStreaming ? "Listening for audio..." : "No transcription available"
    }
    
    private var wordCount: Int {
        text.split(separator: " ").count
    }
    
    private var streamingBorderColor: Color {
        isStreaming ? Color.accentColor : Color(NSColor.separatorColor)
    }
    
    private var streamingOpacity: Double {
        isStreaming ? 1.0 : 0.3
    }
    
    private var confidenceOpacity: Double {
        max(0.6, confidence)
    }
    
    private var confidenceIcon: String {
        switch confidence {
        case 0.9...1.0:
            return "checkmark.circle"
        case 0.7..<0.9:
            return "exclamationmark.triangle"
        default:
            return "questionmark.circle"
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.9...1.0:
            return .green
        case 0.7..<0.9:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - macOS-specific Extensions

extension LiveTextDisplayView {
    /// Creates a view optimized for macOS window sizing
    func macOSOptimized() -> some View {
        self
            .frame(minWidth: 320, maxWidth: .infinity)
            .frame(minHeight: 120, maxHeight: 300)
    }
    
    /// Creates a compact version suitable for smaller spaces
    func compact() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Transcription")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isStreaming {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(streamingOpacity)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: streamingOpacity
                        )
                }
            }
            
            Text(text.isEmpty ? placeholderText : text)
                .font(.caption)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(8)
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

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Streaming state
        LiveTextDisplayView(
            text: "This is a sample transcription that appears in real-time as the audio is being processed. The text updates continuously as new words are recognized by the speech recognition system.",
            isStreaming: true,
            confidence: 0.92
        )
        .macOSOptimized()
        
        // Complete state
        LiveTextDisplayView(
            text: "This is a completed transcription with high confidence.",
            isStreaming: false,
            confidence: 0.98
        )
        .macOSOptimized()
        
        // Low confidence state
        LiveTextDisplayView(
            text: "This transcription has lower confidence due to audio quality issues.",
            isStreaming: true,
            confidence: 0.65
        )
        .macOSOptimized()
        
        // Compact version
        LiveTextDisplayView(
            text: "Compact version for smaller spaces.",
            isStreaming: true,
            confidence: 0.85
        )
        .compact()
        
        // Empty state
        LiveTextDisplayView(
            text: "",
            isStreaming: true,
            confidence: 1.0
        )
        .macOSOptimized()
    }
    .padding()
    .frame(width: 600, height: 800)
    .background(Color(NSColor.windowBackgroundColor))
}
