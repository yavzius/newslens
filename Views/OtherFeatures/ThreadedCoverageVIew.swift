//
//  ThreadedCoverageVIew.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import SwiftUI

struct ThreadedCoverageView: View {
    @State private var threadTitle: String = ""
    @State private var segments: [String] = ["Segment 1: Introduction"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Collaborative Threaded Coverage")
                .font(.largeTitle)
                .padding(.bottom)
            
            // Text Field to add a new segment
            Text("Add a new segment to the thread:")
                .font(.headline)
            TextField("Enter segment title", text: $threadTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: {
                if !threadTitle.isEmpty {
                    segments.append(threadTitle)
                    threadTitle = ""
                }
            }) {
                Text("Add Segment")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Display the thread segments
            List {
                ForEach(segments, id: \.self) { segment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(segment)
                            .font(.headline)
                        // Placeholder: Each segment could show additional branding details
                        Text("Creator branding info")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Spacer()
        }
        .navigationTitle("Threaded Coverage")
    }
}

struct ThreadedCoverageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ThreadedCoverageView()
        }
    }
}
