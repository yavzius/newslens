import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthManager
    
    private let gridItems: [GridItem] = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                HStack(spacing: 16) {
                    // Profile Image
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
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.user?.displayName ?? authManager.user?.email ?? "User")
                            .font(.headline)
                        if authManager.user?.displayName != nil {
                            Text(authManager.user?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Stats View
                HStack(spacing: 0) {
                    StatView(value: "6", title: "My Rewards")
                    StatView(value: "6/203", title: "Daily points")
                    StatView(value: "0 days", title: "Daily streak")
                }
                .padding(.vertical, 8)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Liked Posts Grid
                if !viewModel.likedPosts.isEmpty {
                    LazyVGrid(columns: gridItems, spacing: 1) {
                        ForEach(viewModel.likedPosts) { post in
                            PostGridItem(post: post)
                                .frame(height: 120)
                        }
                    }
                } else {
                    Text("No liked posts yet")
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                }
            }
        }
        .task {
            await viewModel.fetchLikedPosts()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
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
    @Published var user: FirebaseAuth.User? = Auth.auth().currentUser
    @Published var likedPosts: [Post] = []
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let firebaseManager = FirebaseManager.shared
    
    func fetchLikedPosts() async {
        guard let userId = user?.uid else { return }
        
        do {
            self.likedPosts = try await firebaseManager.fetchLikedPosts(userId: userId)
        } catch let error as FirebaseError {
            showError = true
            switch error {
            case .networkError(let message),
                 .serverError(let message),
                 .cacheError(let message),
                 .unknown(let message):
                errorMessage = message
            }
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
