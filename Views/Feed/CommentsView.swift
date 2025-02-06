import SwiftUI
import FirebaseAuth

struct CommentsView: View {
    let post: Post
    @StateObject private var viewModel: CommentViewModel
    @State private var newComment = ""
    @Environment(\.dismiss) private var dismiss
    
    init(post: Post) {
        self.post = post
        _viewModel = StateObject(wrappedValue: CommentViewModel())
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Comments list
                List(viewModel.comments) { comment in
                    CommentRow(comment: comment, userProfile: viewModel.userProfiles[comment.userId])
                }
                .onAppear {
                    print("DEBUG: Loading comments for post ID: \(post.id ?? "nil")")
                    print("DEBUG: Current comments count: \(viewModel.comments.count)")
                }
                
                // Comment input
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        Task {
                            await viewModel.addComment(postId: post.id ?? "", content: newComment)
                            newComment = ""
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(newComment.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                    }
                }
            }
        }
        .onAppear {
            guard let postId = post.id else {
                print("DEBUG: Error - Post ID is nil")
                return
            }
            print("DEBUG: Starting to load comments for post: \(postId)")
            viewModel.loadComments(for: postId)
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    let userProfile: (displayName: String, photoURL: String?)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: userProfile?.photoURL ?? "")) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(userProfile?.displayName ?? "Unknown User")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(comment.content)
                    .font(.body)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
} 