import Foundation
import FirebaseFirestore

public struct Post: Identifiable, Codable, Equatable {
    @DocumentID public var id: String?  
    let created_at: Date
    let headline: String?
    let likes: Int
    let shares: Int
    let subtitle: String?
    let userId: String
    let videoURL: String
    
    public static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id &&
               lhs.created_at == rhs.created_at &&
               lhs.headline == rhs.headline &&
               lhs.likes == rhs.likes &&
               lhs.shares == rhs.shares &&
               lhs.subtitle == rhs.subtitle &&
               lhs.userId == rhs.userId &&
               lhs.videoURL == rhs.videoURL
    }
}
