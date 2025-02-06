import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Haptic Feedback Manager
private enum HapticManager {
    static func playLightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func playMediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct DetailedPostView: View {
    let post: Post
    @StateObject private var viewModel: FeedCellViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @State private var isTransitioning = false
    @State private var showLoadingOverlay = true
    
    // MARK: - Initialization
    init(post: Post) {
        self.post = post
        _viewModel = StateObject(wrappedValue: FeedCellViewModel(postID: UUID(uuidString: post.id ?? "") ?? UUID()))
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video Player
                if viewModel.isVideoReady {
                    CustomVideoPlayerView(viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
                        .opacity(isTransitioning ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: isTransitioning)
                } else {
                    loadingView
                }
                
                // Content Overlay
                VStack(spacing: 0) {
                    // Navigation Bar
                    navigationBar
                    
                    Spacer()
                    
                    // Post Information
                    postInformation
                }
                .padding(.vertical)
                .opacity(showLoadingOverlay ? 0 : 1)
                .animation(.easeIn(duration: 0.3), value: showLoadingOverlay)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
        }
        .navigationBarHidden(true)
        .onAppear {
            setupVideo()
            Task {
                // Update initial like state
                viewModel.isLiked = await feedViewModel.isPostLikedByCurrentUser(post)
                // Delay the fade in of content
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                withAnimation {
                    showLoadingOverlay = false
                }
            }
        }
        .onDisappear {
            isTransitioning = true
            viewModel.cleanup()
        }
        .onChange(of: post) { newPost in
            viewModel.updatePost(newPost)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button(action: {
                HapticManager.playLightImpact()
                withAnimation {
                    isTransitioning = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding()
            
            Spacer()
        }
    }
    
    // MARK: - Post Information
    private var postInformation: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Headline
            if let headline = post.headline {
                Text(headline)
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Subtitle
            if let subtitle = post.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Interaction Buttons
            HStack(spacing: 20) {
                Spacer()
                
                // Like Button
                LikeButton(post: post, feedViewModel: feedViewModel)
                    .transition(.scale.combined(with: .opacity))
                
                // Comments Button
                CommentsButton(post: post)
                    .transition(.scale.combined(with: .opacity))
                
                // Share Button
                ShareButton(post: post)
                    .transition(.scale.combined(with: .opacity))
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    private func setupVideo() {
        if viewModel.player == nil {
            Task {
                await viewModel.setupVideo(storageURL: post.videoURL)
            }
        }
    }
}

// MARK: - Interaction Buttons
struct LikeButton: View {
    let post: Post
    @ObservedObject var feedViewModel: FeedViewModel
    @State private var isLiked = false
    @State private var likeCount: Int = 0
    @State private var countListener: ListenerRegistration?
    @State private var isAnimating = false
    private let firebaseManager = FirebaseManager.shared
    
    var body: some View {
        Button(action: {
            HapticManager.playMediumImpact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            Task {
                if isLiked {
                    await feedViewModel.unlikePost(post)
                } else {
                    await feedViewModel.likePost(post)
                }
                await checkIfUserLiked()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundColor(isLiked ? .red : .white)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                Text("\(likeCount)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            Task {
                await checkIfUserLiked()
                observeLikeCount()
            }
        }
        .onDisappear {
            countListener?.remove()
        }
    }
    
    private func checkIfUserLiked() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let postId = post.id else {
            isLiked = false
            return
        }
        
        do {
            isLiked = try await firebaseManager.checkIfPostLiked(userId: userId, postId: postId)
        } catch {
            print("Error checking if user liked post: \(error.localizedDescription)")
            isLiked = false
        }
    }
    
    private func observeLikeCount() {
        guard let postId = post.id else { return }
        
        countListener = firebaseManager.observeLikeCount(postId: postId) { result in
            switch result {
            case .success(let count):
                self.likeCount = count
            case .failure(let error):
                print("Error fetching like docs: \(error.localizedDescription)")
            }
        }
    }
}

struct CommentsButton: View {
    let post: Post
    @State private var showComments = false
    
    var body: some View {
        Button(action: { showComments.toggle() }) {
            VStack(spacing: 4) {
                Image(systemName: "bubble.right.fill")
                    .font(.system(size: 30))
                Text("Comments")
                    .font(.caption)
            }
            .foregroundColor(.white)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
        }
    }
}

struct ShareButton: View {
    let post: Post
    
    var body: some View {
        Button(action: {
            guard let url = URL(string: post.videoURL) else { return }
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 30))
                Text("Share")
                    .font(.caption)
            }
            .foregroundColor(.white)
        }
    }
}

#Preview {
    NavigationStack {
        DetailedPostView(post: Post(
            id: "preview",
            created_at: Date(),
            headline: "Sample Headline",
            likes: 100,
            shares: 50,
            subtitle: "Sample subtitle text",
            userId: "user123",
            videoURL: "https://example.com/video.mp4"
        ))
        .environmentObject(FeedViewModel())
    }
} 