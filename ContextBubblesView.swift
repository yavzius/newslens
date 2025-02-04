//
//  ContextBubblesView.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import SwiftUI

struct ContextBubblesView: View {
    @State private var timelinePosition: Double = 0.0
    @State private var bubbleText: String = ""
    @State private var addedBubble: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Context Bubbles & Timeline Markers")
                .font(.largeTitle)
                .padding(.bottom)
            
            // Timeline Slider Placeholder
            Text("Select Timeline Position:")
                .font(.headline)
            Slider(value: $timelinePosition, in: 0...1)
                .padding(.horizontal)
            Text("Position: \(Int(timelinePosition * 100))%")
                .padding(.horizontal)
            
            // Bubble Text Field
            Text("Enter context bubble text or link:")
                .font(.headline)
            TextField("e.g., More info here...", text: $bubbleText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: {
                // Add bubble at timelinePosition with bubbleText (Placeholder action)
                addedBubble = "Bubble at \(Int(timelinePosition * 100))%: \(bubbleText)"
            }) {
                Text("Add Context Bubble")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if let bubble = addedBubble {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added Bubble:")
                        .font(.headline)
                    Text(bubble)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Context Bubbles")
    }
}

struct ContextBubblesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContextBubblesView()
        }
    }
}
