import SwiftUI
import AVKit

struct VideoEditorView: View {
    @State private var videoEditor = VideoEditor()
    @State private var currentClip: VideoClip
    @State private var adjustments: VideoAdjustments
    @State private var isProcessing = false
    @State private var showingTrimView = false
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 0  // Will be set to duration when video loads
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var thumbnails: [UIImage] = []
    @State private var isPlaying = false
    @State private var isExpanded = false
    @State private var undoManager = UndoManager()
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @Environment(\.dismiss) private var dismiss
    
    // Player state management
    @State private var playerState = AVPlayer.TimeControlStatus.paused
    
    init(clip: VideoClip) {
        print("🎬 VideoEditorView init")
        print("📼 Initializing with clip:")
        print("   - ID: \(clip.id)")
        print("   - URL: \(clip.url)")
        _currentClip = State(initialValue: clip)
        _adjustments = State(initialValue: clip.adjustments)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // Undo/Redo buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            if undoManager.canUndo {
                                undoManager.undo()
                            }
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(undoManager.canUndo ? .white : .gray)
                        }
                        .disabled(!undoManager.canUndo)
                        
                        Button(action: {
                            if undoManager.canRedo {
                                undoManager.redo()
                            }
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .foregroundColor(undoManager.canRedo ? .white : .gray)
                        }
                        .disabled(!undoManager.canRedo)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Save action will be implemented later
                    }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 1)))
                            .frame(width: 60, height: 44)
                    }
                }
                .padding(.horizontal)
                .background(Color.black)
                
                // Video preview
                Group {
                    if let player = videoEditor.player {
                        ZStack {
                            CustomVideoPlayer(player: player, 
                                            isPlaying: $isPlaying, 
                                            currentTime: $currentTime,
                                            duration: duration)
                                .aspectRatio(isExpanded ? nil : 9/16, contentMode: .fit)
                                .overlay(
                                    isProcessing ? 
                                        ProgressView("Processing...")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.7))
                                        : nil
                                )
                            
                            // Expand/Collapse button
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            isExpanded.toggle()
                                        }
                                    }) {
                                        Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    .padding(8)
                                }
                                Spacer()
                            }
                        }
                        .background(Color.black)
                    } else {
                        ProgressView("Loading video...")
                            .foregroundColor(.white)
                            .aspectRatio(9/16, contentMode: .fit)
                            .background(Color.black)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Timeline with playhead
                VStack(spacing: 4) {
                    // Thumbnail strip container
                    GeometryReader { geometry in
                        if let player = videoEditor.player {
                            VideoTimelineView(
                                geometry: geometry,
                                thumbnails: thumbnails,
                                currentTime: $currentTime,
                                duration: duration,
                                trimStartTime: $trimStartTime,
                                trimEndTime: $trimEndTime,
                                isDraggingStart: $isDraggingStart,
                                isDraggingEnd: $isDraggingEnd,
                                player: player
                            )
                        }
                    }
                    .frame(height: 60)
                    .background(Color.black.opacity(0.3))
                    
                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption2)
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Bottom toolbar
                HStack(spacing: 24) {
                    ForEach(ToolbarItem.allCases, id: \.self) { item in
                        VStack(spacing: 4) {
                            Image(systemName: item.iconName)
                                .font(.system(size: 24))
                            Text(item.title)
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal)
                .background(Color.black)
            }
        }
        .task {
            print("🎥 VideoEditorView task started")
            await loadVideoDetails()
        }
        .onChange(of: playerState) { newState in
            isPlaying = newState == .playing
        }
        .onDisappear {
            print("👋 VideoEditorView disappeared")
            videoEditor.player?.pause()
            videoEditor.player = nil
        }
        .preferredColorScheme(.dark)
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
            // Set the end trim handle to the full duration
            self.trimEndTime = duration.seconds
            // Ensure playhead starts at the beginning
            self.currentTime = 0
            print("⏱️ Video duration loaded: \(duration.seconds) seconds")
        } else {
            print("❌ Failed to load video duration")
        }
        
        // Start in a paused state at the beginning
        print("⏸️ Setting initial state to paused at beginning")
        await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.pause()
        isPlaying = false
        
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
        let remainingSeconds = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }
}

// Toolbar items enum
enum ToolbarItem: CaseIterable {
    case edit, audio, text, overlay, effects, captions, template
    
    var title: String {
        switch self {
        case .edit: return "Edit"
        case .audio: return "Audio"
        case .text: return "Text"
        case .overlay: return "Overlay"
        case .effects: return "Effects"
        case .captions: return "Captions"
        case .template: return "Template"
        }
    }
    
    var iconName: String {
        switch self {
        case .edit: return "slider.horizontal.3"
        case .audio: return "music.note"
        case .text: return "textformat"
        case .overlay: return "square.on.square"
        case .effects: return "sparkles"
        case .captions: return "captions.bubble"
        case .template: return "square.stack"
        }
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TrimHandle: View {
    let isLeft: Bool
    @Binding var isDragging: Bool
    @Binding var trimTime: Double
    @Binding var currentTime: Double
    let duration: Double
    let geometry: GeometryProxy
    let onDragEnded: () -> Void
    let player: AVPlayer
    let otherHandleTime: Double
    @State private var lastDragValue: CGFloat = 0
    
    private let minDuration: Double = 1.0 
    private let handleHeight: CGFloat = 60
    private let handleWidth: CGFloat = 44
    
    var body: some View {
        ZStack(alignment: .top) {
            // Time indicator
            if isDragging {
                Text(formatTime(trimTime))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.8))
                            .shadow(color: .black.opacity(0.2), radius: 3)
                    )
                    .offset(y: -30)
            }
            
            // Handle
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 1)))
                    .frame(width: 4, height: handleHeight)
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                            
                            Circle()
                                .fill(Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 1)))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        .offset(y: handleHeight/2 + 14)
                    )
            }
            .frame(width: handleWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            HapticFeedback.medium()
                        }
                        
                        let delta = value.translation.width - lastDragValue
                        lastDragValue = value.translation.width
                        
                        let positionDelta = delta / geometry.size.width
                        let timeDelta = positionDelta * duration
                        
                        var newTime = trimTime + timeDelta
                        
                        if isLeft {
                            let maxStartTime = otherHandleTime - minDuration
                            newTime = min(max(0, newTime), maxStartTime)
                            
                            if currentTime < newTime {
                                currentTime = newTime
                            }
                        } else {
                            let minEndTime = otherHandleTime + minDuration
                            newTime = max(min(duration, newTime), minEndTime)
                            
                            if currentTime > newTime {
                                currentTime = newTime
                            }
                        }
                        
                        if newTime != trimTime {
                            trimTime = newTime
                            Task {
                                await updatePreview(at: newTime)
                            }
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastDragValue = 0
                        onDragEnded()
                        
                        Task {
                            await updatePreview(at: currentTime)
                        }
                        HapticFeedback.medium()
                    }
            )
        }
        .frame(width: handleWidth)
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: isDragging)
    }
    
    private func updatePreview(at time: Double) async {
        await player.seek(to: CMTime(seconds: time, preferredTimescale: 600),
                         toleranceBefore: .zero,
                         toleranceAfter: .zero)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }
}

// Timeline with playhead and trim handles
struct VideoTimelineView: View {
    let geometry: GeometryProxy
    let thumbnails: [UIImage]
    @Binding var currentTime: Double
    let duration: Double
    @Binding var trimStartTime: Double
    @Binding var trimEndTime: Double
    @Binding var isDraggingStart: Bool
    @Binding var isDraggingEnd: Bool
    let player: AVPlayer
    
    private let thumbnailWidth: CGFloat = 40
    private let thumbnailHeight: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.3)
            
            // Thumbnails with clipping
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(thumbnails.enumerated()), id: \.1) { index, thumbnail in
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: thumbnailWidth, height: thumbnailHeight)
                            .clipped()
                            .contentShape(Rectangle())
                            .overlay(
                                // Add subtle gradient overlay for better visibility
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.3),
                                        Color.clear,
                                        Color.black.opacity(0.3)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .onTapGesture {
                                let targetTime = duration * Double(index) / Double(thumbnails.count)
                                let clampedTime = min(max(targetTime, trimStartTime), trimEndTime)
                                Task {
                                    await player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600),
                                                    toleranceBefore: .zero,
                                                    toleranceAfter: .zero)
                                }
                                currentTime = clampedTime
                                HapticFeedback.light()
                            }
                    }
                }
            }
            
            // Selected region indicator with animated gradient
            Rectangle()
                .fill(Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 0.2)))
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 0.1)),
                            Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 0.3)),
                            Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 0.1))
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: calculateWidth(for: trimEndTime - trimStartTime))
                .position(x: calculatePosition(for: trimStartTime) + calculateWidth(for: trimEndTime - trimStartTime) / 2,
                         y: geometry.size.height / 2)
                .allowsHitTesting(false)
            
            // Trim overlays with gradient edges
            Group {
                // Left overlay
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.6),
                                Color.black.opacity(0.4)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: calculatePosition(for: trimStartTime))
                    .position(x: calculatePosition(for: trimStartTime) / 2,
                             y: geometry.size.height / 2)
                
                // Right overlay
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.4),
                                Color.black.opacity(0.6)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width - calculatePosition(for: trimEndTime))
                    .position(x: (geometry.size.width + calculatePosition(for: trimEndTime)) / 2,
                             y: geometry.size.height / 2)
            }
            .allowsHitTesting(false)
            
            // Trim handles
            Group {
                // Left trim handle
                TrimHandle(
                    isLeft: true,
                    isDragging: $isDraggingStart,
                    trimTime: $trimStartTime,
                    currentTime: $currentTime,
                    duration: duration,
                    geometry: geometry,
                    onDragEnded: {
                        if trimStartTime >= trimEndTime - 1.0 {
                            trimStartTime = max(0, trimEndTime - 1.0)
                        }
                    },
                    player: player,
                    otherHandleTime: trimEndTime
                )
                .position(x: calculatePosition(for: trimStartTime), y: geometry.size.height / 2)
                
                // Right trim handle
                TrimHandle(
                    isLeft: false,
                    isDragging: $isDraggingEnd,
                    trimTime: $trimEndTime,
                    currentTime: $currentTime,
                    duration: duration,
                    geometry: geometry,
                    onDragEnded: {
                        if trimEndTime <= trimStartTime + 1.0 {
                            trimEndTime = min(duration, trimStartTime + 1.0)
                        }
                    },
                    player: player,
                    otherHandleTime: trimStartTime
                )
                .position(x: calculatePosition(for: trimEndTime), y: geometry.size.height / 2)
            }
            
            // Playhead
            Playhead(
                geometry: geometry,
                currentTime: $currentTime,
                duration: duration,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime,
                player: player,
                isDraggingTrim: isDraggingStart || isDraggingEnd
            )
        }
        .frame(height: thumbnailHeight)
        .clipped()
        .overlay(
            // Add subtle shadow at top and bottom
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.3), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 4)
                
                Spacer()
                
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 4)
            }
        )
    }
    
    private func calculatePosition(for time: Double) -> CGFloat {
        geometry.size.width * CGFloat(time / duration)
    }
    
    private func calculateWidth(for duration: Double) -> CGFloat {
        geometry.size.width * CGFloat(duration / self.duration)
    }
}

// Custom Video Player View
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    let duration: Double
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        controller.view.addGestureRecognizer(tapGesture)
        
        // Add observer for video completion
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            player.seek(to: .zero)
            currentTime = 0
        }
        
        // Add time observer
        let interval = CMTime(seconds: 0.03, preferredTimescale: 600) // 30fps update rate
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CustomVideoPlayer
        
        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            if parent.isPlaying {
                parent.player.pause()
            } else {
                // If at the end, seek to start before playing
                if let duration = parent.player.currentItem?.duration,
                   let currentTime = parent.player.currentItem?.currentTime(),
                   currentTime >= duration {
                    Task {
                        await parent.player.seek(to: .zero)
                    }
                }
                parent.player.play()
            }
            parent.isPlaying.toggle()
        }
    }
}

// Add this new struct for the Playhead
struct Playhead: View {
    let geometry: GeometryProxy
    @Binding var currentTime: Double
    let duration: Double
    let trimStartTime: Double
    let trimEndTime: Double
    let player: AVPlayer
    let isDraggingTrim: Bool
    @State private var isDragging = false
    @GestureState private var dragLocation: CGFloat = 0
    
    private let handleWidth: CGFloat = 3
    
    var body: some View {
        Rectangle()
            .fill(Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 1)))
            .frame(width: handleWidth)
            .overlay(
                Circle()
                    .fill(Color(#colorLiteral(red: 0.529, green: 0.808, blue: 0.922, alpha: 1)))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(y: -10),
                alignment: .top
            )
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle().inset(by: -20))
            .position(x: calculatePosition(), y: geometry.size.height/2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragLocation) { value, state, _ in
                        if !isDraggingTrim {
                            state = value.location.x
                            updatePosition(location: value.location.x)
                        }
                    }
                    .onChanged { _ in isDragging = true }
                    .onEnded { _ in isDragging = false }
            )
            .animation(isDragging ? nil : .interactiveSpring(), value: currentTime)
    }
    
    private func calculatePosition() -> CGFloat {
        let position = (currentTime - trimStartTime) / (trimEndTime - trimStartTime)
        return geometry.size.width * min(max(0, position), 1)
    }
    
    private func updatePosition(location: CGFloat) {
        let position = location / geometry.size.width
        let clampedPosition = min(max(0, position), 1)
        let newTime = trimStartTime + (clampedPosition * (trimEndTime - trimStartTime))
        
        if newTime != currentTime {
            currentTime = newTime
            Task {
                await player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600),
                                toleranceBefore: .zero,
                                toleranceAfter: .zero)
            }
        }
    }
}

// Haptic Feedback helper
enum HapticFeedback {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
} 