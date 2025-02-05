import Foundation
import FirebaseFirestore

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchPosts() async throws -> [Post] {
        let snapshot = try await db.collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)  // Adjust limit as needed
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Post.self)
        }
    }
    
    func incrementLikes(postId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        try await postRef.updateData([
            "likes": FieldValue.increment(Int64(1))
        ])
    }
    
    func incrementShares(postId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        try await postRef.updateData([
            "shares": FieldValue.increment(Int64(1))
        ])
    }
}
