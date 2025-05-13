import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showLogin = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showConfirmation = false
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.8
    @State private var inputOpacity: Double = 0.0
    @State private var buttonScale: CGFloat = 1.0

    private let db = Firestore.firestore()
    
    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image("4")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .transition(.opacity.combined(with: .scale))
                    
                    Text("AnyBook")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .opacity(logoOpacity)
                        .transition(.opacity)
                    
                    Text("Create Account")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Constants.accentColor)
                    
                    VStack(spacing: 12) {
                        TextField("Name", text: $name)
                            .font(.system(size: 16, design: .rounded))
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .opacity(inputOpacity)
                            .transition(.opacity)
                        
                        TextField("Email", text: $email)
                            .font(.system(size: 16, design: .rounded))
                            .textInputAutocapitalization(.none)
                            .onChange(of: email) { newValue in
                                email = newValue.lowercased()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .opacity(inputOpacity)
                            .transition(.opacity)
                        
                        SecureField("Password", text: $password)
                            .font(.system(size: 16, design: .rounded))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .opacity(inputOpacity)
                            .transition(.opacity)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .font(.system(size: 16, design: .rounded))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .opacity(inputOpacity)
                            .transition(.opacity)
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
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    Button(action: {
                        if validateInputs() {
                            signUp()
                        }
                    }) {
                        Text("Sign Up")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 180)
                            .background(Constants.buttonGradient)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                            .scaleEffect(buttonScale)
                    }
                    .disabled(isLoading)
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
                    
                    Button(action: { showLogin = true }) {
                        Text("Already have an account? Log in")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Constants.accentColor)
                            .underline()
                            .scaleEffect(buttonScale)
                    }
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
                    .fullScreenCover(isPresented: $showLogin) {
                        LoginView()
                    }
                    
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
                .alert(isPresented: $showConfirmation) {
                    Alert(
                        title: Text("Verification Sent"),
                        message: Text("Please check your email to verify your account."),
                        dismissButton: .default(Text("OK")) {
                            showLogin = true
                        }
                    )
                }
                .onAppear {
                    withAnimation(.easeIn(duration: 0.6)) {
                        logoOpacity = 1.0
                        logoScale = 1.0
                        inputOpacity = 1.0
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Input Validation
    private func validateInputs() -> Bool {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "All fields are required."
            return false
        }
        guard name.count >= 3 else {
            errorMessage = "Name must be at least 3 characters long."
            return false
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long."
            return false
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }
        errorMessage = ""
        return true
    }
    
    // MARK: - User ID Generation
    private func generateRandomUserId() async throws -> String {
        let randomId = String(format: "%06d", Int.random(in: 100000...999999))
        
        let query = db.collection("users").whereField("userId", isEqualTo: randomId)
        let snapshot = try await query.getDocuments()
        
        if snapshot.isEmpty {
            return randomId
        } else {
            return try await generateRandomUserId()
        }
    }
    
    // MARK: - Date Formatting
    private func formatDateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Sign Up Logic
    private func signUp() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let userId = try await generateRandomUserId()
                
                let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
                let user = authResult.user
                
                try await user.sendEmailVerification()
                
                let currentDate = Date()
                let userData: [String: Any] = [
                    "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "email": email,
                    "role": "Member",
                    "userId": userId,
                    "joinedDate": formatDateToString(currentDate), // Store as "yyyy-MM-dd" string
                    "membershipPlan": "None",
                    "membershipExpiryDate": NSNull(),
                    "settings": [
                        "notifications": true,
                        "darkMode": false
                    ]
                ]
                
                try await db.collection("users").document(user.uid).setData(userData)
                
                showConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    // MARK: - Email Validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SignUpView()
                .previewDevice("iPhone 14")
                .previewDisplayName("iPhone 14")
            
            SignUpView()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
                .environment(\.colorScheme, .dark)
        }
    }
}
