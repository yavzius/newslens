import SwiftUI
import FirebaseFirestore
import Foundation
import FirebaseAuth
@MainActor
class FeedViewModel: ObservableObject {
    @Published var feedItems: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    private var likeListeners: [String: ListenerRegistration] = [:]
    
    deinit {
        // Create a local copy of listeners to remove them safely
        let listenersToRemove = likeListeners
        listenersToRemove.values.forEach { listener in
            listener.remove()
        }
    }
    
    nonisolated private func removeAllListeners() {
        // Since this is nonisolated, we need to be careful about thread safety
        DispatchQueue.main.async { [weak self] in
            self?.likeListeners.values.forEach { listener in
                listener.remove()
            }
            self?.likeListeners.removeAll()
        }
    }
    
    func loadFeed() async {
        isLoading = true
        do {
            feedItems = try await FirebaseManager.shared.fetchPosts()
            setupLikeListeners()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    private func setupLikeListeners() {
        // Remove existing listeners
        removeAllListeners()
        
        // Setup new listeners for each post
        for post in feedItems {
            guard let postId = post.id else { continue }
            
            let listener = Firestore.firestore()
                .collection("posts")
                .document(postId)
                .addSnapshotListener { [weak self] documentSnapshot, error in
                    guard let document = documentSnapshot else {
                        print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    guard let self = self,
                          let updatedPost = try? document.data(as: Post.self) else { return }
                    
                    // Update the post in feedItems
                    if let index = self.feedItems.firstIndex(where: { $0.id == postId }) {
                        self.feedItems[index] = updatedPost
                    }
                }
            
            likeListeners[postId] = listener
        }
    }

    func testFirestoreConnection() async {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("posts").getDocuments()
            for document in snapshot.documents {
                print("Document ID: \(document.documentID) => \(document.data())")
            }
            print("Successfully read from Firestore!")
        } catch {
            print("Error reading from Firestore: \(error.localizedDescription)")
        }
    }
    
    func likePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        do {
            try await FirebaseManager.shared.likePostByUser(userId: userId, postId: postId)
            // No need to reload feed as the listener will handle the update
        } catch {
            self.error = error
        }
    }
    
    func unlikePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else { return }
        
        do {
            try await FirebaseManager.shared.unlikePostByUser(userId: userId, postId: postId)
            // No need to reload feed as the listener will handle the update
        } catch {
            self.error = error
        }
    }
    
    // Helper method to check if a post is liked by current user
    func isPostLikedByCurrentUser(_ post: Post) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid,
              let postId = post.id else { return false }
        
        do {
            return try await FirebaseManager.shared.checkIfPostLiked(userId: userId, postId: postId)
        } catch {
            print("Error checking like status: \(error.localizedDescription)")
            return false
        }
    }
} 
