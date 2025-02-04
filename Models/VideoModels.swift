import Foundation
import CoreMedia
import SwiftUI

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