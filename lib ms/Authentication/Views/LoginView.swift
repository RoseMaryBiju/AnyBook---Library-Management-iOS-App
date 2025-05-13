import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct OTPData {
    let code: String
    let timestamp: Date
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showOTPVerification = false
    @State private var otpData: OTPData?
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToAdmin = false
    @State private var navigateToLibrarian = false
    @State private var navigateToMember = false
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.8
    @State private var inputOpacity: Double = 0.0
    @State private var inputOffset: CGFloat = 50.0
    @State private var buttonScale: CGFloat = 1.0
    @State private var isEmailValid = false
    @State private var isPasswordValid = false
    @FocusState private var focusedField: Field?
    @StateObject private var authManager = AuthManager.shared

    private let db = Firestore.firestore()
    
    enum Field: Hashable {
        case email, password
    }
    
    private struct Constants {
        static let accentColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        static let buttonGradient = LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
        static let backgroundGradient = LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.1)]), startPoint: .top, endPoint: .bottom)
        static let adminEmails = ["admin1@library.com", "admin2@library.com", "admin@anybook.com"]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
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
                    
                    Text("Sign In")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.accentColor)
                        .opacity(logoOpacity)
                    
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .leading) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .offset(y: email.isEmpty && focusedField != .email ? 0 : -20)
                                    .scaleEffect(email.isEmpty && focusedField != .email ? 1 : 0.8)
                                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.gray)
                                    TextField("", text: $email)
                                        .textInputAutocapitalization(.none)
                                        .focused($focusedField, equals: .email)
                                        .onChange(of: email) { newValue in
                                            email = newValue.lowercased()
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
                            Text("Enter a valid email (e.g., user@example.com)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .leading) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .offset(y: password.isEmpty && focusedField != .password ? 0 : -20)
                                    .scaleEffect(password.isEmpty && focusedField != .password ? 1 : 0.8)
                                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.gray)
                                    SecureField("", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .onChange(of: password) { newValue in
                                            isPasswordValid = newValue.count >= 6
                                        }
                                        .accessibilityLabel("Password")
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isPasswordValid && !password.isEmpty ? Color.green : errorMessage.contains("password") ? Color.red : Color.gray.opacity(0.3), lineWidth: isPasswordValid && !password.isEmpty ? 1.5 : 1)
                                )
                            }
                            Text("Password must be at least 6 characters")
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
                        initiateLogin()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
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
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Sign In Button")
                    
                    HStack(spacing: 20) {
                        Button(action: { showSignUp = true }) {
                            Text("Create Account")
                                .font(.subheadline)
                                .foregroundColor(Constants.accentColor)
                                .padding(.vertical, 8)
                        }
                        .accessibilityLabel("Sign Up")
                        
                        Button(action: { showForgotPassword = true }) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(Constants.accentColor)
                                .padding(.vertical, 8)
                        }
                        .accessibilityLabel("Forgot Password")
                    }
                    .padding(.top, 8)
                    .opacity(inputOpacity)
                    
                    Spacer()
                }
                .padding(.vertical)
                .fullScreenCover(isPresented: $showSignUp) {
                    SignUpView()
                }
                .fullScreenCover(isPresented: $showForgotPassword) {
                    ForgotPasswordView()
                }
                .sheet(isPresented: $showOTPVerification) {
                    OTPVerificationScreen(db: db, otpData: $otpData, email: email) { result in
                        print("OTP Verification Result: \(result)")
                        DispatchQueue.main.async {
                            if result {
                                print("Navigating to HomePage for Member")
                                navigateToMember = true
                                showOTPVerification = false
                            } else {
                                errorMessage = "OTP verification failed. Please try again."
                                try? Auth.auth().signOut()
                            }
                        }
                    }
                }
                .fullScreenCover(isPresented: $navigateToAdmin) {
                    AdminDashboardView()
                }
                .fullScreenCover(isPresented: $navigateToLibrarian) {
                    LibrarianInterface()
                }
                .fullScreenCover(isPresented: $navigateToMember) {
                    HomePage(role: "Member")
                }
            }
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
                createAdminAccounts()
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Login Logic
    private func initiateLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            isLoading = false
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error as NSError? {
                switch error.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    errorMessage = "Incorrect password. Try again or use 'Forgot Password'."
                case AuthErrorCode.userNotFound.rawValue, AuthErrorCode.invalidEmail.rawValue:
                    errorMessage = "No account found for this email. Please sign up."
                case AuthErrorCode.weakPassword.rawValue:
                    errorMessage = "Password is too weak."
                default:
                    errorMessage = "Login failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let user = result?.user else {
                errorMessage = "Unexpected error: No user found."
                return
            }
            
            db.collection("users").document(user.uid).getDocument { document, error in
                if let error = error {
                    errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                    try? Auth.auth().signOut()
                    return
                }
                
                guard let document = document, document.exists, let data = document.data(),
                      let role = data["role"] as? String else {
                    errorMessage = "User data or role not found."
                    try? Auth.auth().signOut()
                    return
                }
                
                print("User Role: \(role)")
                
                switch role {
                case "Admin":
                    if !Constants.adminEmails.contains(email) {
                        errorMessage = "Unauthorized: Only predefined admin accounts can access Admin role."
                        try? Auth.auth().signOut()
                        return
                    }
                    print("Navigating to Admin Dashboard")
                    DispatchQueue.main.async {
                        authManager.userRole = role
                        authManager.isAuthenticated = true
                        navigateToAdmin = true
                    }
                case "Librarian":
                    print("Navigating to LibrarianInterface")
                    DispatchQueue.main.async {
                        authManager.userRole = role
                        authManager.isAuthenticated = true
                        navigateToLibrarian = true
                    }
                case "Member":
                    let otp = generateOTP()
                    otpData = OTPData(code: otp, timestamp: Date())
                    
                    print("Sending OTP: \(otp) to \(email)")
                    EmailJSManager.shared.sendOTP(to: email, otp: otp, userName: data["name"] as? String ?? "User") { result in
                        switch result {
                        case .success:
                            print("OTP sent successfully, showing OTPVerificationScreen")
                            DispatchQueue.main.async {
                                showOTPVerification = true
                            }
                        case .failure(let error):
                            errorMessage = "Failed to send OTP: \(error.localizedDescription)"
                            try? Auth.auth().signOut()
                        }
                    }
                default:
                    errorMessage = "Invalid role: \(role)"
                    try? Auth.auth().signOut()
                    return
                }
            }
        }
    }
    
    // MARK: - OTP Generation
    private func generateOTP() -> String {
        String(Int.random(in: 100000...999999))
    }
    
    // MARK: - Admin Account Creation
    private func createAdminAccounts() {
        let adminAccounts: [(email: String, password: String, name: String, userId: String, dateJoined: String?)] = [
            (email: "admin1@library.com", password: "Admin123!", name: "Admin One", userId: "100001", dateJoined: nil),
            (email: "admin2@library.com", password: "Admin456!", name: "Admin Two", userId: "100002", dateJoined: nil),
            (email: "admin@anybook.com", password: "Admin@2025!", name: "Admin User", userId: "adminCustomId", dateJoined: "2025-04-25")
        ]
        
        for admin in adminAccounts {
            Auth.auth().fetchSignInMethods(forEmail: admin.email) { methods, error in
                if let error = error {
                    print("Error checking admin email: \(error.localizedDescription)")
                    return
                }
                
                if methods?.isEmpty ?? true {
                    Auth.auth().createUser(withEmail: admin.email, password: admin.password) { result, error in
                        if let error = error as NSError? {
                            if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                                Auth.auth().signIn(withEmail: admin.email, password: admin.password) { _, signInError in
                                    if let signInError = signInError {
                                        print("Failed to sign in existing admin: \(signInError.localizedDescription)")
                                    } else {
                                        saveAdminData(uid: Auth.auth().currentUser?.uid, admin: admin)
                                    }
                                }
                            }
                            return
                        }
                        
                        guard let user = result?.user else { return }
                        saveAdminData(uid: user.uid, admin: admin)
                    }
                } else {
                    Auth.auth().signIn(withEmail: admin.email, password: admin.password) { _, error in
                        if let error = error {
                            print("Failed to sign in to update Firestore: \(error.localizedDescription)")
                            return
                        }
                        if let uid = Auth.auth().currentUser?.uid {
                            saveAdminData(uid: uid, admin: admin)
                        }
                    }
                }
            }
        }
    }
    
    private func saveAdminData(uid: String?, admin: (email: String, password: String, name: String, userId: String, dateJoined: String?)) {
        guard let uid = uid else { return }
        
        var userData: [String: Any] = [
            "name": admin.name,
            "email": admin.email,
            "role": "Admin",
            "userId": admin.userId,
            "joinedDate": admin.dateJoined != nil ? Timestamp(date: dateFormatter.date(from: admin.dateJoined!) ?? Date()) : Timestamp(date: Date()),
            "membershipPlan": "None",
            "membershipExpiryDate": NSNull(),
            "settings": ["notifications": true, "darkMode": false]
        ]
        
        db.collection("users").document(uid).setData(userData) { error in
            if let error = error {
                print("Error saving admin data: \(error.localizedDescription)")
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    // MARK: - Email Validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
