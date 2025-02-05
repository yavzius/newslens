import Foundation
import FirebaseFirestore

public struct Post: Identifiable, Codable {
    public let id: String?
    let userId: String
    let videoURL: String
    let caption: String?
    let timestamp: Date
    let likes: Int
    let shares: Int
    let headline: String?
    let subtitle: String?
    
    public enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case videoURL = "video_url"
        case caption
        case timestamp
        case likes
        case shares
        case headline
        case subtitle
    }
}
