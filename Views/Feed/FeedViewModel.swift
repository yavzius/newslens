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
        guard let postId = post.id else { return }
        do {
            try await FirebaseManager.shared.incrementLikes(postId: postId)
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