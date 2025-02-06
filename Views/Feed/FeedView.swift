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
    @State private var isRefreshing = false
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                feedContent
            }
        }
        .task {
            await viewModel.loadFeed()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your feed...")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Error loading feed")
                .foregroundColor(.red)
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                HapticManager.playMediumImpact()
                Task {
                    await viewModel.loadFeed()
                }
            }) {
                Text("Retry")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private var feedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            RefreshControl(coordinateSpace: .named("RefreshControl"), onRefresh: { done in
                Task {
                    await viewModel.loadFeed()
                    done()
                }
            })
            
            LazyVStack(spacing: 0) {
                ForEach(viewModel.feedItems) { post in
                    FeedCell(post: post)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .environmentObject(viewModel)
                        .transition(.opacity)
                }
            }
        }
        .coordinateSpace(name: "RefreshControl")
        .scrollTargetBehavior(.paging)
        .edgesIgnoringSafeArea(.all)
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

// MARK: - RefreshControl
struct RefreshControl: View {
    let coordinateSpace: CoordinateSpace
    let onRefresh: (@escaping () -> Void) -> Void
    
    @State private var refresh: Bool = false
    @State private var frozen: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.frame(in: coordinateSpace).midY > 50 {
                Spacer()
                    .onAppear {
                        if !refresh {
                            HapticManager.playLightImpact()
                            refresh = true
                        }
                    }
            } else if geometry.frame(in: coordinateSpace).midY < 1 {
                Spacer()
                    .onAppear {
                        if refresh {
                            refresh = false
                        }
                    }
            }
            ZStack(alignment: .center) {
                if refresh && !frozen {
                    ProgressView()
                        .onAppear {
                            frozen = true
                            onRefresh {
                                withAnimation(.easeInOut) {
                                    frozen = false
                                    refresh = false
                                }
                            }
                        }
                }
            }
            .frame(width: geometry.size.width)
            .offset(y: -geometry.size.height + (refresh && frozen ? 50 : 0))
        }
        .frame(height: 0)
    }
}

#Preview {
    FeedView()
}
