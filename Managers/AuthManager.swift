import FirebaseAuth
import FirebaseStorage
import SwiftUI

// MARK: - AuthManager
class AuthManager: ObservableObject {
    @Published var user: User? = nil
    private let storage = Storage.storage()

    init() {
        self.user = Auth.auth().currentUser
    }

    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = authResult?.user {
                DispatchQueue.main.async {
                    self.user = user
                }
                completion(.success(user))
            }
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = authResult?.user {
                DispatchQueue.main.async {
                    self.user = user
                }
                completion(.success(user))
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    func checkUserSetup(uid: String) async -> Bool {
        await FirebaseManager.shared.checkUserSetup(uid: uid)
    }
    
    func setupUserInFirestore(userId: String, displayName: String) async throws {
        try await FirebaseManager.shared.setupUserInFirestore(userId: userId, displayName: displayName)
    }
    
    func updateProfile(displayName: String? = nil, photoURL: URL? = nil) async throws {
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        
        if let displayName = displayName {
            changeRequest?.displayName = displayName
        }
        
        if let photoURL = photoURL {
            changeRequest?.photoURL = photoURL
        }
        
        try await changeRequest?.commitChanges()
        // Update local user
        self.user = Auth.auth().currentUser
    }
    
    func uploadProfileImage(_ image: UIImage) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let userId = user?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image"])
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        // Upload image data
        _ = try await storageRef.putDataAsync(imageData, metadata: nil)
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        
        // Update user profile with new photo URL
        try await updateProfile(photoURL: downloadURL)
        
        return downloadURL
    }
}

// MARK: - Profile Image Selection
extension AuthManager {
    func handleImageSelection(image: UIImage) async {
        do {
            _ = try await uploadProfileImage(image)
        } catch {
            print("Error uploading profile image: \(error.localizedDescription)")
        }
    }
}
