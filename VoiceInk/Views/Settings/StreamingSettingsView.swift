import SwiftUI
import AppKit

struct StreamingSettingsView: View {
    // Essential Settings (5 settings)
    @AppStorage("streamingEnabled") private var streamingEnabled = true
    @AppStorage("streamingMaxFileSize") private var streamingMaxFileSize = 500.0
    @AppStorage("streamingShowLiveText") private var streamingShowLiveText = true
    @AppStorage("streamingPreprocessAudio") private var streamingPreprocessAudio = true
    @AppStorage("streamingProgressUpdateInterval") private var streamingProgressUpdateInterval = 0.1
    
    // Advanced Settings (2 settings)
    @AppStorage("streamingUploadTimeout") private var streamingUploadTimeout = 300.0
    @AppStorage("streamingTranscriptionTimeout") private var streamingTranscriptionTimeout = 600.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Settings content
            ScrollView {
                VStack(spacing: 20) {
                    generalSection
                    
                    if streamingEnabled {
                        fileSizeSection
                        userInterfaceSection
                        advancedSection
                        resetSection
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform.badge.plus")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Streaming Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack {
                Text("Configure real-time streaming transcription for long audio files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        MacOSSettingsSection(
            title: "General",
            description: "Streaming transcription provides real-time feedback for long audio files by processing them in chunks."
        ) {
            Toggle("Enable Streaming Transcription", isOn: $streamingEnabled)
                .toggleStyle(MacOSToggleStyle())
        }
    }
    
    
    // MARK: - File Size Section
    
    private var fileSizeSection: some View {
        MacOSSettingsSection(
            title: "File Size Limits",
            description: "Maximum file size supported for streaming transcription."
        ) {
            MacOSSliderSetting(
                title: "Maximum File Size",
                value: $streamingMaxFileSize,
                range: 100...1000,
                step: 50,
                unit: "MB",
                description: "Maximum file size supported for streaming"
            )
        }
    }
    
    // MARK: - User Interface Section
    
    private var userInterfaceSection: some View {
        MacOSSettingsSection(
            title: "User Interface",
            description: "Customize the streaming experience and visual feedback."
        ) {
            VStack(spacing: 12) {
                Toggle("Show Live Text", isOn: $streamingShowLiveText)
                    .toggleStyle(MacOSToggleStyle())
                    .help("Display transcription text as it's being processed")
                
                Toggle("Preprocess Audio", isOn: $streamingPreprocessAudio)
                    .toggleStyle(MacOSToggleStyle())
                    .help("Apply audio preprocessing before streaming")
                
                MacOSSliderSetting(
                    title: "Progress Update Interval",
                    value: $streamingProgressUpdateInterval,
                    range: 0.05...1.0,
                    step: 0.05,
                    unit: "seconds",
                    description: "How often to update the progress display",
                    formatter: { String(format: "%.2f", $0) }
                )
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        MacOSSettingsSection(
            title: "Advanced Settings",
            description: "Configure timeout values for streaming operations."
        ) {
            VStack(spacing: 16) {
                MacOSSliderSetting(
                    title: "Upload Timeout",
                    value: $streamingUploadTimeout,
                    range: 60...600,
                    step: 30,
                    unit: "seconds",
                    description: "Maximum time to wait for file upload to complete"
                )
                
                MacOSSliderSetting(
                    title: "Transcription Timeout",
                    value: $streamingTranscriptionTimeout,
                    range: 300...1800,
                    step: 60,
                    unit: "seconds",
                    description: "Maximum time to wait for streaming transcription"
                )
            }
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        MacOSSettingsSection(
            title: "Reset",
            description: "Reset all streaming settings to their default values."
        ) {
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(MacOSDestructiveButtonStyle())
                
                Spacer()
            }
        }
    }
    
    private func resetToDefaults() {
        // Essential Settings
        streamingEnabled = true
        streamingMaxFileSize = 500.0
        streamingShowLiveText = true
        streamingPreprocessAudio = true
        streamingProgressUpdateInterval = 0.1
        
        // Advanced Settings
        streamingUploadTimeout = 300.0
        streamingTranscriptionTimeout = 600.0
    }
}

// MARK: - macOS-specific Components

struct MacOSSettingsSection<Content: View>: View {
    let title: String
    let description: String
    let content: Content
    
    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        )
    }
}

struct MacOSSliderSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let description: String
    let formatter: ((Double) -> String)?
    
    init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        description: String,
        formatter: ((Double) -> String)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.description = description
        self.formatter = formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formattedValue)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: step)
                .accentColor(.accentColor)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var formattedValue: String {
        if let formatter = formatter {
            return "\(formatter(value)) \(unit)"
        } else {
            return "\(Int(value)) \(unit)"
        }
    }
}

struct MacOSToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.subheadline)
            
            Spacer()
            
            Button(action: {
                configuration.isOn.toggle()
            }) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isOn ? Color.accentColor : Color(NSColor.separatorColor))
                    .frame(width: 44, height: 24)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .offset(x: configuration.isOn ? 10 : -10)
                            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

struct MacOSDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.red.opacity(0.8) : Color.red)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


#Preview {
    StreamingSettingsView()
        .frame(width: 700, height: 600)
}
