import SwiftData
import SwiftUI

struct TranscriptionCardHeader: View {
    let transcription: Transcription

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transcription.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(transcription.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Duration
                Text("Duration: \(formatDuration(transcription.duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Version and enhancement indicators
            HStack(spacing: 8) {
                // Version indicator - Always show
                VersionIndicatorBadge(
                    count: transcription.transcriptionVersions.count,
                    icon: "doc.text",
                    color: .blue
                )

                // Enhancement indicator - Always show
                VersionIndicatorBadge(
                    count: transcription.enhancementVersions.count,
                    icon: "sparkles",
                    color: .purple
                )
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VersionIndicatorBadge: View {
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    let sampleTranscription = Transcription(text: "Sample", duration: 125.0)
    TranscriptionCardHeader(transcription: sampleTranscription)
        .padding()
}
