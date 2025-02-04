//
//  AuthView.swift
//  newslens
//
//  Created by ga on 2/3/25.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Newslens")
                .font(.largeTitle)
                .bold()
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .padding(.horizontal)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button("Sign In") {
                authManager.signIn(email: email, password: password) { result in
                    switch result {
                    case .success:
                        print("User signed in")
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Sign Up") {
                authManager.signUp(email: email, password: password) { result in
                    switch result {
                    case .success:
                        print("User signed up")
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
