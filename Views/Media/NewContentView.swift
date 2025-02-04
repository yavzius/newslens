import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import PhotosUI

@preconcurrency import AVFoundation

final class MovieCapture: NSObject, @unchecked Sendable {
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentDelegate: MovieCaptureDelegate?
    
    var isRecording: Bool {
        movieOutput.isRecording
    }
    
    func configure(in session: AVCaptureSession) throws {
        guard session.canAddOutput(movieOutput) else {
            throw NSError(domain: "MovieCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to add movie output"])
        }
        
        session.beginConfiguration()
        session.addOutput(movieOutput)
        
        // Configure video connection for optimal quality
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }
        session.commitConfiguration()
    }
    
    func startRecording() async throws -> URL {
        // Create a unique file URL in the temporary directory
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                // Create new delegate and retain it
                let newDelegate = MovieCaptureDelegate(continuation: continuation)
                currentDelegate = newDelegate
                
                // Start recording with the delegate
                movieOutput.startRecording(to: outputURL, recordingDelegate: newDelegate)
            } catch {
                currentDelegate = nil
                continuation.resume(throwing: error)
            }
        }
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording else { 
            throw NSError(domain: "MovieCapture", code: 4, userInfo: [NSLocalizedDescriptionKey: "Not recording"]) 
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let delegate = currentDelegate else {
                continuation.resume(throwing: NSError(domain: "MovieCapture", code: 6, userInfo: [NSLocalizedDescriptionKey: "No active recording delegate"]))
                return
            }
            
            // Update the continuation for the existing delegate
            delegate.continuation = continuation
            movieOutput.stopRecording()
        }
    }
    
    deinit {
        if isRecording {
            movieOutput.stopRecording()
        }
        currentDelegate = nil
    }
}

private class MovieCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var continuation: CheckedContinuation<URL, Error>
    
    init(continuation: CheckedContinuation<URL, Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Ensure we only resume the continuation once
        defer {
            // Clean up by removing the reference to self
            if let movieOutput = output as? AVCaptureMovieFileOutput {
                // Instead of accessing delegate directly, we'll just stop recording if needed
                if movieOutput.isRecording {
                    movieOutput.stopRecording()
                }
            }
        }
        
        if let error = error {
            continuation.resume(throwing: error)
            return
        }
        
        // Verify the recorded file exists and has content
        if FileManager.default.fileExists(atPath: outputFileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                if let size = attributes[.size] as? UInt64, size > 0 {
                    continuation.resume(returning: outputFileURL)
                } else {
                    continuation.resume(throwing: NSError(domain: "MovieCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty recording file"]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        } else {
            continuation.resume(throwing: NSError(domain: "MovieCapture", code: 3, userInfo: [NSLocalizedDescriptionKey: "Recording file not found"]))
        }
    }
    
    func cleanUp() {
        // Clean up any resources if needed
    }
}

final class CameraManager: ObservableObject {
    @Published private(set) var captureSession: AVCaptureSession?
    private let movieCapture = MovieCapture()
    @Published private(set) var isRecording = false
    @Published private(set) var capturedMedia: URL?
    @Published var currentVideoClip: VideoClip?
    @Published private(set) var recordingDuration: Double = 0.0
    @Published var showVideoEditor = false
    private var recordingTimer: Timer?
    private var isConfigured = false
    
    func configure() async throws {
        guard !isConfigured else { return }
        print("📸 CameraManager: Starting configuration...")
        
        // Create and configure capture session
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high // Use high quality preset
        
        print("📸 CameraManager: Configuring video device...")
        // Configure back camera with specific configuration
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get camera device"])
        }
        
        // Configure video device for optimal recording
        try videoDevice.lockForConfiguration()
        if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
            videoDevice.exposureMode = .continuousAutoExposure
        }
        if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
            videoDevice.focusMode = .continuousAutoFocus
        }
        videoDevice.unlockForConfiguration()
        
        print("📸 CameraManager: Adding video input...")
        // Add video input
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else {
            throw NSError(domain: "CameraManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to add video input"])
        }
        session.addInput(videoInput)
        
        print("📸 CameraManager: Adding audio input...")
        // Add audio input with error handling
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    print("📸 CameraManager: Audio input added successfully")
                }
            } catch {
                print("📸 CameraManager: Warning - Could not add audio input: \(error.localizedDescription)")
            }
        }
        
        print("📸 CameraManager: Configuring movie capture...")
        try movieCapture.configure(in: session)
        session.commitConfiguration()
        
        // Update session on main thread
        await MainActor.run {
            self.captureSession = session
            self.isConfigured = true
        }
        
        print("📸 CameraManager: Starting capture session...")
        // Start the session on a background thread
        Task.detached {
            session.startRunning()
            print("📸 CameraManager: Capture session is running")
        }
    }
    
    @MainActor
    func startRecording() async throws {
        print("📸 CameraManager: Attempting to start recording...")
        
        guard !isRecording else {
            print("📸 CameraManager: Warning - Already recording")
            return
        }
        
        guard let session = captureSession, session.isRunning else {
            print("📸 CameraManager: Error - Capture session not running")
            throw NSError(domain: "CameraManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Capture session not running"])
        }
        
        // Reset recording duration and start timer
        recordingDuration = 0.0
        startRecordingTimer()
        
        // Start recording
        isRecording = true
        do {
            let outputURL = try await movieCapture.startRecording()
            capturedMedia = outputURL
            
            // Create video clip and show editor
            let clip = VideoClip(
                id: UUID().uuidString,
                url: outputURL,
                startTime: .zero,
                endTime: .indefinite,
                adjustments: VideoAdjustments(),
                order: 0
            )
            currentVideoClip = clip
            showVideoEditor = true
        } catch {
            isRecording = false
            stopRecordingTimer()
            throw error
        }
    }
    
    @MainActor
    func stopRecording() {
        print("📸 CameraManager: Stopping recording...")
        guard isRecording else {
            print("📸 CameraManager: Warning - Not recording")
            return
        }
        
        Task {
            do {
                let outputURL = try await movieCapture.stopRecording()
                isRecording = false
                stopRecordingTimer()
                capturedMedia = outputURL
            } catch {
                print("📸 CameraManager: Error stopping recording - \(error.localizedDescription)")
                isRecording = false
                stopRecordingTimer()
            }
        }
    }
    
    @MainActor
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
        RunLoop.main.add(recordingTimer!, forMode: .common)
    }
    
    @MainActor
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    @MainActor
    func cleanup() {
        print("📸 CameraManager: Cleaning up resources...")
        if let session = captureSession {
            // Stop session on background thread
            Task.detached {
                session.stopRunning()
            }
        }
        
        // Clean up timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0.0
        
        captureSession = nil
        capturedMedia = nil
        currentVideoClip = nil
        isConfigured = false
        print("📸 CameraManager: Cleanup completed")
    }
}

class VideoCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    weak var cameraManager: CameraManager?
    var showVideoEditor: Binding<Bool>
    var completionHandler: ((URL?, Error?) -> Void)?
    
    init(cameraManager: CameraManager, showVideoEditor: Binding<Bool>) {
        self.cameraManager = cameraManager
        self.showVideoEditor = showVideoEditor
        super.init()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("📸 VideoCaptureDelegate: Recording finished")
        
        if let error = error {
            print("📸 VideoCaptureDelegate: Recording error - \(error.localizedDescription)")
            completionHandler?(nil, error)
            return
        }
        
        // Verify the recorded file
        if FileManager.default.fileExists(atPath: outputFileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                if let size = attributes[.size] as? UInt64, size > 0 {
                    print("📸 VideoCaptureDelegate: Valid recording file created - \(size) bytes")
                    completionHandler?(outputFileURL, nil)
                    
                    // Create a VideoClip and navigate to editor
                    Task { @MainActor in
                        let clip = VideoClip(
                            id: UUID().uuidString,
                            url: outputFileURL,
                            startTime: .zero,
                            endTime: .indefinite,
                            adjustments: VideoAdjustments(),
                            order: 0
                        )
                        cameraManager?.currentVideoClip = clip
                        showVideoEditor.wrappedValue = true
                    }
                } else {
                    print("📸 VideoCaptureDelegate: Invalid recording file - zero size")
                    completionHandler?(nil, NSError(domain: "VideoCaptureDelegate", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid recording file"]))
                }
            } catch {
                print("📸 VideoCaptureDelegate: Error reading file attributes - \(error.localizedDescription)")
                completionHandler?(nil, error)
            }
        } else {
            print("📸 VideoCaptureDelegate: Recording file not found")
            completionHandler?(nil, NSError(domain: "VideoCaptureDelegate", code: 5, userInfo: [NSLocalizedDescriptionKey: "Recording file not found"]))
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.name = "CameraPreviewLayer"
        
        // Configure preview layer for vertical video
        if let connection = previewLayer.connection {
            // Force portrait orientation for 9:16 video
            connection.videoOrientation = .portrait
            
            // Handle device orientation
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main) { _ in
                    self.updatePreviewLayerOrientation(previewLayer)
                }
        }
        
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first(where: { $0.name == "CameraPreviewLayer" }) as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
                updatePreviewLayerOrientation(previewLayer)
            }
        }
    }
    
    private func updatePreviewLayerOrientation(_ previewLayer: AVCaptureVideoPreviewLayer) {
        guard let connection = previewLayer.connection else { return }
        
        let orientation = UIDevice.current.orientation
        let videoOrientation: AVCaptureVideoOrientation
        
        switch orientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            // Force portrait for vertical video
            videoOrientation = .portrait
        case .landscapeRight:
            // Force portrait for vertical video
            videoOrientation = .portrait
        default:
            videoOrientation = .portrait
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        NotificationCenter.default.removeObserver(uiView, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}

struct NewContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @StateObject private var cameraManager = CameraManager()
    @State private var showVideoEditor = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let session = cameraManager.captureSession {
                    CameraPreview(session: session)
                        .ignoresSafeArea()
                    
                    VStack {
                        // Top controls
                        HStack {
                            Button {
                                if cameraManager.isRecording {
                                    stopRecording()
                                }
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 20)
                            
                            Spacer()
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                        
                        // Recording timer
                        if cameraManager.isRecording {
                            Text(formatDuration(cameraManager.recordingDuration))
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        
                        // Record button
                        Button {
                            if cameraManager.isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        } label: {
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Group {
                                        if cameraManager.isRecording {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white)
                                                .frame(width: 32, height: 32)
                                        } else {
                                            Circle()
                                                .stroke(Color.red, lineWidth: 4)
                                                .frame(width: 70, height: 70)
                                        }
                                    }
                                )
                        }
                        .disabled(!(cameraManager.captureSession?.isRunning ?? false))
                        .padding(.bottom, 30)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showVideoEditor) {
                if let clip = cameraManager.currentVideoClip {
                    VideoEditorView(clip: clip)
                        .navigationBarBackButtonHidden(true)
                        .onDisappear {
                            cameraManager.cleanup()
                        }
                }
            }
            .task {
                do {
                    try await requestCameraPermission()
                    try await cameraManager.configure()
                } catch {
                    print("📸 Camera setup failed: \(error.localizedDescription)")
                    dismiss()
                }
            }
            .onDisappear {
                if !showVideoEditor {
                    cameraManager.cleanup()
                }
            }
        }
    }
    
    private func requestCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw NSError(domain: "CameraManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Camera access denied"])
            }
        case .denied, .restricted:
            throw NSError(domain: "CameraManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Camera access denied"])
        @unknown default:
            throw NSError(domain: "CameraManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unknown camera authorization status"])
        }
        
        // Also check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                print("📸 Warning: Microphone access denied - proceeding with video only")
            }
        case .denied, .restricted:
            print("📸 Warning: Microphone access denied - proceeding with video only")
        @unknown default:
            print("📸 Warning: Unknown microphone authorization status - proceeding with video only")
        }
    }
    
    private func startRecording() {
        Task {
            do {
                try await cameraManager.startRecording()
            } catch {
                print("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
    
    private func stopRecording() {
        cameraManager.stopRecording()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
