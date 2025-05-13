import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddLibrarianView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var name = ""
    @State private var personalEmail = ""
    @State private var govtDocNumber = ""
    @State private var errorMessage = ""
    @State private var isAdminSignedIn = false
    @State private var adminUid = ""
    @State private var isEmailVerified = false
    @State private var isVerifyingEmail = false
    @State private var showingErrorAlert = false
    @State private var refreshTrigger = false // Added to force UI refresh
    var onSave: ((id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String)) -> Void
    private let db = Firestore.firestore()
    private let aadhaarPattern = "^[0-9]{12}$"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Librarian Details")) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .accessibilityLabel("Librarian's full name")
                        .accessibilityHint("Enter the full name of the librarian")
                }
                
                Section(header: Text("Email Verification")) {
                    HStack {
                        TextField("Personal Email", text: $personalEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(isEmailVerified)
                            .accessibilityLabel("Personal email address")
                            .accessibilityHint("Enter the librarian's personal email address")
                        
                        if isVerifyingEmail {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .accessibilityLabel("Verifying email")
                        } else {
                            Button(action: {
                                verifyEmail()
                            }) {
                                Text(isEmailVerified ? "Verified" : "Verify")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(isEmailVerified ? .green : .accentColor)
                            .disabled(isEmailVerified || personalEmail.isEmpty)
                            .accessibilityLabel(isEmailVerified ? "Email verified" : "Verify email")
                            .accessibilityHint(isEmailVerified ? "Email has been verified" : "Tap to send a verification email")
                        }
                    }
                }
                
                Section(header: Text("Government ID")) {
                    TextField("Aadhaar Number", text: $govtDocNumber)
                        .textContentType(.none)
                        .keyboardType(.numberPad)
                        .disabled(!isEmailVerified)
                        .foregroundColor(isEmailVerified ? .primary : .secondary)
                        .accessibilityLabel("Aadhaar number")
                        .accessibilityHint("Enter the 12-digit Aadhaar number")
                }
            }
            .navigationTitle("Add Librarian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel adding librarian")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveLibrarian()
                    }) {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isAdminSignedIn || !isEmailVerified)
                    .accessibilityLabel("Save librarian")
                    .accessibilityHint("Tap to save the librarian's details")
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    showingErrorAlert = false
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                signInAdmin()
            }
        }
    }
    
    private func verifyEmail() {
        guard personalEmail.contains("@") && personalEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            showingErrorAlert = true
            return
        }
        
        isVerifyingEmail = true
        
        let tempPassword = generateStrongPassword()
        Auth.auth().createUser(withEmail: personalEmail, password: tempPassword) { authResult, error in
            if let error = error {
                errorMessage = "Failed to initiate email verification: \(error.localizedDescription)"
                showingErrorAlert = true
                isVerifyingEmail = false
                print("Email verification initiation error: \(error.localizedDescription)")
                return
            }
            
            guard let user = authResult?.user else {
                errorMessage = "Failed to create temporary user for verification."
                showingErrorAlert = true
                isVerifyingEmail = false
                return
            }
            
            sendVerificationEmail(user: user)
        }
    }
    
    private func sendVerificationEmail(user: FirebaseAuth.User) {
        user.sendEmailVerification { error in
            if let error = error {
                errorMessage = "Failed to send verification email: \(error.localizedDescription)"
                showingErrorAlert = true
                isVerifyingEmail = false
                print("Send verification email error: \(error.localizedDescription)")
                
                user.delete { deleteError in
                    if let deleteError = deleteError {
                        print("Failed to delete temporary user: \(deleteError.localizedDescription)")
                    }
                }
                return
            }
            
            print("Verification email sent to \(personalEmail)")
            
            // Start polling for verification status
            let verificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                user.reload { error in
                    if let error = error {
                        print("Error reloading user: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            print("Error code: \(nsError.code), details: \(nsError.userInfo)")
                        }
                        return
                    }
                    
                    print("Checking verification status: isEmailVerified = \(user.isEmailVerified)")
                    
                    if user.isEmailVerified {
                        isEmailVerified = true
                        isVerifyingEmail = false
                        refreshTrigger.toggle() // Force UI refresh
                        timer.invalidate()
                        
                        // Delay deletion to ensure state updates propagate
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            user.delete { deleteError in
                                if let deleteError = deleteError {
                                    print("Failed to delete temporary user: \(deleteError.localizedDescription)")
                                }
                            }
                            signInAdmin()
                        }
                    }
                }
            }
            
            // Timeout after 300 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                if !isEmailVerified {
                    verificationTimer.invalidate()
                    isVerifyingEmail = false
                    errorMessage = "Email verification timed out. Please try again."
                    showingErrorAlert = true
                    
                    user.delete { deleteError in
                        if let deleteError = deleteError {
                            print("Failed to delete temporary user: \(deleteError.localizedDescription)")
                        }
                    }
                    
                    signInAdmin()
                }
            }
        }
    }
    
    private func signInAdmin() {
        let adminEmail = "admin@anybook.com"
        let adminPassword = "Admin@2025!"
        
        Auth.auth().signIn(withEmail: adminEmail, password: adminPassword) { result, error in
            if let error = error {
                errorMessage = "Admin login failed: \(error.localizedDescription)"
                showingErrorAlert = true
                print("Admin sign-in error: \(error.localizedDescription)")
                isAdminSignedIn = false
                return
            }
            
            if let uid = result?.user.uid {
                adminUid = uid
                verifyAdminRole(uid: uid) { isAdmin in
                    isAdminSignedIn = isAdmin
                    if !isAdmin {
                        errorMessage = "Current user does not have admin privileges."
                        showingErrorAlert = true
                        print("Admin role verification failed for UID: \(uid)")
                    } else {
                        print("Admin signed in successfully, UID: \(uid)")
                    }
                }
            } else {
                errorMessage = "Failed to get admin UID."
                showingErrorAlert = true
                isAdminSignedIn = false
            }
        }
    }
    
    private func verifyAdminRole(uid: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Error checking admin role: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let role = snapshot?.data()?["role"] as? String, role == "Admin" else {
                print("Admin role not found for UID: \(uid)")
                completion(false)
                return
            }
            
            print("Admin role confirmed: \(role)")
            completion(true)
        }
    }
    
    private func checkAadhaarNumber(_ aadhaar: String, completion: @escaping (Bool) -> Void) {
        db.collection("users")
            .whereField("govtDocNumber", isEqualTo: aadhaar)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking Aadhaar number: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let snapshot = snapshot, !snapshot.isEmpty {
                    print("Aadhaar number \(aadhaar) already exists")
                    completion(true) // Duplicate found
                } else {
                    print("Aadhaar number \(aadhaar) is unique")
                    completion(false) // No duplicate
                }
            }
    }
    
    private func saveLibrarian() {
        guard !name.isEmpty, !personalEmail.isEmpty, !govtDocNumber.isEmpty else {
            errorMessage = "All fields are required."
            showingErrorAlert = true
            return
        }
        guard isEmailVerified else {
            errorMessage = "Please verify the email address first."
            showingErrorAlert = true
            return
        }
        guard govtDocNumber.range(of: aadhaarPattern, options: .regularExpression) != nil else {
            errorMessage = "Please enter a valid 12-digit Aadhaar number."
            showingErrorAlert = true
            return
        }
        
        // Check for duplicate Aadhaar number
        checkAadhaarNumber(govtDocNumber) { isDuplicate in
            if isDuplicate {
                errorMessage = "Aadhaar number already in use. Please use a different number."
                showingErrorAlert = true
                return
            }
            
            // Proceed with saving if no duplicate is found
            generateUniqueEmail { generatedEmail in
                guard let generatedEmail = generatedEmail else {
                    errorMessage = "Failed to generate a unique email address. Please try again later."
                    showingErrorAlert = true
                    print("Email generation failed")
                    return
                }
                
                let generatedPassword = generateStrongPassword()
                print("Generated credentials: Email: \(generatedEmail), Password: \(generatedPassword)")
                
                Auth.auth().createUser(withEmail: generatedEmail, password: generatedPassword) { authResult, error in
                    if let error = error {
                        errorMessage = "Failed to create user: \(error.localizedDescription)"
                        showingErrorAlert = true
                        print("Authentication error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let newUserUid = authResult?.user.uid else {
                        errorMessage = "Failed to retrieve new user UID."
                        showingErrorAlert = true
                        return
                    }
                    
                    print("New user created with UID: \(newUserUid)")
                    
                    let userId = getLastSixDigits(from: newUserUid)
                    print("Using last 6 digits as user ID: \(userId)")
                    
                    let dateJoined = formattedDate()
                    let userData: [String: Any] = [
                        "userId": userId,
                        "name": name,
                        "role": "Librarian",
                        "email": generatedEmail,
                        "personalEmail": personalEmail,
                        "govtDocNumber": govtDocNumber,
                        "dateJoined": dateJoined,
                        "authUid": newUserUid
                    ]
                    
                    db.collection("users").document(newUserUid).setData(userData) { error in
                        if let error = error {
                            errorMessage = "Failed to save librarian: \(error.localizedDescription)"
                            showingErrorAlert = true
                            print("Firestore write error: \(error.localizedDescription)")
                            print("Attempted to write to: users/\(newUserUid)")
                            print("User data: \(userData)")
                            
                            Auth.auth().currentUser?.delete()
                            signInAdmin()
                            return
                        }
                        
                        print("Successfully saved user data to Firestore")
                        
                        let newUser = (
                            id: userId,
                            name: name,
                            role: "Librarian",
                            email: generatedEmail,
                            personalEmail: personalEmail,
                            govtDocNumber: govtDocNumber,
                            dateJoined: dateJoined
                        )
                        
                        sendCredentialsEmail(to: personalEmail, generatedEmail: generatedEmail, password: generatedPassword)
                        onSave(newUser)
                        
                        signInAdmin()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getLastSixDigits(from uid: String) -> String {
        if uid.count <= 6 {
            return String(format: "%06d", Int(uid) ?? 0)
        }
        
        let startIndex = uid.index(uid.endIndex, offsetBy: -6)
        return String(uid[startIndex..<uid.endIndex])
    }
    
    private func generateUniqueEmail(completion: @escaping (String?) -> Void) {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let maxRetries = 10 // Prevent infinite recursion
        
        func generateRandomEmail() -> String {
            // Generate 3 random letters
            let randomLetters = (0..<3).map { _ in String(letters.randomElement()!) }.joined()
            // Generate random number (3 to 6 digits)
            let randomNumber = Int.random(in: 100...999999)
            return "\(randomLetters)\(randomNumber)@anybook.com"
        }
        
        func checkEmail(_ email: String, counter: Int = 0) {
            print("Checking email availability: \(email), attempt: \(counter + 1)")
            Auth.auth().fetchSignInMethods(forEmail: email) { providers, error in
                if let error = error {
                    print("Firebase error checking email availability: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                print("Firebase response for \(email): Providers = \(String(describing: providers))")
                
                if providers?.isEmpty ?? true {
                    // Email is available
                    print("Email \(email) is available")
                    completion(email)
                } else if counter >= maxRetries {
                    // Max retries reached
                    print("Error: Max retries (\(maxRetries)) reached for email generation")
                    completion(nil)
                } else {
                    // Email exists, try a new random email
                    let newEmail = generateRandomEmail()
                    checkEmail(newEmail, counter: counter + 1)
                }
            }
        }
        
        let initialEmail = generateRandomEmail()
        checkEmail(initialEmail)
    }
    
    private func generateStrongPassword(length: Int = 12) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let special = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        let allChars = letters + numbers + special
        
        var password = ""
        password += String((letters.randomElement() ?? "A").uppercased())
        password += String(letters.randomElement() ?? "a")
        password += String(numbers.randomElement() ?? "0")
        password += String(special.randomElement() ?? "!")
        
        for _ in 0..<(length - 4) {
            password += String(allChars.randomElement() ?? "x")
        }
        
        return String(password.shuffled())
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func sendCredentialsEmail(to email: String, generatedEmail: String, password: String) {
        print("Sending email to \(email) with credentials:")
        print("Email: \(generatedEmail)")
        print("Password: \(password)")
        
        EmailJSManager.shared.sendCredentials(to: email, userName: name, generatedEmail: generatedEmail, password: password) { result in
            switch result {
            case .success:
                print("Credentials email sent successfully to \(email)")
            case .failure(let error):
                print("Failed to send credentials email: \(error.localizedDescription)")
                // Optionally show an alert to the user
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to send credentials email: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    struct AddLibrarianView_Previews: PreviewProvider {
        static var previews: some View {
            AddLibrarianView(onSave: { _ in })
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            AddLibrarianView(onSave: { _ in })
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
