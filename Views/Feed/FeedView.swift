import SwiftUI
import FirebaseFirestore
import Foundation
import UIKit

// MARK: - Haptic Feedback Manager
private enum HapticManager {
    static func playLightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func playMediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedPost: Post?
    @State private var showingComments = false
    @State private var visiblePostID: String?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.feedItems) { post in
                        FeedItemView(post: post,
                            onLike: {
                                Task {
                                    await viewModel.likePost(post)
                                }
                            },
                            onUnlike: {
                                Task {
                                    await viewModel.unlikePost(post)
                                }
                            },
                            onCommentTap: {
                                selectedPost = post
                                showingComments = true
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(post.id)
                        .onAppear {
                            visiblePostID = post.id
                            viewModel.setActiveVideo(UUID(uuidString: post.id ?? "") ?? UUID())
                        }
                        .onDisappear {
                            if visiblePostID == post.id {
                                visiblePostID = nil
                            }
                        }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
            .background(Color.black)
        }
        .sheet(isPresented: $showingComments) {
            if let post = selectedPost {
                CommentsView(post: post)
            }
        }
        .refreshable {
            await viewModel.loadFeed()
        }
        .task {
            await viewModel.loadFeed()
        }
    }
}

#Preview {
    FeedView()
}
