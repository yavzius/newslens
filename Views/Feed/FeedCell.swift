import SwiftUI
import AVKit
import FirebaseStorage
import Foundation
import FirebaseFirestore
import FirebaseAuth


// MARK: - Feed State Manager
class FeedStateManager: ObservableObject {
    static let instance = FeedStateManager()
    @Published var activeVideoID: UUID?
    
    private init() {}
    
    func setActiveVideo(_ id: UUID) {
        if activeVideoID != id {
            activeVideoID = id
        }
    }
}

// MARK: - Feed Cell View Model
class FeedCellViewModel: ObservableObject {
    @Published var isVideoReady = false
    @Published var isPlaying = false
    @Published var isLoading = true
    private(set) var player: AVPlayer?
    private var observers = Set<NSKeyValueObservation>()
    private var playerItem: AVPlayerItem?
    private let articleID: UUID
    
    init(articleID: UUID) {
        self.articleID = articleID
    }
    
    @MainActor
    func setupVideo(storageURL: String) async {
        // 1) Check if file is cached
        if let localURL = await Task.detached(operation: { await VideoCacheManager.shared.fileExists(for: self.articleID) }).value {
            // Already cached; load from local file
            print("✔️ Using cached video at: \(localURL)")
            let asset = AVURLAsset(url: localURL)
            Task {
                setupPlayerWithAsset(asset)
            }
            return
        }
        
        // 2) Otherwise, download from Firebase Storage
        let storage = Storage.storage()
        let videoRef = storage.reference(forURL: storageURL)
        
        isLoading = true
        Task {
            do {
                let data = try await videoRef.data(maxSize: 50 * 1024 * 1024) // 50MB limit, adjust if needed
                let cachedURL = try await VideoCacheManager.shared.cacheVideo(data: data, for: self.articleID)
                print("✅ Downloaded & cached video at: \(cachedURL)")
                
                let asset = AVURLAsset(url: cachedURL)
                try await asset.loadValues(forKeys: ["playable", "duration"])
                await setupPlayerWithAsset(asset)
            } catch {
                print("❌ Error: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    private func setupPlayerWithAsset(_ asset: AVURLAsset) {
        // Create player item
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // Configure player
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Observe status
        let statusObserver = playerItem?.observe(\.status) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                self.isVideoReady = true
                self.isLoading = false
                self.play()
            }
        }
        
        if let statusObserver = statusObserver {
            observers.insert(statusObserver)
        }
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main) { [weak self] _ in
                self?.restartVideo()
            }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func restartVideo() {
        Task {
            await player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            play()
        }
    }
    
    func cleanup() {
        pause()
        observers.forEach { $0.invalidate() }
        observers.removeAll()
        playerItem = nil
        player = nil
        isVideoReady = false
        isLoading = true
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Feed Cell View
struct FeedCell: View {
    let post: Post
    @StateObject private var viewModel: FeedCellViewModel
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var feedState = FeedStateManager.instance
    @EnvironmentObject private var feedViewModel: FeedViewModel
    
    
    init(post: Post) {
        self.post = post
        _viewModel = StateObject(wrappedValue: FeedCellViewModel(articleID: UUID(uuidString: post.id ?? "") ?? UUID()))
    }

    @State private var likeCount: Int = 0
    @State private var isLiked = false
    @State private var countListener: ListenerRegistration?
    @State private var showComments = false


    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if viewModel.isVideoReady {
                    CustomVideoPlayerView(viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    loadingView
                }
                
                textOverlay
                    .padding(.bottom, 20)
                    .padding(.horizontal)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .preference(
                key: VisibilityPreferenceKey.self,
                value: [VisibilityItem(id: UUID(uuidString: post.id ?? "") ?? UUID(), frame: geometry.frame(in: .global))]
            )
            .onAppear {
                setupVideoIfNeeded()
            }
            .onDisappear {
                viewModel.cleanup()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    viewModel.play()
                } else {
                    viewModel.pause()
                }
            }
            .sheet(isPresented: $showComments) {
                CommentsView(post: post)
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
    
    // MARK: - Text Overlay Views
    private var textOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 20) {
                // Caption and user info
                VStack(alignment: .leading, spacing: 8) {
                    if let headline = post.headline {
                        Text(headline)
                            .foregroundColor(.white)
                            .font(.system(size: 15))
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 20) {
                    Button(action: {
                        Task {
                            // If the user has already liked => unlike
                            // otherwise => like
                            if isLiked {
                                await feedViewModel.unlikePost(post)
                            } else {
                                await feedViewModel.likePost(post)
                            }
                            // After toggling, re-check
                            await checkIfUserLiked()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 30))
                                .foregroundColor(isLiked ? .red : .white)
                            Text("\(likeCount)")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        showComments.toggle()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.right.fill")
                                .font(.system(size: 30))
                            Text("Comments")
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.trailing)
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .onAppear {
            Task {
                await checkIfUserLiked()
                observeLikeCount()  // optional if you want a live likeCount
            }
        }
        .onDisappear {
            // Remove any listeners if you attached them
            countListener?.remove()
            countListener = nil
        }
    }
    
    private func removeLikeCountListener() {
        countListener?.remove()
        countListener = nil
    }
    
    private var headlineText: some View {
        Text(post.headline ?? "")
            .font(.title3)
            .foregroundColor(.white)
            .bold()
            .lineLimit(3)
    }
    
    private func subheadlineText(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.white)
            .lineLimit(2)
    }
    
    // MARK: - Helper Methods
    private func setupVideoIfNeeded() {
        if viewModel.player == nil {
            Task {
                await viewModel.setupVideo(storageURL: post.videoURL)
            }
        }
    }
}

// MARK: - Visibility Tracking
struct VisibilityItem: Equatable {
    let id: UUID
    let frame: CGRect
}

struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [VisibilityItem] = []
    
    static func reduce(value: inout [VisibilityItem], nextValue: () -> [VisibilityItem]) {
        value.append(contentsOf: nextValue())
    }
}

struct VisibilityTracker: View {
    @ObservedObject private var feedState = FeedStateManager.instance
    
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onPreferenceChange(VisibilityPreferenceKey.self) { items in
                    handleVisibilityChange(items)
                }
        }
    }
    
    private func handleVisibilityChange(_ items: [VisibilityItem]) {
        guard !items.isEmpty else { return }
        
        let screenMidY = UIScreen.main.bounds.height / 2
        let threshold = UIScreen.main.bounds.height / 4
        
        // Process items to find distances
        let itemsWithDistance = items.map { item -> (VisibilityItem, CGFloat) in
            let itemMidY = item.frame.minY + (item.frame.height / 2)
            let distance = abs(itemMidY - screenMidY)
            return (item, distance)
        }
        
        // Filter items within threshold
        let visibleItems = itemsWithDistance.filter { _, distance in
            distance < threshold
        }
        
        // Find closest item
        if let closestItem = visibleItems.min(by: { $0.1 < $1.1 }) {
            feedState.setActiveVideo(closestItem.0.id)
        }
    }
}

// MARK: - Custom Video Player View
struct CustomVideoPlayerView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: FeedCellViewModel
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = viewModel.player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        controller.view.backgroundColor = .black
        controller.view.frame = UIScreen.main.bounds
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        controller.view.addGestureRecognizer(tapGesture)
        
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        controller.view.addGestureRecognizer(doubleTapGesture)
        
        tapGesture.require(toFail: doubleTapGesture)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update player state if needed
        if viewModel.isPlaying {
            uiViewController.player?.play()
        } else {
            uiViewController.player?.pause()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CustomVideoPlayerView
        
        init(_ parent: CustomVideoPlayerView) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            parent.viewModel.togglePlayback()
        }
        
        @objc func handleDoubleTap() {
            parent.viewModel.restartVideo()
        }
    }
}

// MARK: - Check If User Liked
extension FeedCell {
    /// Checks userLikes to see if current user has a doc where postId == this post
    @MainActor
    private func checkIfUserLiked() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let postId = post.id else {
            isLiked = false
            return
        }

        do {
            let query = Firestore.firestore()
                .collection("userLikes")
                .whereField("userId", isEqualTo: userId)
                .whereField("postId", isEqualTo: postId)
                .limit(to: 1)

            let snapshot = try await query.getDocuments()
            // If there's at least 1 doc => user has liked
            isLiked = !snapshot.isEmpty
        } catch {
            print("Error checking if user liked post: \(error.localizedDescription)")
            isLiked = false
        }
    }
}

// MARK: - Observe Like Count (Optional)
extension FeedCell {
    private func observeLikeCount() {
        guard let postId = post.id else { return }

        // Query all docs in userLikes for this postId
        let query = Firestore.firestore()
            .collection("userLikes")
            .whereField("postId", isEqualTo: postId)

        // Attach a snapshot listener
        countListener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error fetching like docs: \(error?.localizedDescription ?? "")")
                return
            }
            self.likeCount = snapshot.documents.count
        }
    }
}