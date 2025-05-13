//
//  ForgotPasswordScreen.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isEmailValid = false
    @FocusState private var isEmailFocused: Bool
    
    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
        static let backgroundGradient = LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.1)]), startPoint: .top, endPoint: .bottom)
    }
    
    var body: some View {
        ZStack {
            Constants.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                    }
                    .padding(.trailing, 16)
                    .accessibilityLabel("Dismiss")
                }
                
                Image("4")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(radius: 5)
                
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text("Enter your email to receive a password reset link")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .leading) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .offset(y: email.isEmpty && !isEmailFocused ? 0 : -20)
                                .scaleEffect(email.isEmpty && !isEmailFocused ? 1 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: isEmailFocused)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                TextField("", text: $email)
                                    .textInputAutocapitalization(.none)
                                    .focused($isEmailFocused)
                                    .onChange(of: email) { newValue in
                                        isEmailValid = isValidEmail(newValue)
                                    }
                                    .accessibilityLabel("Email")
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isEmailValid && !email.isEmpty ? Color.green : errorMessage.contains("email") ? Color.red : Color.gray.opacity(0.3), lineWidth: isEmailValid && !email.isEmpty ? 1.5 : 1)
                            )
                        }
                        Text("Enter your registered email address")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                }
                
                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                }
                
                Button(action: {
                    Auth.auth().sendPasswordReset(withEmail: email) { error in
                        if let error = error {
                            errorMessage = "Error: \(error.localizedDescription)"
                            successMessage = ""
                        } else {
                            successMessage = "Password reset email sent!"
                            errorMessage = ""
                        }
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Text("Send Reset Email")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Constants.buttonGradient)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                }
                .padding(.horizontal, 24)
                .accessibilityLabel("Send Reset Email Button")
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }
                .accessibilityLabel("Cancel")
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}
