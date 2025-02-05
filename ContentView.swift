import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
     @State private var isUserSetup = false
    @State private var isCheckingSetup = true
    
    var loggedIn = true

    var body: some View {
        Group {
            if isCheckingSetup {
                ProgressView("Checking account setup...")
                    .task {
                        await handleSetupCheck()
                    }
            } else if authManager.user == nil {
                // Show sign-in screen
                AuthView()
            } else if !isUserSetup {
                // Show profile setup
                ProfileSetupView()
                 .environmentObject(authManager)
            } else {
                // Show main UI
                MainTabView()
            }
        }
    }
    
    private func handleSetupCheck() async {
        guard let user = authManager.user else {
            isCheckingSetup = false
            return
        }
        // Use either the convenience method inside AuthManager
        // or call FirebaseManager.shared directly
        isUserSetup = await authManager.checkUserSetup(uid: user.uid)
        isCheckingSetup = false
    }
}

#Preview {
    ContentView()
}
