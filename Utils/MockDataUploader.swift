import Foundation
import FirebaseFirestore
import FirebaseStorage

class MockDataUploader {
    static let shared = MockDataUploader()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadMockData() async throws {
        // Convert mock articles to posts
        for article in mockArticles {
            // Create a post document
            let post = Post(
                id: nil,
                userId: "mock_user_1", // Mock user ID
                videoURL: article.videoURL,
                caption: article.headline,
                timestamp: Date(),
                likes: Int.random(in: 10...1000),
                shares: Int.random(in: 5...500)
            )
            
            // Add to Firestore
            do {
                try await db.collection("posts").addDocument(from: post)
                print("✅ Successfully uploaded post: \(post.caption ?? "")")
            } catch {
                print("❌ Error uploading post: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

// MARK: - Usage Example
#if DEBUG
extension MockDataUploader {
    static func uploadMockDataIfNeeded() {
        Task {
            do {
                try await shared.uploadMockData()
                print("✅ Mock data upload completed")
            } catch {
                print("❌ Error uploading mock data: \(error.localizedDescription)")
            }
        }
    }
}
#endif
