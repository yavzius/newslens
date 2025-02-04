//
//  MockData.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import Foundation
import SwiftUI

// Model for a news video (or article) used in the TikTok-like feed.
struct Article: Identifiable {
    let id = UUID()
    let category: String?
    let timestamp: String       // e.g., "Feb. 3, 2025, 3:31 p.m. ET Just now"
    let headline: String        // Main title
    let subheadline: String?    // Secondary title
    let description: String?    // Brief description (if needed)
    let readDuration: String?   // e.g., "5 min read"
    // For mock purposes, use an asset name for the video placeholder.
    let imageName: String?
}

// Sample mock data based on top headlines.
let mockArticles: [Article] = [
    Article(
        category: "LIVE",
        timestamp: "Feb. 3, 2025, 3:31 p.m. ET Just now",
        headline: "Delaying Mexico Tariffs, Trump Takes Aggressive Posture With Canada",
        subheadline: "After Tariff Fight With Canada and Mexico, Trump’s Next Target Is Europe",
        description: "President Trump said he would pause tariffs on Mexico for a month, but levies on Canada and China were still set to take effect on Tuesday.",
        readDuration: "5 min read",
        imageName: "video_placeholder1" // Ensure this image is in your Assets.xcassets
    ),
    Article(
        category: "LIVE",
        timestamp: "Feb. 3, 2025, 3:28 p.m. ET 3m ago",
        headline: "Democratic Lawmakers Join Protest Outside Shuttered U.S. Aid Agency",
        subheadline: nil,
        description: "Secretary of State Marco Rubio said he was the acting administrator of the U.S. Agency for International Development, which was targeted for closure by Elon Musk.",
        readDuration: nil,
        imageName: "video_placeholder2"
    )
]
