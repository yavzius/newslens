import SwiftUI
import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import CoreImage.CIFilterBuiltins

/// Handles video editing operations including adjustments and clip manipulation
@Observable
final class VideoEditor: @unchecked Sendable {
    // MARK: - Properties
    private let context: CIContext = {
        print("🎨 Creating CIContext")
        // Create CIContext on the main thread with thread-safe options
        let options = [CIContextOption.useSoftwareRenderer: false,
                      CIContextOption.priorityRequestLow: false]
        return CIContext(options: options)
    }()
    var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    
    var isProcessing = false
    var progress: Double = 0.0
    var error: Error?
    
    // MARK: - Basic Adjustments
    
    /// Applies adjustments to a video clip
    /// - Parameters:
    ///   - clip: The video clip to adjust
    ///   - adjustments: The adjustments to apply
    /// - Returns: URL of the processed video
    func applyAdjustments(to clip: VideoClip, adjustments: VideoAdjustments) async throws -> URL {
        isProcessing = true
        progress = 0.0
        defer { isProcessing = false }
        
        let asset = AVURLAsset(url: clip.url)
        let composition = AVMutableComposition()
        
        // Create video track
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }
        
        // Add video track to composition
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: clip.startTime, duration: clip.duration),
            of: assetTrack,
            at: .zero
        )
        
        // Create a thread-safe copy of the context for the closure
        let processingContext = self.context
        
        // Create video composition using the new async API
        let videoComposition = try await AVMutableVideoComposition.videoComposition(with: composition) { request in
            // Apply filters
            var outputImage = request.sourceImage
            
            // Brightness adjustment
            if adjustments.brightness != 0 {
                let brightnessFilter = CIFilter.colorControls()
                brightnessFilter.inputImage = outputImage
                brightnessFilter.brightness = Float(adjustments.brightness)
                if let output = brightnessFilter.outputImage {
                    outputImage = output
                }
            }
            
            // Contrast adjustment
            if adjustments.contrast != 1 {
                let contrastFilter = CIFilter.colorControls()
                contrastFilter.inputImage = outputImage
                contrastFilter.contrast = Float(adjustments.contrast)
                if let output = contrastFilter.outputImage {
                    outputImage = output
                }
            }
            
            // Saturation adjustment
            if adjustments.saturation != 1 {
                let saturationFilter = CIFilter.colorControls()
                saturationFilter.inputImage = outputImage
                saturationFilter.saturation = Float(adjustments.saturation)
                if let output = saturationFilter.outputImage {
                    outputImage = output
                }
            }
            
            request.finish(with: outputImage, context: processingContext)
        }
        
        // Export the processed video
        let exportSession = try await export(composition: composition, videoComposition: videoComposition)
        return exportSession
    }
    
    // MARK: - Clip Manipulation
    
    /// Trims a video clip to the specified time range
    /// - Parameters:
    ///   - clip: The video clip to trim
    ///   - startTime: New start time
    ///   - endTime: New end time
    /// - Returns: The trimmed clip
    func trimClip(_ clip: VideoClip, startTime: CMTime, endTime: CMTime) async throws -> VideoClip {
        guard startTime >= .zero && endTime > startTime else {
            throw NSError(domain: "VideoEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid time range"])
        }
        
        let asset = AVURLAsset(url: clip.url)
        let composition = AVMutableComposition()
        
        // Create video track
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let assetTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoEditor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }
        
        // Add trimmed video to composition
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: startTime, duration: CMTimeSubtract(endTime, startTime)),
            of: assetTrack,
            at: .zero
        )
        
        // Export trimmed video
        let exportURL = try await export(composition: composition)
        
        // Create new clip with trimmed video
        return VideoClip(
            id: UUID().uuidString,
            url: exportURL,
            startTime: .zero,
            endTime: CMTimeSubtract(endTime, startTime),
            adjustments: clip.adjustments,
            order: clip.order
        )
    }
    
    /// Splits a video clip at the specified time
    /// - Parameters:
    ///   - clip: The video clip to split
    ///   - atTime: The time to split the clip at
    /// - Returns: Tuple containing the two resulting clips
    func splitClip(_ clip: VideoClip, atTime: CMTime) async throws -> (VideoClip, VideoClip) {
        // Create first clip
        let firstClip = try await trimClip(clip, startTime: clip.startTime, endTime: atTime)
        
        // Create second clip
        var secondClip = try await trimClip(clip, startTime: atTime, endTime: clip.endTime)
        secondClip = VideoClip(
            id: secondClip.id,
            url: secondClip.url,
            startTime: secondClip.startTime,
            endTime: secondClip.endTime,
            adjustments: secondClip.adjustments,
            order: firstClip.order + 1
        )
        
        return (firstClip, secondClip)
    }
    
    // MARK: - Preview Generation
    
    /// Generates a thumbnail for a video clip at the specified time
    /// - Parameters:
    ///   - clip: The video clip
    ///   - time: Time to generate thumbnail at
    /// - Returns: Generated thumbnail image
    func generateThumbnail(for clip: VideoClip, at time: CMTime) async throws -> UIImage {
        print("🖼️ Generating thumbnail at time: \(time.seconds)")
        let asset = AVURLAsset(url: clip.url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await generator.image(at: time).image
            print("✅ Thumbnail generated successfully")
            return UIImage(cgImage: cgImage)
        } catch {
            print("❌ Failed to generate thumbnail: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Sets up video preview for the specified clip
    /// - Parameter clip: The video clip to preview
    func setupPreview(for clip: VideoClip) {
        print("🎬 Setting up preview for clip: \(clip.id)")
        print("📍 Video URL: \(clip.url)")
        
        let asset = AVURLAsset(url: clip.url)
        let playerItem = AVPlayerItem(asset: asset)
        self.playerItem = playerItem
        print("📼 Created player item")
        
        if player == nil {
            print("🆕 Creating new AVPlayer")
            player = AVPlayer(playerItem: playerItem)
        } else {
            print("🔄 Replacing existing player item")
            player?.replaceCurrentItem(with: playerItem)
        }
        
        print("▶️ Starting playback")
        player?.play()
        
        // Add observer for player status
        if let player = player {
            print("👀 Current player status: \(player.status.rawValue)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func export(composition: AVComposition, videoComposition: AVVideoComposition? = nil) async throws -> URL {
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoEditor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = exportURL
        exportSession.outputFileType = .mp4
        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
        }
        
        // Use the new async export API
        try await exportSession.export(to: exportURL, as: .mp4)
        
        return exportURL
    }
} 