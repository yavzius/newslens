import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseStorage

struct FeedItemView: View {
    @StateObject private var viewModel: FeedItemViewModel
    let post: Post
    let onLike: () -> Void
    let onUnlike: () -> Void
    let onCommentTap: () -> Void
    
    init(post: Post, onLike: @escaping () -> Void = {}, onUnlike: @escaping () -> Void = {}, onCommentTap: @escaping () -> Void = {}) {
        self.post = post
        self.onLike = onLike
        self.onUnlike = onUnlike
        self.onCommentTap = onCommentTap
        _viewModel = StateObject(wrappedValue: FeedItemViewModel(postID: UUID(uuidString: post.id ?? "") ?? UUID()))
    }
    
    var body: some View {
        VideoPlayerView(player: viewModel.player)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if let headline = post.headline {
                        Text(headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                    }
                    
                    if let subtitle = post.subtitle {
                        Text(subtitle)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 20) {
                        Button {
                            if viewModel.isLiked {
                                Task { await viewModel.unlikePost(post) }
                                onUnlike()
                            } else {
                                Task { await viewModel.likePost(post) }
                                onLike()
                            }
                        } label: {
                            Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                .foregroundColor(viewModel.isLiked ? .red : .white)
                        }
                        
                        Button {
                            onCommentTap()
                        } label: {
                            Image(systemName: "bubble.right")
                                .foregroundColor(.white)
                        }
                    }
                    .font(.title)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .onAppear {
                viewModel.updatePost(post)
                Task {
                    await viewModel.setupVideoPlayer()
                }
            }
            .onDisappear {
                viewModel.cleanup()
            }
    }
}

// MARK: - View Model
@MainActor
class FeedItemViewModel: ObservableObject {
    @Published var isVideoReady = false
    @Published var isPlaying = false
    @Published var isLoading = true
    @Published var isLiked = false
    private(set) var player: AVPlayer?
    private(set) var postID: UUID
    private var post: Post?
    private var timeObserver: Any?
    private var cleanupTask: Task<Void, Never>?
    private var isActive = false
    
    init(postID: UUID) {
        self.postID = postID
        setupNotificationObservers()
    }
    
    deinit {
        // Remove notification observers synchronously since it's thread-safe
        NotificationCenter.default.removeObserver(self)
        
        // Create cleanup task for main actor operations
        cleanupTask = Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayNotification),
            name: NSNotification.Name("PlayVideo"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePauseNotification),
            name: NSNotification.Name("PauseVideo"),
            object: nil
        )
    }
    
    @objc private func handlePlayNotification(_ notification: Notification) {
        guard let videoID = notification.userInfo?["videoID"] as? UUID else { return }
        
        if videoID == postID {
            isActive = true
            if player == nil {
                Task {
                    await setupVideoPlayer()
                }
            } else {
                player?.play()
                isPlaying = true
            }
        } else {
            isActive = false
            cleanup()
        }
    }
    
    @objc private func handlePauseNotification(_ notification: Notification) {
        guard let videoID = notification.userInfo?["videoID"] as? UUID,
              videoID == postID else { return }
        player?.pause()
        isPlaying = false
    }
    
    func setupVideoPlayer() async {
        // Only setup if this is the active video
        guard isActive, let post = post else { return }
        
        // If we already have a player, just play it
        if player != nil {
            player?.play()
            isPlaying = true
            return
        }
        
        do {
            let url = try await Storage.storage().reference(forURL: post.videoURL).downloadURL()
            let playerItem = AVPlayerItem(url: url)
            
            // Check if we're still active before creating the player
            guard isActive else { return }
            
            player = AVPlayer(playerItem: playerItem)
            setupPlayerObservers()
            
            // Start playing immediately
            player?.play()
            isPlaying = true
            isVideoReady = true
            isLoading = false
            
            // Add observer for when the video finishes loading
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemNewErrorLogEntry,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, self.isActive else { return }
                self.player?.play()
            }
            
            // Add observer for playback status
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, self.isActive else { return }
                self.player?.seek(to: .zero)
                self.player?.play()
            }
            
        } catch {
            print("Error setting up video player: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.handleTimeUpdate()
        }
    }
    
    private func handleTimeUpdate() {
        guard let player = player,
              let duration = player.currentItem?.duration.seconds,
              !duration.isNaN,
              duration > 0 else { return }
        
        let currentTime = player.currentTime().seconds
        if currentTime >= duration {
            player.seek(to: .zero)
            player.play()
        }
    }
    
    func cleanup() {
        isActive = false
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        // Remove all notification observers
        if let playerItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemNewErrorLogEntry, object: playerItem)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }
        
        timeObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        isVideoReady = false
        isLoading = true
    }
    
    func updatePost(_ newPost: Post) {
        self.post = newPost
        Task {
            await updateLikeState()
        }
    }
    
    private func updateLikeState() async {
        guard let post = post else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            isLiked = try await FirebaseManager.shared.checkIfPostLiked(userId: userId, postId: post.id ?? "")
        } catch {
            print("Error updating like state: \(error.localizedDescription)")
        }
    }
    
    func likePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        do {
            try await FirebaseManager.shared.likePostByUser(userId: userId, postId: postId)
            isLiked = true
        } catch {
            print("Error liking post: \(error.localizedDescription)")
        }
    }
    
    func unlikePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        do {
            try await FirebaseManager.shared.unlikePostByUser(userId: userId, postId: postId)
            isLiked = false
        } catch {
            print("Error unliking post: \(error.localizedDescription)")
        }
    }
} 
