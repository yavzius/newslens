import SwiftUI
import FirebaseFirestore
import Foundation

@MainActor
class FeedViewModel: ObservableObject {
    @Published var feedItems: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadFeed() async {
        isLoading = true
        do {
            feedItems = try await FirebaseManager.shared.fetchPosts()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    func likePost(_ post: Post) async {
        guard let postId = post.id else { return }
        do {
            try await FirebaseManager.shared.incrementLikes(postId: postId)
        } catch {
            self.error = error
        }
    }
    
    func sharePost(_ post: Post) async {
        guard let postId = post.id else { return }
        do {
            try await FirebaseManager.shared.incrementShares(postId: postId)
        } catch {
            self.error = error
        }
    }
} 