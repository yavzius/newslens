struct UserProfile: Codable, Identifiable {
    let id: String  // This should match the Firestore document ID
    let displayName: String
    // Add other fields as you need (photoURL, etc.)

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    // An optional init that can parse from a Firestore dictionary if you prefer
    init?(id: String, data: [String: Any]) {
        guard let displayName = data["displayName"] as? String else { return nil }
        self.id = id
        self.displayName = displayName
    }
}