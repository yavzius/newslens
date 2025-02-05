//
//  MockData.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import Foundation
import SwiftUI
import AVKit
import FirebaseStorage

// Model for a news video (or article) used in the TikTok-like feed.
struct Article: Identifiable {
    let id = UUID()
    let category: String?
    let timestamp: String       // e.g., "Feb. 3, 2025, 3:31 p.m. ET Just now"
    let headline: String        // Main title
    let subheadline: String?    // Secondary title
    let description: String?    // Brief description (if needed)
    let readDuration: String?   // e.g., "5 min read"
    let videoURL: String        // Firebase Storage URL
    
    // Get the download URL for the video
    func getVideoDownloadURL(completion: @escaping (URL?) -> Void) {
        let storage = Storage.storage()
        let videoRef = storage.reference(forURL: videoURL)
        
        videoRef.downloadURL { url, error in
            if let error = error {
                print("❌ Error getting download URL: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let downloadURL = url {
                print("✅ Got download URL: \(downloadURL)")
                completion(downloadURL)
            } else {
                completion(nil)
            }
        }
    }
}

// Sample mock data based on top headlines.
let mockArticles: [Article] = [
    Article(
        category: "LIVE",
        timestamp: "Feb. 3, 2025, 3:31 p.m. ET Just now",
        headline: "Delaying Mexico Tariffs, Trump Takes Aggressive Posture With Canada",
        subheadline: "After Tariff Fight With Canada and Mexico, Trump's Next Target Is Europe",
        description: "President Trump said he would pause tariffs on Mexico for a month, but levies on Canada and China were still set to take effect on Tuesday.",
        readDuration: "5 min read",
        videoURL: "gs://nlbackend.firebasestorage.app/media/video2.mp4"
    ),
    Article(
        category: "LIVE",
        timestamp: "Feb. 3, 2025, 3:28 p.m. ET 3m ago",
        headline: "Democratic Lawmakers Join Protest Outside Shuttered U.S. Aid Agency",
        subheadline: nil,
        description: "Secretary of State Marco Rubio said he was the acting administrator of the U.S. Agency for International Development, which was targeted for closure by Elon Musk.",
        readDuration: nil,
        videoURL: "gs://nlbackend.firebasestorage.app/media/video1.mp4"
    )
]

// Helper extension to write data to a temporary URL
extension Data {
    func writeToTemporaryURL() -> URL? {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            print("📝 Writing video to temporary file: \(temporaryFileURL.path)")
            try self.write(to: temporaryFileURL)
            
            // Verify the file exists and get its size
            let attributes = try FileManager.default.attributesOfItem(atPath: temporaryFileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("✅ Successfully wrote video file. Size: \(fileSize) bytes")
            
            return temporaryFileURL
        } catch {
            print("❌ Error writing video data to temporary file: \(error)")
            return nil
        }
    }
}

