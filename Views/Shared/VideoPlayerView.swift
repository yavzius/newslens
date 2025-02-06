import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let player: AVPlayer?
    
    var body: some View {
        if let player = player {
            VideoLayerView(player: player)
                .edgesIgnoringSafeArea(.all)
        } else {
            Color.black
                .edgesIgnoringSafeArea(.all)
                .overlay {
                    ProgressView()
                        .tint(.white)
                }
        }
    }
}

struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.layer.bounds
        view.layer.addSublayer(playerLayer)
        
        // Add observer for layout changes
        view.addObserver(context.coordinator, forKeyPath: "bounds", options: .new, context: nil)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.layer.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        let parent: VideoLayerView
        
        init(parent: VideoLayerView) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "bounds" {
                if let view = object as? UIView,
                   let playerLayer = view.layer.sublayers?.first as? AVPlayerLayer {
                    playerLayer.frame = view.layer.bounds
                }
            }
        }
    }
}

#Preview {
    VideoPlayerView(player: nil)
} 