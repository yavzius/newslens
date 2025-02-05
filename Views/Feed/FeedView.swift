import SwiftUI
import FirebaseFirestore
import Foundation
import UIKit

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                ProgressView()
            } else if let error = viewModel.error {
                VStack {
                    Text("Error loading feed")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                    Button("Retry") {
                        Task {
                            await viewModel.loadFeed()
                        }
                    }
                }
            } else {
                feedContent
            }
        }
        .task {
            await viewModel.loadFeed()
        }
    }
    
    private var feedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.feedItems) { post in
                    FeedCell(post: post)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .environmentObject(viewModel)
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .edgesIgnoringSafeArea(.all)
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

#Preview {
    FeedView()
}
