import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    
    var loggedIn = true

    var body: some View {
        
        // If no user is signed in, show the full-screen AuthView.
        // Otherwise, show the main logged-in view.
//        if authManager.user == nil
        Group {
            if !loggedIn {
                AuthView()
                    .environmentObject(authManager)
            } else {
                MainTabView()
                    .environmentObject(authManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
