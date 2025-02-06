import SwiftUI
import FirebaseFirestore
import Foundation
import FirebaseAuth
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
        guard let postId = post.id else {
            // Handle the case where post.id is nil
            return
        }
        do {
            try await FirebaseManager.shared.likePostByUser(userId: userId, postId: postId)
            await loadFeed()
        } catch {
            self.error = error
        }
    }
    
    func unlikePost(_ post: Post) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let postId = post.id else {
            // Handle the case where post.id is nil
            return
        }
        do {
            try await FirebaseManager.shared.unlikePostByUser(userId: userId, postId: postId)
            await loadFeed()
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
