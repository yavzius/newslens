//
//  MainTabView.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import SwiftUI


struct SearchView: View {
    var body: some View {
        NavigationView {
            Text("Search Page")
                .navigationTitle("Search")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationView {
            Text("Profile Page")
                .navigationTitle("Profile")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Text("Settings / Brand Kit")
                .navigationTitle("Settings")
        }
    }
}

struct MainTabView: View {
    @State private var isShowingNewContent = false

    var body: some View {
        TabView {
            FeedView()
                .ignoresSafeArea(.container, edges: [.top])
                .tabItem {
                    Label("Feed", systemImage: "house.fill")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        // Overlay a centered plus button above the tab bar.
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
        // Present the New Content view full-screen (which will later integrate video creation).
        .fullScreenCover(isPresented: $isShowingNewContent) {
            NewContentView(isPresented: $isShowingNewContent)
        }
    }
}
