import Foundation
import FirebaseFirestore

@MainActor
class PostCacheManager: ObservableObject {
    static let shared = PostCacheManager()
    
    @Published private(set) var posts: [String: Post] = [:]
    private var listeners: [String: ListenerRegistration] = [:]
    
    private init() {}
    
    func getPost(_ postId: String) -> Post? {
        return posts[postId]
    }
    
    func cachePost(_ post: Post) {
        guard let postId = post.id else { return }
        posts[postId] = post
    }
    
    func startListening(for postId: String) {
        guard listeners[postId] == nil else { return }
        
        let listener = Firestore.firestore()
            .collection("posts")
            .document(postId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let post = try? Firestore.Decoder().decode(Post.self, from: data) else {
                    return
                }
                
                self.posts[postId] = post
            }
        
        listeners[postId] = listener
    }
    
    func stopListening(for postId: String) {
        listeners[postId]?.remove()
        listeners[postId] = nil
    }
    
    func clearCache() {
        posts.removeAll()
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
} 