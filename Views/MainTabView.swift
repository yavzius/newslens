import SwiftUI

struct MainTabView: View {
    @State private var isShowingNewContent = false
    @EnvironmentObject var authManager: AuthManager
    var body: some View {
        TabView {
            FeedView()
                .ignoresSafeArea(.container, edges: [.top])
                .tabItem {
                    Label("Feed", systemImage: "house.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .environmentObject(authManager)
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isShowingNewContent = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .offset(y: -10)
                    Spacer()
                }
            }
        )
        .fullScreenCover(isPresented: $isShowingNewContent) {
            NewContentView(isPresented: $isShowingNewContent)
        }
    }
}
