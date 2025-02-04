import SwiftUI
import AVKit

struct MediaViewer: View {
    let mediaURL: URL
    
    var body: some View {
        Group {
            // If the URL ends with "mp4", display a video.
            if mediaURL.pathExtension.lowercased() == "mp4" {
                VideoPlayer(player: AVPlayer(url: mediaURL))
                    .frame(height: 300)
            } else {
                // Otherwise, assume it's an image.
                AsyncImage(url: mediaURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure(let error):
                        Text("Failed to load image: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    @unknown default:
                        Text("Unexpected error")
                    }
                }
            }
        }
        .padding()
        .onAppear {
            print("MediaViewer appeared with URL: \(mediaURL)")
        }
    }
}

struct MediaViewer_Previews: PreviewProvider {
    static var previews: some View {
        MediaViewer(mediaURL: URL(string: "https://example.com/sample.jpg")!)
    }
}
