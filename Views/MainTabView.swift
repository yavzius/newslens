import SwiftUI

struct MainTabView: View {
    init() {
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        
        UITabBar.appearance().standardAppearance = appearance
        
        // For iOS 15 and later, also set the scrollEdgeAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    @State private var isShowingNewContent = false
    @EnvironmentObject var authManager: AuthManager
    var body: some View {
        TabView {
            Tab("Feed", systemImage: "house.fill") {
                FeedView()
                .ignoresSafeArea(.container, edges: [.top])
            }
            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
                .environmentObject(authManager)
                }
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
