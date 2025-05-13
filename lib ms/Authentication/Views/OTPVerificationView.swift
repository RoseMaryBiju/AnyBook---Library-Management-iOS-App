//
//  OTPVerificationScreen.swift
//  lib ms
//
//  Created by admin86 on 10/05/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct OTPVerificationScreen: View {
    let db: Firestore
    @Binding var otpData: OTPData?
    let email: String
    let onVerify: (Bool) -> Void
    @State private var enteredOTP = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.8
    @State private var inputOpacity: Double = 0.0
    @State private var inputOffset: CGFloat = 50.0
    @State private var buttonScale: CGFloat = 1.0
    @State private var isOTPValid = false
    @FocusState private var isOTPFocused: Bool
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthManager.shared
    
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
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                    .transition(.opacity.combined(with: .scale))
                
                Text("AnyBook")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .opacity(logoOpacity)
                    .transition(.opacity)
                
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundColor(Constants.accentColor)
                    .opacity(logoOpacity)
                    .transition(.opacity)
                
                Text("Verify OTP")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.accentColor)
                    .opacity(logoOpacity)
                
                Text("A 6-digit code was sent to \(email)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(logoOpacity)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .leading) {
                            Text("OTP Code")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .offset(y: enteredOTP.isEmpty && !isOTPFocused ? 0 : -20)
                                .scaleEffect(enteredOTP.isEmpty && !isOTPFocused ? 1 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: isOTPFocused)
                            
                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(.gray)
                                TextField("", text: $enteredOTP)
                                    .textInputAutocapitalization(.none)
                                    .keyboardType(.numberPad)
                                    .focused($isOTPFocused)
                                    .onChange(of: enteredOTP) { newValue in
                                        if let otpData = otpData, newValue.count == 6 {
                                            let timeInterval = Date().timeIntervalSince(otpData.timestamp)
                                            isOTPValid = newValue == otpData.code && timeInterval <= 300
                                        } else {
                                            isOTPValid = false
                                        }
                                    }
                                    .accessibilityLabel("OTP Code")
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isOTPValid && !enteredOTP.isEmpty ? Color.green : errorMessage.contains("OTP") ? Color.red : Color.gray.opacity(0.3), lineWidth: isOTPValid && !enteredOTP.isEmpty ? 1.5 : 1)
                            )
                        }
                        Text("Enter the 6-digit code sent to your email")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(inputOpacity)
                .offset(y: inputOffset)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                
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
                        .opacity(inputOpacity)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Button(action: {
                    verifyOTP()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Text("Verify OTP")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Constants.buttonGradient)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                        .scaleEffect(buttonScale)
                }
                .disabled(isLoading || enteredOTP.count != 6)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            buttonScale = 1.0
                        }
                    }
                }
                .padding(.horizontal, 24)
                .accessibilityLabel("Verify OTP Button")
                
                Button(action: {
                    resendOTP()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Text("Resend OTP")
                        .font(.subheadline)
                        .foregroundColor(Constants.accentColor)
                        .padding(.vertical, 8)
                }
                .accessibilityLabel("Resend OTP")
                
                Spacer()
            }
            .padding(.vertical)
            .overlay(
                isLoading ? ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } : nil
            )
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    logoOpacity = 1.0
                    logoScale = 1.0
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                    inputOpacity = 1.0
                    inputOffset = 0.0
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }
    
    private func verifyOTP() {
        guard let otpData = otpData else {
            errorMessage = "No OTP data available."
            return
        }
        
        guard enteredOTP == otpData.code else {
            errorMessage = "Invalid OTP. Please try again."
            return
        }
        
        // Check if OTP is expired (e.g., valid for 5 minutes)
        let timeInterval = Date().timeIntervalSince(otpData.timestamp)
        guard timeInterval <= 300 else {
            errorMessage = "OTP has expired. Please resend."
            return
        }
        
        isLoading = true
        print("OTP Verified: \(enteredOTP)")
        
        // Update auth manager state
        DispatchQueue.main.async {
            authManager.userRole = "Member"
            authManager.isAuthenticated = true
            isLoading = false
            onVerify(true)
        }
    }
    
    private func resendOTP() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "User not authenticated."
            return
        }
        
        isLoading = true
        let newOTP = String(Int.random(in: 100000...999999))
        otpData = OTPData(code: newOTP, timestamp: Date())
        
        db.collection("users").document(user.uid).getDocument { document, error in
            guard let document = document, document.exists, let data = document.data(),
                  let name = data["name"] as? String else {
                errorMessage = "Failed to fetch user data."
                isLoading = false
                return
            }
            
            print("Resending OTP: \(newOTP) to \(email)")
            EmailJSManager.shared.sendOTP(to: email, otp: newOTP, userName: name) { result in
                isLoading = false
                switch result {
                case .success:
                    errorMessage = "New OTP sent to your email."
                case .failure(let error):
                    errorMessage = "Failed to resend OTP: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct OTPVerificationScreen_Previews: PreviewProvider {
    static var previews: some View {
        OTPVerificationScreen(
            db: Firestore.firestore(),
            otpData: .constant(OTPData(code: "123456", timestamp: Date())),
            email: "test@example.com",
            onVerify: { _ in }
        )
        .previewDevice("iPhone 14")
        .previewDisplayName("iPhone 14")
    }
}
