import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var displayName: String = ""
    @State private var errorMessage: String = ""
    @State private var isSettingUp = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Let’s get you set up!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Display Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button(action: {
                Task {
                    await handleSubmit()
                }
            }, label: {
                if isSettingUp {
                    ProgressView()
                } else {
                    Text("Finish Setup")
                        .fontWeight(.semibold)
                }
            })
            .disabled(isSettingUp || displayName.isEmpty)
            
            Spacer()
        }
        .padding()
    }
    
    private func handleSubmit() async {
        guard let user = authManager.user else { return }
        
        do {
            isSettingUp = true
            try await authManager.setupUserInFirestore(userId: user.uid, displayName: displayName)
            // Optionally, refresh or navigate away. 
            // For example:
            // You could pop this view off if you’re using a navigation stack, or rely on 
            // the `ContentView` logic to detect the user is set up & show MainTabView.
        } catch {
            errorMessage = error.localizedDescription
        }
        isSettingUp = false
    }
}