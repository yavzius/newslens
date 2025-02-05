//
//  MockData.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import Foundation
import SwiftUI
import AVKit

// Model for a news video (or article) used in the TikTok-like feed.
struct Article: Identifiable {
    let id = UUID()
    let category: String?
    let timestamp: String       // e.g., "Feb. 3, 2025, 3:31 p.m. ET Just now"
    let headline: String        // Main title
    let subheadline: String?    // Secondary title
    let description: String?    // Brief description (if needed)
    let readDuration: String?   // e.g., "5 min read"
    let videoURL: URL?         // URL for the video content
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
        videoURL: {
            print("🎥 Loading video2 from asset catalog")
            guard let dataAsset = NSDataAsset(name: "video2") else {
                print("❌ Failed to load video2 from asset catalog")
                return nil
            }
            print("✅ Successfully loaded video data: \(dataAsset.data.count) bytes")
            let url = dataAsset.data.writeToTemporaryURL()
            print("📍 Video URL created: \(String(describing: url))")
            return url
        }()
    ),
    Article(
        category: "LIVE",
        timestamp: "Feb. 3, 2025, 3:28 p.m. ET 3m ago",
        headline: "Democratic Lawmakers Join Protest Outside Shuttered U.S. Aid Agency",
        subheadline: nil,
        description: "Secretary of State Marco Rubio said he was the acting administrator of the U.S. Agency for International Development, which was targeted for closure by Elon Musk.",
        readDuration: nil,
        videoURL: {
            print("🎥 Loading video1 from asset catalog")
            guard let dataAsset = NSDataAsset(name: "video1") else {
                print("❌ Failed to load video1 from asset catalog")
                return nil
            }
            print("✅ Successfully loaded video data: \(dataAsset.data.count) bytes")
            let url = dataAsset.data.writeToTemporaryURL()
            print("📍 Video URL created: \(String(describing: url))")
            return url
        }()
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

