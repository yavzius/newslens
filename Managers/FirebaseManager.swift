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