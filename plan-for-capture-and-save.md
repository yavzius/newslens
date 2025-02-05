# Media Capture and Save Implementation Plan

This plan outlines a simple, maintainable approach to implementing media capture, editing, and upload functionality.

## Phase 1: Basic Media Capture Setup
- [x] Remove existing MijickCamera implementation
- [x] Set up basic SwiftUI view structure for media capture
- [x] Create MediaCaptureView using AVFoundation
  - [x] Start with just back camera
  - [x] Basic capture button
  - [x] Preview view showing camera feed
  - [x] Simple camera switch button (front/back)
- [x] Add photo library picker integration
- [x] Add basic media type selection (photo/video)
- [x] Test basic capture functionality
- [x] Set up 9:16 aspect ratio constraints for vertical video

Key Notes:
- Use `AVCaptureSession` for camera
- Use `PHPickerViewController` for library selection
- Keep UI minimal - just capture/select buttons and preview
- Enforce vertical video format (9:16 aspect ratio)
- Reuse existing permission handling code

## Phase 2: Video Editing & Composition
- [x] Create video clip management system
  - [x] Save captured clips to app's documents directory
  - [x] Generate unique filenames for clips
  - [x] Clean up old files
  - [x] Maintain clip order and timeline
- [x] Implement video editing capabilities
  - Basic adjustments
    - [x] Brightness control
    - [x] Contrast adjustment
    - [x] Saturation adjustment
  - Clip manipulation
    - [x] Trim start/end points
    - [x] Split clips
    - [x] Reorder clips in timeline
    - [x] Delete clips
  - Timeline management
    - [x] Drag and drop interface for clip ordering
    - [x] Preview thumbnail generation
    - [x] Duration indicators
- [x] Create composition preview system
  - [x] Real-time preview of edits
  - [x] Timeline scrubbing
  - [x] Frame-accurate playback
- [x] Add export functionality
  - [x] Maintain 9:16 aspect ratio
  - [x] Quality settings
  - [x] Progress indication

Key Notes:
- Use AVFoundation for video processing
- Implement efficient caching for previews
- Keep UI responsive during processing
- Focus on smooth playback and editing
- Use Swift Concurrency for processing tasks

## Phase 3: Implementation Fixes
### Capture Flow Improvements
1. Update Capture Button Behavior
   - [x] Implement tap for photo capture
   - [x] Implement long press for video recording
   - [x] Add haptic feedback for mode changes
   - [x] Add visual indicator for recording state
   - [x] Implement proper video recording start/stop

3. Remove Photo/Video Mode Switch
   - [x] Remove existing mode switch UI
   - [x] Clean up related code
   - [x] Update UI to reflect single capture button approach

### Editing Flow Implementation
1. Navigation Setup
   - [x] Create proper navigation flow from capture to edit
   - [x] Implement edit view presentation logic
   - [x] Add transition animations

2. Edit View Implementation
   - [x] Create dedicated editing view
   - [x] Implement basic editing controls layout
   - [x] Add preview capability
   - [x] Implement editing tools section

3. Testing and Validation
   - [x] Test capture to edit flow
   - [x] Verify editing capabilities
   - [x] Test navigation stack
   - [x] Verify proper state management

Key Notes:
- Focus on user experience and smooth transitions
- Ensure proper state management during mode switches
- Implement proper cleanup on view dismissal
- Add appropriate loading states and indicators

## Phase 4: Firebase Integration
- [ ] Set up Firebase Storage reference for video content
- [ ] Create upload manager
  - Chunked upload for large videos
  - Upload progress tracking
  - Error handling and resume capability
  - Success confirmation
- [ ] Implement Firestore data model for video projects
- [ ] Add location tagging
  - Simple location selection UI
  - Geotag validation
  - Location-based video discovery

Key Notes:
- Use Firebase Storage for video files with proper compression
- Use Firestore for project metadata and clip information
- Implement efficient upload strategy for large files
- Ensure proper error handling and retry logic

## Phase 5: Polish & Integration
- [ ] Add loading indicators for all processing steps
- [ ] Implement proper error messages
- [ ] Add upload progress visualization
- [ ] Implement background export and upload
- [ ] Add video processing optimizations
  - Hardware acceleration usage
  - Memory management for large videos
  - Cache management for edited clips
- [ ] Add basic retry mechanism for failed uploads
- [ ] Test all user flows
- [ ] Add export quality options
- [ ] Implement proper cleanup of temporary files

Key Notes:
- Focus on performance and memory management
- Keep UI responsive during heavy processing
- Provide clear feedback during long operations
- Test on various devices and iOS versions
- Monitor memory usage during video processing

## Data Models

```swift
// Modern Swift 6.0 implementation with proper attributes
@Observable
final class VideoProject {
    let id: String
    var clips: [VideoClip]
    var aspectRatio: CGFloat = 9.0/16.0 // Vertical video
    let timestamp: Date
    
    init(id: String = UUID().uuidString,
         clips: [VideoClip] = [],
         timestamp: Date = .now) {
        self.id = id
        self.clips = clips
        self.timestamp = timestamp
    }
}

struct VideoClip: Identifiable, Sendable {
    let id: String
    let url: URL
    var startTime: CMTime
    var endTime: CMTime
    var adjustments: VideoAdjustments
    var order: Int
    
    var duration: CMTime {
        CMTimeSubtract(endTime, startTime)
    }
}

struct VideoAdjustments: Sendable {
    var brightness: Double = 0.0 // -1.0 to 1.0
    var contrast: Double = 1.0 // 0.0 to 2.0
    var saturation: Double = 1.0 // 0.0 to 2.0
}

@Observable
final class VideoCompositionManager {
    private var composition: AVMutableComposition?
    private var videoComposition: AVMutableVideoComposition?
    
    var isProcessing: Bool = false
    var progress: Double = 0.0
    var error: Error?
    
    func createComposition(from project: VideoProject) async throws -> AVAsset {
        // Composition logic will go here
    }
    
    func exportVideo(composition: AVAsset, preset: String) async throws -> URL {
        // Export logic will go here
    }
}
```

## Implementation Tips
1. Start with basic clip management
2. Test video processing performance early
3. Use Instruments for performance profiling
4. Keep memory usage in check
5. Use meaningful variable names
6. Add comments for complex video processing logic
7. Commit code frequently
8. Use Swift Concurrency for all heavy operations
9. Leverage AVFoundation's built-in optimizations
10. Cache processed videos efficiently

## Modern Swift Features to Use
- @Observable for state management
- Structured Concurrency with async/await
- Actor isolation for thread safety
- AVFoundation modern APIs
- Sendable protocol for thread-safe types
- Swift Package Manager for dependencies
- Memory management attributes
- Background task handling

## Common Pitfalls to Avoid
1. Don't process videos on the main thread
2. Don't keep full-resolution previews in memory
3. Don't ignore memory warnings
4. Don't process all clips simultaneously
5. Don't block UI during video processing
6. Don't ignore export quality settings
7. Don't cache too many processed clips
8. Don't ignore video codec compatibility

## Testing Checklist
- [x] Video capture in correct aspect ratio
- [x] Clip management
  - [x] Adding clips
  - [x] Deleting clips
  - [x] Reordering clips
  - [x] Trimming clips
- [x] Video adjustments
  - [x] Brightness control
  - [x] Contrast adjustments
  - [x] Saturation changes
- [x] Timeline functionality
  - [x] Smooth scrubbing
  - [x] Accurate preview
  - [x] Clip reordering
- [x] Export process
  - [x] Quality settings
  - [x] Progress tracking
  - [x] Final video validation
- [ ] Upload process
  - [ ] Large file handling
  - [ ] Progress tracking
  - [ ] Error recovery
- [ ] Memory management
  - [ ] Long video handling
  - [ ] Multiple clip processing
  - [ ] Cache cleanup
- [ ] Background operation handling
- [ ] Error handling and recovery
- [x] Capture button behavior
  - [x] Photo capture on tap
  - [x] Video capture on hold
  - [x] Visual feedback
  - [x] Haptic feedback
- [ ] Camera switching
  - [ ] Front/back camera toggle
  - [ ] State persistence
- [x] Edit flow navigation
  - [x] Smooth transitions
  - [x] State preservation
  - [x] UI responsiveness

Remember: Focus on smooth video processing and editing experience first, then optimize for performance and memory usage.
