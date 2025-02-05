import SwiftUI
import AVKit

struct FeedCell: View {
    let article: Article
    @StateObject private var viewModel = FeedCellViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if let videoURL = article.videoURL {
                    ZStack {
                        if viewModel.isVideoReady, let player = viewModel.player {
                            CustomVideoPlayerView(player: player)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .onTapGesture {
                                    if player.timeControlStatus == .playing {
                                        player.pause()
                                    } else {
                                        player.play()
                                    }
                                }
                                // Double tap to restart video
                                .onTapGesture(count: 2) {
                                    Task {
                                        await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                                        player.play()
                                    }
                                }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)
                        }
                    }
                }
                
                // Overlay content
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.headline)
                        .font(.title3)
                        .foregroundColor(.white)
                        .bold()
                        .lineLimit(3)
                    
                    if let subheadline = article.subheadline {
                        Text(subheadline)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
                .frame(maxWidth: geometry.size.width)
            }
        }
        .onAppear {
            print("📱 FeedCell appeared")
            if let videoURL = article.videoURL {
                viewModel.setupVideo(url: videoURL)
            }
        }
        .onDisappear {
            print("👋 FeedCell disappeared")
            // When the cell disappears, fully clean up the video player (i.e. close it)
            viewModel.cleanup()
        }
        // Track when this cell becomes visible in the scroll view
        .visibilityAware { isVisible in
            if isVisible {
                print("▶️ Video became visible - resetting and resuming playback")
                // If the player has been cleaned up, reinitialize it (if the video URL is available)
                if viewModel.player == nil, let videoURL = article.videoURL {
                    viewModel.setupVideo(url: videoURL)
                }
                
                // Always restart from the beginning
                if let player = viewModel.player, viewModel.isVideoReady {
                    Task {
                        print("▶️ Before seek: \(player.currentTime().seconds)")
                        await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                        print("🔄 After seek: \(player.currentTime().seconds)")
                        player.play()
                    }
                }
            } else {
                print("⏹️ Video no longer visible - cleaning up player")
                // Instead of simply pausing, fully clean up the player when the cell is not visible.
                viewModel.cleanup()
            }
        }
    }
}

// MARK: - Custom Video Player View
struct CustomVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("📱 Creating AVPlayerViewController")
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        // Remove gesture recognizers that might interfere with our custom tap
        controller.view.gestureRecognizers?.removeAll()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - View Model
class FeedCellViewModel: ObservableObject {
    @Published var isVideoReady = false
    private(set) var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    
    func setupVideo(url: URL) {
        print("🎥 Setting up video with URL: \(url)")
        // Only setup if we don't already have a player
        guard player == nil else { return }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Video file does not exist at path: \(url.path)")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Configure player for better performance
        player?.automaticallyWaitsToMinimizeStalling = false
        
        // Start paused
        player?.pause()
        
        // Loop video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                             object: playerItem,
                                             queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                if self?.isVideoReady == true {
                    self?.player?.play()
                }
            }
        }
        
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    print("✅ Video is ready to play")
                    self?.isVideoReady = true
                }
            }
        }
    }
    
    func cleanup() {
        print("🧹 Cleaning up video player")
        statusObserver?.invalidate()
        statusObserver = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        isVideoReady = false
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Visibility Tracking
extension View {
    func visibilityAware(perform action: @escaping (Bool) -> Void) -> some View {
        self.overlay(
            VisibilityTracker(action: action)
        )
    }
}

struct VisibilityTracker: UIViewRepresentable {
    let action: (Bool) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            let isVisible = uiView.isVisible()
            action(isVisible)
        }
    }
}

extension UIView {
    func isVisible() -> Bool {
        guard let window = self.window else { return false }
        let viewFrame = self.convert(self.bounds, to: window)
        let isIntersecting = viewFrame.intersects(window.bounds)
        let isVisible = self.alpha > 0 && !self.isHidden && isIntersecting
        return isVisible
    }
}

struct FeedCell_Previews: PreviewProvider {
    static var previews: some View {
        FeedCell(article: mockArticles.first!)
            .previewInterfaceOrientation(.portrait)
    }
}
