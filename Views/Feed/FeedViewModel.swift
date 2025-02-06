import SwiftUI
import FirebaseFirestore
import Foundation
import FirebaseAuth

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

@MainActor
class FeedViewModel: ObservableObject {
    @Published var feedItems: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    private var likeListeners: [String: ListenerRegistration] = [:]
    private var activeVideoID: UUID?
    private var cleanupTask: Task<Void, Never>?
    
    private let cacheManager = PostCacheManager.shared
    
    deinit {
        // Immediately remove listeners since this is thread-safe
        likeListeners.values.forEach { listener in
            listener.remove()
        }
        likeListeners.removeAll()
        
        // Handle main actor operations
        if let activeID = activeVideoID {
            // Post notification synchronously since NotificationCenter is thread-safe
            NotificationCenter.default.post(
                name: NSNotification.Name("PauseVideo"),
                object: nil,
                userInfo: ["videoID": activeID]
            )
        }
        
        // Clear state
        activeVideoID = nil
        
        // Create a cleanup task for main actor-isolated operations
        cleanupTask = Task { @MainActor in
            // Capture the posts that need cleanup
            let postsToCleanup = feedItems
            
            // Clean up cache listeners
            for post in postsToCleanup {
                if let postId = post.id {
                    cacheManager.stopListening(for: postId)
                }
            }
        }
    }
    
    func setActiveVideo(_ id: UUID?) {
        // Pause previous video if exists
        if let previousID = activeVideoID, previousID != id {
            NotificationCenter.default.post(
                name: NSNotification.Name("PauseVideo"),
                object: nil,
                userInfo: ["videoID": previousID]
            )
        }
        
        activeVideoID = id
        
        // Play new video if exists
        if let newID = id {
            NotificationCenter.default.post(
                name: NSNotification.Name("PlayVideo"),
                object: nil,
                userInfo: ["videoID": newID]
            )
        }
    }
    
    func loadFeed() async {
        isLoading = true
        error = nil
        
        do {
            let posts = try await FirebaseManager.shared.fetchPosts()
            withAnimation {
                self.feedItems = posts
            }
            
            // Start listening for updates on each post
            posts.forEach { post in
                if let postId = post.id {
                    cacheManager.startListening(for: postId)
                    cacheManager.cachePost(post)
                }
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func likePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        do {
            try await FirebaseManager.shared.likePostByUser(userId: userId, postId: postId)
            HapticManager.playMediumImpact()
        } catch {
            print("Error liking post: \(error.localizedDescription)")
        }
    }
    
    func unlikePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        do {
            try await FirebaseManager.shared.unlikePostByUser(userId: userId, postId: postId)
            HapticManager.playLightImpact()
        } catch {
            print("Error unliking post: \(error.localizedDescription)")
        }
    }
    
    func isPostLikedByCurrentUser(_ post: Post) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid,
              let postId = post.id else { return false }
        
        do {
            return try await FirebaseManager.shared.checkIfPostLiked(userId: userId, postId: postId)
        } catch {
            print("Error checking if post is liked: \(error.localizedDescription)")
            return false
        }
    }
    
    func observeLikeCount(for postId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        // Remove existing listener if any
        likeListeners[postId]?.remove()
        
        // Add new listener
        let listener = FirebaseManager.shared.observeLikeCount(postId: postId) { result in
            completion(result)
        }
        
        likeListeners[postId] = listener
    }
    
    func getPost(by id: String) -> Post? {
        return cacheManager.getPost(id)
    }
} 
