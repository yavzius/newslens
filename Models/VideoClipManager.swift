import Foundation
import AVFoundation
import SwiftUI
import CoreMedia

/// Manages video clips in the app's documents directory, handling storage, cleanup, and organization
@Observable
final class VideoClipManager {
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let clipsDirectory: URL
    
    var currentProject: VideoProject
    var error: Error?
    
    // MARK: - Initialization
    init(projectId: String = UUID().uuidString) {
        // Set up clips directory in app's documents folder
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.clipsDirectory = docs.appendingPathComponent("VideoClips", isDirectory: true)
        
        // Initialize empty project
        self.currentProject = VideoProject(id: projectId)
        
        // Create clips directory if it doesn't exist
        try? fileManager.createDirectory(at: clipsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Clip Management
    
    /// Saves a video clip to the clips directory and adds it to the current project
    /// - Parameter sourceURL: The URL of the source video clip
    /// - Returns: The saved clip's URL
    func saveClip(_ sourceURL: URL) async throws -> VideoClip {
        let filename = "\(UUID().uuidString).mp4"
        let destinationURL = clipsDirectory.appendingPathComponent(filename)
        
        // Copy clip to clips directory
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // Get clip duration
        let asset = AVURLAsset(url: destinationURL)
        let duration = try await asset.load(.duration)
        
        // Create new clip
        let clip = VideoClip(
            id: UUID().uuidString,
            url: destinationURL,
            startTime: .zero,
            endTime: duration,
            adjustments: VideoAdjustments(),
            order: currentProject.clips.count
        )
        
        // Add to project
        currentProject.clips.append(clip)
        
        return clip
    }
    
    /// Removes a clip from the project and optionally deletes its file
    /// - Parameters:
    ///   - clip: The clip to remove
    ///   - deleteFile: Whether to delete the clip's file from disk
    func removeClip(_ clip: VideoClip, deleteFile: Bool = true) throws {
        // Remove from project
        currentProject.clips.removeAll { $0.id == clip.id }
        
        // Update order of remaining clips
        for (index, _) in currentProject.clips.enumerated() {
            currentProject.clips[index].order = index
        }
        
        // Delete file if requested
        if deleteFile {
            try? fileManager.removeItem(at: clip.url)
        }
    }
    
    /// Reorders a clip in the project
    /// - Parameters:
    ///   - clip: The clip to reorder
    ///   - newOrder: The new order for the clip
    func reorderClip(_ clip: VideoClip, to newOrder: Int) {
        guard let currentIndex = currentProject.clips.firstIndex(where: { $0.id == clip.id }),
              newOrder >= 0 && newOrder < currentProject.clips.count else {
            return
        }
        
        // Remove clip from current position
        let clip = currentProject.clips.remove(at: currentIndex)
        
        // Insert at new position
        currentProject.clips.insert(clip, at: newOrder)
        
        // Update order of all clips
        for (index, _) in currentProject.clips.enumerated() {
            currentProject.clips[index].order = index
        }
    }
    
    /// Cleans up old unused clips from the clips directory
    func cleanupUnusedClips() throws {
        // Get all files in clips directory
        let clipFiles = try fileManager.contentsOfDirectory(
            at: clipsDirectory,
            includingPropertiesForKeys: nil
        )
        
        // Get URLs of clips in current project
        let activeClipURLs = Set(currentProject.clips.map { $0.url })
        
        // Delete files that aren't in the current project
        for fileURL in clipFiles {
            if !activeClipURLs.contains(fileURL) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
} 