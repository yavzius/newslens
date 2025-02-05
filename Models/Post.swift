import Foundation
import FirebaseFirestoreSwift

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let videoURL: String
    let caption: String?
    let timestamp: Date
    let likes: Int
    let shares: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case videoURL = "video_url"
        case caption
        case timestamp
        case likes
        case shares
    }
}
