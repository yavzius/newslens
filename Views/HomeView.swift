//
//  HomeView.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Brand Kit & Video Creation", destination: BrandKitView())
                NavigationLink("Context Bubbles & Timeline Markers", destination: ContextBubblesView())
                NavigationLink("Collaborative Threaded Coverage", destination: ThreadedCoverageView())
            }
            .navigationTitle("Newslens MVP")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
