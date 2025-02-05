import Foundation
import FirebaseFirestore
import Network

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
    
    func incrementLikes(postId: String) async throws {
        guard isOnline else {
            throw FirebaseError.networkError("Cannot update likes while offline")
        }
        
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
    
    func fetchLikedPosts(userId: String) async throws -> [Post] {
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("likedPosts")
                .order(by: "created_at", descending: true)
                .getDocuments(source: isOnline ? .default : .cache)
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Post.self)
            }
        } catch let error as NSError {
            throw handleFirebaseError(error)
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