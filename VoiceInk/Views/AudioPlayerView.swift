import SwiftUI
import AVFoundation

class WaveformGenerator {
    static func generateWaveformSamples(from url: URL, sampleCount: Int = 200) async -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        let stride = max(1, Int(frameCount) / sampleCount)
        let bufferSize = min(UInt32(4096), frameCount)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else { return [] }
        
        do {
            var maxValues = [Float](repeating: 0.0, count: sampleCount)
            var sampleIndex = 0
            var framePosition: AVAudioFramePosition = 0
            
            while sampleIndex < sampleCount && framePosition < AVAudioFramePosition(frameCount) {
                audioFile.framePosition = framePosition
                try audioFile.read(into: buffer)
                
                if let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                    maxValues[sampleIndex] = abs(channelData[0])
                    sampleIndex += 1
                }
                
                framePosition += AVAudioFramePosition(stride)
            }
            
            if let maxSample = maxValues.max(), maxSample > 0 {
                return maxValues.map { $0 / maxSample }
            }
            return maxValues
        } catch {
            print("Error reading audio file: \(error)")
            return []
        }
    }
}

class AudioPlayerManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var waveformSamples: [Float] = []
    @Published var isLoadingWaveform = false
    
    func loadAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            isLoadingWaveform = true
            
            Task {
                let samples = await WaveformGenerator.generateWaveformSamples(from: url)
                await MainActor.run {
                    self.waveformSamples = samples
                    self.isLoadingWaveform = false
                }
            }
        } catch {
            print("Error loading audio: \(error.localizedDescription)")
        }
    }
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = self.audioPlayer?.currentTime ?? 0
            if self.currentTime >= self.duration {
                self.pause()
                self.seek(to: 0)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopTimer()
    }
}

struct WaveformView: View {
    let samples: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isLoading: Bool
    var onSeek: (Double) -> Void
    @State private var isHovering = false
    @State private var hoverLocation: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isLoading {
                    VStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .rotationEffect(.degrees(360))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                        Text("Generating waveform...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 1) {
                        ForEach(0..<samples.count, id: \.self) { index in
                            WaveformBar(
                                sample: samples[index],
                                isPlayed: CGFloat(index) / CGFloat(samples.count) <= CGFloat(currentTime / duration),
                                totalBars: samples.count,
                                geometryWidth: geometry.size.width,
                                isHovering: isHovering,
                                hoverProgress: hoverLocation / geometry.size.width
                            )
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 2)
                    
                    if isHovering {
                        Text(formatTime(duration * Double(hoverLocation / geometry.size.width)))
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor))
                            .offset(x: max(0, min(hoverLocation - 30, geometry.size.width - 60)))
                            .offset(y: -30)
                        
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .offset(x: hoverLocation)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isLoading {
                            hoverLocation = value.location.x
                            onSeek(Double(value.location.x / geometry.size.width) * duration)
                        }
                    }
            )
            .onHover { hovering in
                if !isLoading {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            }
            .onContinuousHover { phase in
                if !isLoading {
                    if case .active(let location) = phase {
                        hoverLocation = location.x
                    }
                }
            }
        }
        .frame(height: 56)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WaveformBar: View {
    let sample: Float
    let isPlayed: Bool
    let totalBars: Int
    let geometryWidth: CGFloat
    let isHovering: Bool
    let hoverProgress: CGFloat
    
    private var isNearHover: Bool {
        let barPosition = geometryWidth / CGFloat(totalBars)
        let hoverPosition = hoverProgress * geometryWidth
        return abs(barPosition - hoverPosition) < 20
    }
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        isPlayed ? Color.accentColor : Color.accentColor.opacity(0.3),
                        isPlayed ? Color.accentColor.opacity(0.8) : Color.accentColor.opacity(0.2)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(
                width: max((geometryWidth / CGFloat(totalBars)) - 1, 1),
                height: max(CGFloat(sample) * 40, 3)
            )
            .scaleEffect(y: isHovering && isNearHover ? 1.2 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isHovering && isNearHover)
    }
}

struct AudioPlayerView: View {
    let url: URL
    @StateObject private var playerManager = AudioPlayerManager()
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.accentColor)
                    Text("Recording")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTime(playerManager.duration))
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                WaveformView(
                    samples: playerManager.waveformSamples,
                    currentTime: playerManager.currentTime,
                    duration: playerManager.duration,
                    isLoading: playerManager.isLoadingWaveform,
                    onSeek: { playerManager.seek(to: $0) }
                )
                
                HStack(spacing: 20) {
                    Button(action: {
                        if playerManager.isPlaying {
                            playerManager.pause()
                        } else {
                            playerManager.play()
                        }
                    }) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .contentTransition(.symbolEffect(.replace.downUp))
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isHovering ? 1.05 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isHovering = hovering
                        }
                    }
                    
                    Spacer()
                    
                    Text(formatTime(playerManager.currentTime))
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .onAppear {
            playerManager.loadAudio(from: url)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
