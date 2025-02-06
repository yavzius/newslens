import Foundation
import FirebaseFirestore
import Network
import FirebaseStorage
enum FirebaseError: Error {
    case networkError(String)
    case serverError(String)
    case cacheError(String)
    case unknown(String)
}

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db: Firestore
    private var networkMonitor: NWPathMonitor?
    private var isOnline = false
    
    private init() {
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        
        // Initialize Firestore with settings
        db = Firestore.firestore()
        db.settings = settings
        
        // Setup network monitoring
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            self?.isOnline = path.status == .satisfied
            print("Network status changed: \(path.status == .satisfied ? "Online" : "Offline")")
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }
    
    deinit {
        networkMonitor?.cancel()
    }
    
    func fetchPosts() async throws -> [Post] {
        do {
            let snapshot = try await db.collection("posts")
                .limit(to: 20)
                .order(by: "created_at", descending: true)
                .getDocuments(source: isOnline ? .default : .cache)
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Post.self)
            }
        } catch let error as NSError {
            switch error.domain {
            case NSPOSIXErrorDomain where error.code == 50:
                throw FirebaseError.networkError("Network connection is down. Using cached data if available.")
            case FirestoreErrorDomain:
                switch error.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    throw FirebaseError.serverError("Firestore service is currently unavailable")
                case FirestoreErrorCode.notFound.rawValue:
                    throw FirebaseError.cacheError("No cached data available")
                default:
                    throw FirebaseError.unknown(error.localizedDescription)
                }
            default:
                throw FirebaseError.unknown(error.localizedDescription)
            }
        }
    }
    
    func fetchUserData(userId: String) async throws -> [String: Any] {
        do {
            let document = try await db.collection("users")
                .document(userId)
                .getDocument(source: isOnline ? .default : .cache)
            
            guard let data = document.data() else {
                throw FirebaseError.cacheError("User data not found")
            }
            
            return data
        } catch let error as NSError {
            throw handleFirebaseError(error)
        }
    }

    func updateProfilePhoto(uid: String, image: UIImage) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert image to data"])
        }

        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")

        _ = try await storageRef.putDataAsync(imageData, metadata: nil)

        let downloadURL = try await storageRef.downloadURL()

        try await db.collection("users")
            .document(uid)
            .setData([
                "photoURL": downloadURL.absoluteString
            ], merge: true)

        return downloadURL
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile {
        let doc = try await db.collection("users")
            .document(uid)
            .getDocument()

        guard let data = doc.data() else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user document found"])
        }

        // Use our init?(id:data:) to map the dictionary to a UserProfile
        guard let profile = UserProfile(id: doc.documentID, data: data) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user data"])
        }

        return profile
    }

    func updateUserProfile(_ profile: UserProfile) async throws {
        try await db.collection("users")
            .document(profile.id)
            .setData([
                "displayName": profile.displayName
                // Add other fields you want to update
            ], merge: true)
    }
    
    func fetchLikedPosts(userId: String) async throws -> [Post] {
    do {
        // 1) Fetch all docs in userLikes for this user
        let userLikesSnapshot = try await db.collection("userLikes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        // Extract the postIds from the userLikes docs
        let postIds = userLikesSnapshot.documents
            .compactMap { $0["postId"] as? String }
        
        // 2) For each postId, fetch the Post from "posts" collection
        var likedPosts: [Post] = []
        
        for postId in postIds {
            let postDoc = try await db.collection("posts")
                .document(postId)
                .getDocument()
            
            if let postData = postDoc.data(),
               let post = try? postDoc.data(as: Post.self) {
                likedPosts.append(post)
            }
        }
        
        return likedPosts
    } catch let error as NSError {
        // Use your existing error handling if you like
        throw handleFirebaseError(error)
    }
}

     func likePostByUser(userId: String, postId: String) async throws {
        // 1) Query for an existing doc where userId == userId AND postId == postId
        let query = db.collection("userLikes")
            .whereField("userId", isEqualTo: userId)
            .whereField("postId", isEqualTo: postId)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        if !snapshot.isEmpty {
            // Already liked
            return
        }
        
        // 2) Otherwise, create a new doc
        // Optionally, generate your own doc ID like "\(userId)_\(postId)"
        let docData: [String: Any] = [
            "userId": userId,
            "postId": postId,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("userLikes").addDocument(data: docData)
    }
    
    func unlikePostByUser(userId: String, postId: String) async throws {
        let query = db.collection("userLikes")
            .whereField("userId", isEqualTo: userId)
            .whereField("postId", isEqualTo: postId)
        
        let snapshot = try await query.getDocuments()
        
        // Delete each doc found, typically it should only be one
        for doc in snapshot.documents {
            try await db.collection("userLikes").document(doc.documentID).delete()
        }
    }
    
    private func handleFirebaseError(_ error: NSError) -> FirebaseError {
        switch error.domain {
        case NSPOSIXErrorDomain where error.code == 50:
            return .networkError("Network connection is down. Using cached data if available.")
        case FirestoreErrorDomain:
            switch error.code {
            case FirestoreErrorCode.unavailable.rawValue:
                return .serverError("Firestore service is currently unavailable")
            case FirestoreErrorCode.notFound.rawValue:
                return .cacheError("No cached data available")
            default:
                return .unknown(error.localizedDescription)
            }
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

extension FirebaseManager {
     func checkUserSetup(uid: String) async -> Bool {
        do {
            let docSnapshot = try await db.collection("users").document(uid).getDocument()
            
            // If doc doesn't exist, user is NOT setup
            guard let docData = docSnapshot.data() else {
                return false
            }
            
            // Check if "displayName" is set
            if let displayName = docData["displayName"] as? String, !displayName.isEmpty {
                return true
            }
            return false
            
        } catch {
            print("Error checking user setup: \(error.localizedDescription)")
            return false
        }
    }
    
    // Actually create/update the user's doc
    func setupUserInFirestore(userId: String, displayName: String) async throws {
        let userRef = db.collection("users").document(userId)
        
        // If you need more fields, add them here
        let data: [String: Any] = [
            "displayName": displayName,
            "updated_at": FieldValue.serverTimestamp()
        ]
        
        // Use setData(…, merge: true) to either create or update the doc
        try await userRef.setData(data, merge: true)
    }
}

// MARK: - Comment Model
struct Comment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case userId
        case content
        case createdAt = "created_at"
    }
}

// MARK: - Comment Functions
extension FirebaseManager {
    /// Adds a new comment to a post
    func addComment(postId: String, userId: String, content: String) async throws {
        print("DEBUG: Adding comment for postId: \(postId), userId: \(userId)")
        let commentData: [String: Any] = [
            "postId": postId,
            "userId": userId,
            "content": content,
            "created_at": FieldValue.serverTimestamp()
        ]
        
        do {
            let ref = try await db.collection("comments").addDocument(data: commentData)
            print("DEBUG: Successfully added comment with ID: \(ref.documentID)")
        } catch {
            print("DEBUG: Error adding comment: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches all comments for a specific post
    func fetchComments(for postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "created_at", descending: false)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            var commentData = document.data()
            commentData["id"] = document.documentID
            
            // Handle the Timestamp conversion
            if let timestamp = commentData["created_at"] as? Timestamp {
                commentData["created_at"] = timestamp.dateValue()
            }
            
            return try Firestore.Decoder().decode(Comment.self, from: commentData)
        }
    }
    
    /// Sets up a real-time listener for comments on a specific post
    func listenForComments(
        postId: String,
        completion: @escaping (Result<[Comment], Error>) -> Void
    ) -> ListenerRegistration {
        print("DEBUG: Setting up comment listener for postId: \(postId)")
        
        return db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "created_at", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: Error listening for comments: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("DEBUG: No documents in comment snapshot")
                    completion(.success([]))
                    return
                }
                
                print("DEBUG: Received \(documents.count) comment documents")
                let comments = documents.compactMap { document -> Comment? in
                    let data = document.data()
                    
                    guard let postId = data["postId"] as? String,
                          let userId = data["userId"] as? String,
                          let content = data["content"] as? String,
                          let timestamp = data["created_at"] as? Timestamp else {
                        print("DEBUG: Missing required fields in comment data: \(data)")
                        return nil
                    }
                    
                    return Comment(
                        id: document.documentID,
                        postId: postId,
                        userId: userId,
                        content: content,
                        createdAt: timestamp.dateValue()
                    )
                }
                
                print("DEBUG: Successfully decoded \(comments.count) comments")
                completion(.success(comments))
            }
    }
    
    /// Fetches a user's profile data for displaying with comments
    func fetchCommentUserProfile(userId: String) async throws -> (displayName: String, photoURL: String?) {
        let document = try await db.collection("users")
            .document(userId)
            .getDocument()
        
        guard let data = document.data() else {
            throw FirebaseError.cacheError("User profile not found")
        }
        
        return (
            displayName: data["displayName"] as? String ?? "Unknown User",
            photoURL: data["photoURL"] as? String
        )
    }
}

extension FirebaseManager {
    // MARK: - Like Management
    
    func checkIfPostLiked(userId: String, postId: String) async throws -> Bool {
        let query = db.collection("userLikes")
            .whereField("userId", isEqualTo: userId)
            .whereField("postId", isEqualTo: postId)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        return !snapshot.isEmpty
    }
    
    func observeLikeCount(postId: String, completion: @escaping (Result<Int, Error>) -> Void) -> ListenerRegistration {
        let query = db.collection("userLikes")
            .whereField("postId", isEqualTo: postId)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let snapshot = snapshot else {
                completion(.success(0))
                return
            }
            
            completion(.success(snapshot.documents.count))
        }
    }
}