//
//  BrandKitView.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import SwiftUI

struct BrandKitView: View {
    @State private var selectedColor: Color = .blue
    @State private var logoImage: Image? = nil  // Placeholder for logo upload
    @State private var selectedTemplate: Int = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Brand Kit & Video Creation")
                .font(.largeTitle)
                .padding(.bottom)
            
            // Logo Upload Placeholder
            Text("Upload your logo:")
                .font(.headline)
            Button(action: {
                // Action for logo upload goes here.
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(height: 150)
                    Text("Tap to upload logo")
                        .foregroundColor(.gray)
                }
            }
            
            // Brand Color Picker
            Text("Choose a Brand Color:")
                .font(.headline)
            ColorPicker("Brand Color", selection: $selectedColor)
                .padding(.horizontal)
            
            // Pre-built Overlay Templates
            Text("Select an Overlay Template:")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(1..<4) { template in
                        Button(action: {
                            selectedTemplate = template
                        }) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(template == selectedTemplate ? selectedColor : Color.gray.opacity(0.5))
                                .frame(width: 120, height: 60)
                                .overlay(Text("Template \(template)")
                                            .foregroundColor(.white))
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Simple Trimming Tool (Placeholder Slider)
            Text("Trim Video (Placeholder):")
                .font(.headline)
            Slider(value: .constant(0.5))
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Brand Kit")
    }
}

struct BrandKitView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BrandKitView()
        }
    }
}
