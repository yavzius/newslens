import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CommentViewModel: ObservableObject {
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var userProfiles: [String: (displayName: String, photoURL: String?)] = [:]
    @Published var errorMessage: String?
    
    private var listener: ListenerRegistration?
    private let firebaseManager: FirebaseManager
    
    init(firebaseManager: FirebaseManager = .shared) {
        self.firebaseManager = firebaseManager
    }
    
    func loadComments(for postId: String) {
        startRealtimeUpdates(for: postId)
    }
    
    func startRealtimeUpdates(for postId: String) {
        listener?.remove()
        
        listener = firebaseManager.listenForComments(postId: postId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success(let newComments):
                    self.comments = newComments
                    await self.fetchUserProfiles()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func addComment(postId: String, content: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to comment"
            return
        }
        
        do {
            try await firebaseManager.addComment(postId: postId, userId: userId, content: content)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchUserProfiles() async {
        let newUserIds = Set(comments.map(\.userId)).subtracting(userProfiles.keys)
        guard !newUserIds.isEmpty else { return }
        
        for userId in newUserIds {
            do {
                userProfiles[userId] = try await firebaseManager.fetchCommentUserProfile(userId: userId)
            } catch {
                print("Failed to fetch profile for user \(userId): \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
} 
