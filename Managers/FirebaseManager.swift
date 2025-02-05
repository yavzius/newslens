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
}
