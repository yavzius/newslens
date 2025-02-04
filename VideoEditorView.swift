import SwiftUI
import AVKit

struct VideoEditorView: View {
    @State private var videoEditor = VideoEditor()
    @State private var currentClip: VideoClip
    @State private var adjustments: VideoAdjustments
    @State private var isProcessing = false
    @State private var showingTrimView = false
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 1
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var thumbnails: [UIImage] = []
    
    init(clip: VideoClip) {
        print("🎬 VideoEditorView init")
        print("📼 Initializing with clip:")
        print("   - ID: \(clip.id)")
        print("   - URL: \(clip.url)")
        _currentClip = State(initialValue: clip)
        _adjustments = State(initialValue: clip.adjustments)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Video preview
            Group {
                if let player = videoEditor.player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .overlay(
                            isProcessing ? ProgressView("Processing...") : nil
                        )
                        .onAppear {
                            print("✅ Player available, showing VideoPlayer")
                        }
                } else {
                    ProgressView("Loading video...")
                        .aspectRatio(9/16, contentMode: .fit)
                        .onAppear {
                            print("⏳ Player not ready, showing loading view")
                        }
                }
            }
            
            // Timeline view with thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(thumbnails, id: \.self) { thumbnail in
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 40)
                            .clipped()
                    }
                }
                .frame(height: 40)
            }
            .padding(.horizontal)
            
            // Trim controls
            if showingTrimView {
                HStack {
                    Text(formatTime(trimStartTime * duration))
                    Slider(value: $trimStartTime, in: 0...trimEndTime)
                        .tint(.blue)
                    Slider(value: $trimEndTime, in: trimStartTime...1)
                        .tint(.blue)
                    Text(formatTime(trimEndTime * duration))
                }
                .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        showingTrimView = false
                    }
                    
                    Button("Apply Trim") {
                        Task {
                            await trimVideo()
                        }
                    }
                }
            }
            
            // Adjustment controls
            VStack(spacing: 12) {
                AdjustmentSlider(
                    value: $adjustments.brightness,
                    range: -1...1,
                    label: "Brightness"
                )
                
                AdjustmentSlider(
                    value: $adjustments.contrast,
                    range: 0...2,
                    label: "Contrast"
                )
                
                AdjustmentSlider(
                    value: $adjustments.saturation,
                    range: 0...2,
                    label: "Saturation"
                )
            }
            .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 20) {
                Button(action: {
                    showingTrimView.toggle()
                }) {
                    VStack {
                        Image(systemName: "scissors")
                        Text("Trim")
                    }
                }
                
                Button(action: {
                    Task {
                        await splitVideoAtCurrentTime()
                    }
                }) {
                    VStack {
                        Image(systemName: "scissors.badge.ellipsis")
                        Text("Split")
                    }
                }
                
                Button(action: {
                    Task {
                        await applyAdjustments()
                    }
                }) {
                    Text("Apply Adjustments")
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .task {
            print("🎥 VideoEditorView task started")
            print("📱 Current state:")
            print("   - Clip URL: \(currentClip.url)")
            print("   - Player exists: \(videoEditor.player != nil)")
            await loadVideoDetails()
        }
        .onAppear {
            print("👋 VideoEditorView appeared")
        }
        .onDisappear {
            print("👋 VideoEditorView disappeared")
            // Clean up
            videoEditor.player?.pause()
            videoEditor.player = nil
        }
    }
    
    private func loadVideoDetails() async {
        print("🎯 Starting loadVideoDetails")
        print("📍 Loading video from URL: \(currentClip.url)")
        
        // Create an AVPlayer for the clip
        let player = AVPlayer(url: currentClip.url)
        print("🎬 Created AVPlayer")
        videoEditor.player = player
        print("💾 Assigned player to videoEditor")
        
        // Get video duration
        let asset = AVURLAsset(url: currentClip.url)
        if let duration = try? await asset.load(.duration) {
            self.duration = duration.seconds
            print("⏱️ Video duration loaded: \(duration.seconds) seconds")
        } else {
            print("❌ Failed to load video duration")
        }
        
        // Start playing the video
        print("▶️ Starting video playback")
        player.play()
        
        // Generate thumbnails
        print("🖼️ Starting thumbnail generation")
        await generateThumbnails()
        print("✅ Finished loadVideoDetails")
    }
    
    private func generateThumbnails() async {
        let numberOfThumbnails = 10
        let interval = duration / Double(numberOfThumbnails)
        
        for i in 0..<numberOfThumbnails {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            if let thumbnail = try? await videoEditor.generateThumbnail(for: currentClip, at: time) {
                thumbnails.append(thumbnail)
            }
        }
    }
    
    private func applyAdjustments() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let processedURL = try await videoEditor.applyAdjustments(to: currentClip, adjustments: adjustments)
            currentClip = VideoClip(
                id: currentClip.id,
                url: processedURL,
                startTime: currentClip.startTime,
                endTime: currentClip.endTime,
                adjustments: adjustments,
                order: currentClip.order
            )
            videoEditor.setupPreview(for: currentClip)
        } catch {
            print("Failed to apply adjustments: \(error.localizedDescription)")
        }
    }
    
    private func trimVideo() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let startTime = CMTime(seconds: trimStartTime * duration, preferredTimescale: 600)
            let endTime = CMTime(seconds: trimEndTime * duration, preferredTimescale: 600)
            
            let trimmedClip = try await videoEditor.trimClip(currentClip, startTime: startTime, endTime: endTime)
            currentClip = trimmedClip
            videoEditor.setupPreview(for: currentClip)
            showingTrimView = false
            
            // Regenerate thumbnails
            thumbnails.removeAll()
            await generateThumbnails()
        } catch {
            print("Failed to trim video: \(error.localizedDescription)")
        }
    }
    
    private func splitVideoAtCurrentTime() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let currentTime = CMTime(seconds: self.currentTime, preferredTimescale: 600)
            let (firstClip, secondClip) = try await videoEditor.splitClip(currentClip, atTime: currentTime)
            
            // Handle the split clips (you might want to pass these back to the parent view)
            print("Video split into clips: \(firstClip.id) and \(secondClip.id)")
        } catch {
            print("Failed to split video: \(error.localizedDescription)")
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AdjustmentSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Slider(value: $value, in: range)
                    .tint(.blue)
                
                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .frame(width: 40)
            }
        }
    }
} 