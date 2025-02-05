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
    @State private var appearAnimation = false
    
    private let gridItems: [GridItem] = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    // NewsLens brand colors - professional, trustworthy, and modern
    private let gradientColors = [
        Color(red: 0.95, green: 0.95, blue: 0.97), // Light background
        Color(red: 0.98, green: 0.98, blue: 1.0)   // Subtle variation
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Profile Header
                VStack(spacing: 24) {
                    // Profile Image
                    ZStack {
                        if let photoURL = authManager.user?.photoURL {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .tint(Color(red: 0.2, green: 0.2, blue: 0.3))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .transition(.opacity.combined(with: .scale))
                                case .failure(_):
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                        }
                        
                        // Show progress if uploading
                        if isUploading {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.2, blue: 0.3)))
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPhotoPicker = true
                        }
                    }
                    
                    VStack(spacing: 8) {
                        // Show displayName from profile
                        Text(viewModel.profile?.displayName ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))

                        // Show user's email
                        if let userEmail = authManager.user?.email {
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.7))
                        }
                    }
                }
                .offset(y: appearAnimation ? 0 : 30)
                .opacity(appearAnimation ? 1 : 0)
    
                // Stats View
                HStack(spacing: 0) {
                    StatView(value: "6", title: "Following")
                    Divider()
                        .frame(height: 24)
                        .background(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.1))
                    StatView(value: "203", title: "Followers")
                    Divider()
                        .frame(height: 24)
                        .background(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.1))
                    StatView(value: "4", title: "Likes")
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                )
                .padding(.horizontal)
                .offset(y: appearAnimation ? 0 : 20)
                .opacity(appearAnimation ? 1 : 0)
            }
            .padding(.vertical, 20)
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
        .background(
            ZStack {
                LinearGradient(gradient: Gradient(colors: gradientColors),
                             startPoint: .top,
                             endPoint: .bottom)
                    .ignoresSafeArea()
                
                // Subtle pattern overlay
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let spacing: CGFloat = 40
                        
                        for x in stride(from: 0, through: width, by: spacing) {
                            for y in stride(from: 0, through: height, by: spacing) {
                                path.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                            }
                        }
                    }
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.03))
                }
            }
        )
        .task {
            await viewModel.loadCurrentUserData()
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
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
        // Load the raw Data from the user's photo selection
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
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
            Text(title)
                .font(.caption)
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.7))
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
