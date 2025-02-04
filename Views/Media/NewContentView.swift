import SwiftUI
import MijickCamera
import FirebaseStorage
import FirebaseFirestore

struct NewContentView: View {
    // If this view is presented as a full-screen cover, you might still have a binding
    // from a parent view. For simplicity, we'll assume this view persists while the camera is active.
    // If you need the media to persist across dismissal of this view, consider moving it
    // into an external ObservableObject.
    @Binding var isPresented: Bool
    @State private var isUploading = false
    @State private var mediaURL: URL?
    @State private var showMediaViewer = false

    var body: some View {
        ZStack {
            // MCamera configuration.
            MCamera()
                .setCameraOutputType(.video) // or .photo if you wish; adjust as needed.
                .setResolution(.hd1920x1080)
                .setFlashMode(.auto)
                // When an image is captured, call our handler.
                .onImageCaptured { image, controller in
                    handleMediaCapture(image: image, controller: controller)
                }
                // When a video is captured, call our handler.
                .onVideoCaptured { videoURL, controller in
                    handleMediaCapture(videoURL: videoURL, controller: controller)
                }
                // You can set a close action if you want to allow the user to exit.
                // For now, we comment this out so that closing the camera doesn’t reset our state.
                //.setCloseMCameraAction { isPresented = false }
                .startSession()
            
            if isUploading {
                ProgressView("Uploading...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        // Present the media viewer sheet over the camera view.
        .sheet(isPresented: $showMediaViewer, onDismiss: {
            // Optionally clear the mediaURL after dismissal.
            mediaURL = nil
        }) {
            Group {
                if let url = mediaURL {
                    MediaViewer(mediaURL: url)
                        .onAppear {
                            print("MediaViewer appeared with URL: \(url)")
                        }
                } else {
                    Text("No media to display")
                }
            }
        }
    }
    
    /// Handles the media capture event from MCamera.
    private func handleMediaCapture(image: UIImage? = nil, videoURL: URL? = nil, controller: MCamera.Controller) {
        isUploading = true
        
        uploadMedia(image: image, videoURL: videoURL) { urlString in
            if let urlString = urlString, let url = URL(string: urlString) {
                // Save the URL to Firestore.
                saveToFirestore(mediaURL: urlString)
                // Update the state so that the sheet appears.
                DispatchQueue.main.async {
                    print("Setting mediaURL to: \(url)")
                    self.mediaURL = url
                    self.showMediaViewer = true
                }
            } else {
                print("Upload failed")
            }
            isUploading = false
            // Reopen the camera screen to allow further captures.
            controller.reopenCameraScreen()
        }
    }
    
    /// Uploads the captured image or video to Firebase Storage.
    private func uploadMedia(image: UIImage? = nil, videoURL: URL? = nil, completion: @escaping (String?) -> Void) {
        let storage = Storage.storage().reference()
        
        // If an image was captured...
        if let image = image {
            // Append the .jpg extension so the URL reflects an image file.
            let mediaRef = storage.child("media/\(UUID().uuidString).jpg")
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                completion(nil)
                return
            }
            
            mediaRef.putData(imageData, metadata: nil) { _, error in
                if error == nil {
                    mediaRef.downloadURL { url, error in
                        if let url = url {
                            print("Download URL: \(url)")
                            completion(url.absoluteString)
                        } else {
                            print("Failed to get download URL: \(error?.localizedDescription ?? "unknown error")")
                            completion(nil)
                        }
                    }
                } else {
                    completion(nil)
                }
            }
        }
        // If a video was captured...
        else if let videoURL = videoURL {
            // Append the .mp4 extension.
            let mediaRef = storage.child("media/\(UUID().uuidString).mp4")
            mediaRef.putFile(from: videoURL, metadata: nil) { _, error in
                if error == nil {
                    mediaRef.downloadURL { url, error in
                        if let url = url {
                            print("Download URL: \(url)")
                            completion(url.absoluteString)
                        } else {
                            print("Failed to get download URL: \(error?.localizedDescription ?? "unknown error")")
                            completion(nil)
                        }
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    /// Saves the media URL to Firestore.
    private func saveToFirestore(mediaURL: String) {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "mediaURL": mediaURL,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "draft"
        ]
        
        db.collection("posts").addDocument(data: data) { error in
            if let error = error {
                print("Error saving to Firestore: \(error.localizedDescription)")
            }
        }
    }
}
