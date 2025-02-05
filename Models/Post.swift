import Foundation
import FirebaseFirestore

public struct Post: Identifiable, Codable {
    @DocumentID public var id: String?  
    let created_at: Date
    let headline: String?
    let likes: Int
    let shares: Int
    let subtitle: String?
    let userId: String
    let videoURL: String
}
