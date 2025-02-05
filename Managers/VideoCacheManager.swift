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