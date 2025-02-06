import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseFirestore

struct DetailedPostView: View {
    let post: Post
    @StateObject private var viewModel: FeedCellViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    
    // MARK: - Initialization
    init(post: Post) {
        self.post = post
        _viewModel = StateObject(wrappedValue: FeedCellViewModel(articleID: UUID(uuidString: post.id ?? "") ?? UUID()))
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video Player
                if viewModel.isVideoReady {
                    CustomVideoPlayerView(viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
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
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
        }
        .navigationBarHidden(true)
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            viewModel.cleanup()
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
            Button(action: { dismiss() }) {
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
            }
            
            // Subtitle
            if let subtitle = post.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
            }
            
            // Interaction Buttons
            HStack(spacing: 20) {
                Spacer()
                
                // Like Button
                LikeButton(post: post, feedViewModel: feedViewModel)
                
                // Comments Button
                CommentsButton(post: post)
                
                // Share Button
                ShareButton(post: post)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Helper Methods
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
    private let firebaseManager = FirebaseManager.shared
    
    var body: some View {
        Button(action: {
            Task {
                if isLiked {
                    await feedViewModel.unlikePost(post)
                } else {
                    await feedViewModel.likePost(post)
                }
                await checkIfUserLiked()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundColor(isLiked ? .red : .white)
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