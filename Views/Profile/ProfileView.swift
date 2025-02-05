import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthManager

    @State private var showPhotoPicker = false
     @State private var selectedImageItem: PhotosPickerItem?
    @State private var isUploading = false
    
    private let gridItems: [GridItem] = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Profile Header
                HStack(spacing: 16) {
                    // Profile Image
                     ZStack {
                        if let photoURL = authManager.user?.photoURL {
                            AsyncImage(url: photoURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                        }
                        
                        // Show progress if uploading
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .onTapGesture {
                        showPhotoPicker = true
                    }
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $selectedImageItem,
                        matching: .images
                    )
                    .onChange(of: selectedImageItem) {
                        Task {
                            await loadAndUploadImage()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Show displayName from profile
                        Text(viewModel.profile?.displayName ?? "User")
                            .font(.headline)

                        // Show user’s email
                        if let userEmail = authManager.user?.email {
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                }
    
               
                
                // Stats View
                HStack(spacing: 0) {
                    StatView(value: "6", title: "Following")
                    StatView(value: "203", title: "Followers")
                    StatView(value: "4", title: "Likes")
                }
                .padding(.vertical, 8)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // // Liked Posts Grid
                // if !viewModel.likedPosts.isEmpty {
                //     LazyVGrid(columns: gridItems, spacing: 1) {
                //         ForEach(viewModel.likedPosts) { post in
                //             PostGridItem(post: post)
                //                 .frame(height: 120)
                //         }
                //     }
                // } else {
                //     Text("No liked posts yet")
                //         .foregroundColor(.gray)
                //         .padding(.top, 40)
                // }
            }
            .padding(.vertical, 20)
        }
        .task {
            await viewModel.loadCurrentUserData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func loadAndUploadImage() async {
    // Make sure we have a valid PhotosPickerItem
    guard let selectedImageItem else { return }
    
    // Indicate upload has started
    isUploading = true
    defer {
        // Always reset the upload state when done
        isUploading = false
    }

    do {
        // Load the raw Data from the user’s photo selection
        let data = try await selectedImageItem.loadTransferable(type: Data.self)
        guard let data, let uiImage = UIImage(data: data) else {
            print("No valid image data found.")
            return
        }
        
        // Optional: Compress the image before upload (e.g., 80% quality)
        guard
            let compressedData = uiImage.jpegData(compressionQuality: 0.8),
            let compressedUIImage = UIImage(data: compressedData)
        else {
            print("Failed to compress image.")
            return
        }

        // Call your AuthManager to upload the profile image to Storage
        _ = try await authManager.uploadProfileImage(compressedUIImage)
        
        // Optionally reload or refresh your user profile data
        await viewModel.loadCurrentUserData()
        
    } catch {
        // You could also set an @Published error property to show an Alert or Toast
        print("Error uploading image: \(error.localizedDescription)")
    }
}
}

struct StatView: View {
    let value: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PostGridItem: View {
    let post: Post
    
    var body: some View {
        AsyncImage(url: URL(string: post.videoURL)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    ProgressView()
                )
        }
        .clipped()
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false

    private let profileRepo: FirebaseManager

    init(profileRepo: FirebaseManager = FirebaseManager.shared) {
        self.profileRepo = profileRepo
    }

    func loadCurrentUserData() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            profile = nil
            return
        }

        do {
            let fetchedProfile = try await profileRepo.fetchUserProfile(uid: uid)
            profile = fetchedProfile
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func saveDisplayName(_ newName: String) async {
        guard var existingProfile = profile else { return }
        existingProfile = UserProfile(id: existingProfile.id, displayName: newName)

        do {
            try await profileRepo.updateUserProfile(existingProfile)
            profile = existingProfile  // Update local model
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
