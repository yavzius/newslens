import Foundation

struct Article: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    let author: String?
    let publishedDate: Date
    let imageUrl: String?
    let sourceUrl: String
    let category: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: publishedDate)
    }
} 