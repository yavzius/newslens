Below are two straightforward suggestions to (1) add rudimentary video caching and (2) fix or simplify cell sizing so that the layout is more predictable. These examples aim for minimal, easy-to-maintain code changes rather than elaborate custom solutions.
---
1. Simple Video Caching
Because you’re using Firebase Storage, the easiest caching approach is:
Check for a local file on disk before downloading from Firebase.
If found, create an AVURLAsset from the local file. Otherwise, download from Firebase, store it locally, then play.
Here’s a small “VideoCacheManager” to demonstrate. Configure your file path as needed:
import Foundation
import AVFoundation

actor VideoCacheManager {
    static let shared = VideoCacheManager()

    private init() { }

    func localFileURL(for videoID: UUID) -> URL {
        // Documents directory with a unique filename
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("\(videoID.uuidString).mp4")
    }

    func fileExists(for videoID: UUID) -> URL? {
        let fileURL = localFileURL(for: videoID)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func cacheVideo(data: Data, for videoID: UUID) throws -> URL {
        let fileURL = localFileURL(for: videoID)
        try data.write(to: fileURL)
        return fileURL
    }
}
Then, in your FeedCellViewModel:
@MainActor
func setupVideo(storageURL: String, articleID: UUID) {
    // 1) Check if file is cached
    if let localURL = VideoCacheManager.shared.fileExists(for: articleID) {
        // Already cached; load from local file
        print("✔️ Using cached video at: \(localURL)")
        Task {
            await setupPlayerWithAsset(AVURLAsset(url: localURL))
        }
        return
    }
    
    // 2) Otherwise, download from Firebase Storage
    let storage = Storage.storage()
    let videoRef = storage.reference(forURL: storageURL)
    
    isLoading = true
    Task {
        do {
            let data = try await videoRef.data(maxSize: 50 * 1024 * 1024) // 50MB limit, adjust if needed
            let cachedURL = try VideoCacheManager.shared.cacheVideo(data: data, for: articleID)
            print("✅ Downloaded & cached video at: \(cachedURL)")
            
            let asset = AVURLAsset(url: cachedURL)
            try await asset.loadValues(forKeys: ["playable", "duration"])
            await setupPlayerWithAsset(asset)
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            self.isLoading = false
        }
    }
}
> Note: This approach downloads the full file (instead of streaming). For short clips this is fine, but if your videos are large, consider HLS or partial download approaches with AVAssetDownloadURLSession. However, the above is simpler and works well for small/medium video files.
---
2. Fixing / Simplifying Cell Sizing
Your rotation trick with TabView can cause sizing confusion. If you want the simplest vertical scrolling approach, remove the rotation and use SwiftUI’s TabView with a dedicated style (or just switch to a ScrollView + LazyVStack). For a standard vertical feed, here’s a more streamlined approach:
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex = 0
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                ProgressView()
            } else if let error = viewModel.error {
                /* handle error */
            } else {
                // A vertical paging TabView (iOS 14+):
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, article in
                        FeedCell(article: article)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .rotationEffect(.degrees(0))  // remove the rotation
            }
        }
        .task {
            await viewModel.loadFeed()
        }
    }
}
This removes the geometry rotation and uses a vertical pager with minimal fuss. If you truly need a “swipe horizontally, then rotate the content” UI, verify your geometry sizes and constraints. For instance, you may need to fix the frame(width:height:) calls so that you aren’t forcing unwanted clipping. A typical approach is:
TabView {
    ForEach( /* items */ ) { item in
        FeedCell(article: item)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
Then let each FeedCell handle its own sizing without rotations. If the rotation is truly needed for a “TikTok style” effect, ensure you rotate the content consistently and remove extra offset or contradictory frames.
---
Key Takeaways
Caching: A tiny VideoCacheManager using FileManager is often enough for small/medium clips.
Sizing: Remove or reduce complicated rotations and frames. Let SwiftUI’s .page TabView or a ScrollView + LazyVStack handle vertical layout. Stick to .frame(maxWidth: .infinity, maxHeight: .infinity) to avoid unexpected clipping.
With these two changes, you’ll see simpler code plus more efficient performance on limited networks.