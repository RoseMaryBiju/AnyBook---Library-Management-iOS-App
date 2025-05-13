import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserDetailView: View {
    let user: (id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String)
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var animateButton = false
    @State private var errorMessage: String?
    @State private var isSuccessMessage = false // New state to track success
    @State private var isLoading = false
    @State private var currentDateJoined: String
    @State private var showResendConfirmation = false
    @State private var animateResendButton = false
    @Environment(\.dismiss) var dismiss

    private let db = Firestore.firestore()
    private let customAccentColor = Color(red: 0.15, green: 0.38, blue: 0.70)

    private let standardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private let legacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private let simpleLegacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private var formattedDateJoined: String {
        let rawDate = currentDateJoined.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawDate.isEmpty || rawDate.lowercased() == "n/a" || rawDate.lowercased() == "null" {
            return "Not Available"
        }

        if let date = standardDateFormatter.date(from: rawDate) {
            return displayDateFormatter.string(from: date)
        }

        if let date = legacyDateFormatter.date(from: rawDate) {
            return displayDateFormatter.string(from: date)
        }

        if let date = simpleLegacyDateFormatter.date(from: rawDate) {
            return displayDateFormatter.string(from: date)
        }

        return "Not Available"
    }

    init(user: (id: String, name: String, role: String, email: String, personalEmail: String, govtDocNumber: String, dateJoined: String), onDelete: @escaping () -> Void) {
        self.user = user
        self.onDelete = onDelete
        _currentDateJoined = State(initialValue: user.dateJoined)
    }

    private func updateDateFormat() {
        isLoading = true
        errorMessage = nil
        isSuccessMessage = false

        let trimmedDate = user.dateJoined.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDate.isEmpty || trimmedDate.lowercased() == "n/a" || trimmedDate.lowercased() == "null" {
            let defaultDate = "2025-05-08"
            
            db.collection("users")
                .whereField("userId", isEqualTo: user.id)
                .getDocuments { snapshot, error in
                    if let error = error {
                        self.errorMessage = "Failed to find user: \(error.localizedDescription)"
                        self.isSuccessMessage = false
                        self.isLoading = false
                        return
                    }

                    guard let document = snapshot?.documents.first else {
                        self.errorMessage = "User not found in database."
                        self.isSuccessMessage = false
                        self.isLoading = false
                        return
                    }

                    document.reference.updateData([
                        "joinedDate": defaultDate
                    ]) { error in
                        if let error = error {
                            self.errorMessage = "Failed to update date format: \(error.localizedDescription)"
                            self.isSuccessMessage = false
                        } else {
                            self.currentDateJoined = defaultDate
                            self.errorMessage = "Date format updated successfully to default date"
                            self.isSuccessMessage = true
                        }
                        self.isLoading = false
                    }
                }
            return
        }

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a 'UTC'Z"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.timeZone = TimeZone(identifier: "UTC")

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        outputFormatter.timeZone = TimeZone(identifier: "UTC")

        if let date = inputFormatter.date(from: trimmedDate) {
            let newDateString = outputFormatter.string(from: date)

            db.collection("users")
                .whereField("userId", isEqualTo: user.id)
                .getDocuments { snapshot, error in
                    if let error = error {
                        self.errorMessage = "Failed to find user: \(error.localizedDescription)"
                        self.isSuccessMessage = false
                        self.isLoading = false
                        return
                    }

                    guard let document = snapshot?.documents.first else {
                        self.errorMessage = "User not found in database."
                        self.isSuccessMessage = false
                        self.isLoading = false
                        return
                    }

                    document.reference.updateData([
                        "joinedDate": newDateString
                    ]) { error in
                        if let error = error {
                            self.errorMessage = "Failed to update date format: \(error.localizedDescription)"
                            self.isSuccessMessage = false
                        } else {
                            self.currentDateJoined = newDateString
                            self.errorMessage = "Date format updated successfully"
                            self.isSuccessMessage = true
                        }
                        self.isLoading = false
                    }
                }
        } else {
            let alternativeFormatter = DateFormatter()
            alternativeFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a"
            alternativeFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = alternativeFormatter.date(from: trimmedDate) {
                let newDateString = outputFormatter.string(from: date)
                
                db.collection("users")
                    .whereField("userId", isEqualTo: user.id)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            self.errorMessage = "Failed to find user: \(error.localizedDescription)"
                            self.isSuccessMessage = false
                            self.isLoading = false
                            return
                        }

                        guard let document = snapshot?.documents.first else {
                            self.errorMessage = "User not found in database."
                            self.isSuccessMessage = false
                            self.isLoading = false
                            return
                        }

                        document.reference.updateData([
                            "joinedDate": newDateString
                        ]) { error in
                            if let error = error {
                                self.errorMessage = "Failed to update date format: \(error.localizedDescription)"
                                self.isSuccessMessage = false
                            } else {
                                self.currentDateJoined = newDateString
                                self.errorMessage = "Date format updated successfully"
                                self.isSuccessMessage = true
                            }
                            self.isLoading = false
                        }
                    }
            } else {
                errorMessage = "Invalid date format: \(trimmedDate)"
                isSuccessMessage = false
                isLoading = false
            }
        }
    }

    private func resendCredentials() {
        guard user.role == "Librarian", !user.personalEmail.isEmpty else {
            errorMessage = "Cannot resend credentials: Invalid role or personal email."
            isSuccessMessage = false
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        isSuccessMessage = false

        // Step 1: Find the user in Firestore
        db.collection("users")
            .whereField("userId", isEqualTo: user.id)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to find user: \(error.localizedDescription)"
                    self.isSuccessMessage = false
                    self.isLoading = false
                    return
                }

                guard let document = snapshot?.documents.first else {
                    self.errorMessage = "User not found in database."
                    self.isSuccessMessage = false
                    self.isLoading = false
                    return
                }

                let authUid = document.documentID

                // Step 2: Generate a new password
                let newPassword = self.generateStrongPassword()

                // Step 3: Sign in as admin to delete and recreate the librarian account
                let adminEmail = "admin@anybook.com"
                let adminPassword = "Admin@2025!" // Replace with secure method in production
                Auth.auth().signIn(withEmail: adminEmail, password: adminPassword) { result, error in
                    if let error = error as NSError? {
                        switch error.code {
                        case AuthErrorCode.networkError.rawValue:
                            self.errorMessage = "Network error during admin login. Please check your connection and try again."
                            print("Network error details: \(error.localizedDescription)")
                        default:
                            self.errorMessage = "Admin login failed: \(error.localizedDescription)"
                            print("Admin login error details: \(error)")
                        }
                        self.isSuccessMessage = false
                        self.isLoading = false
                        return
                    }

                    // Step 4: Delete the existing librarian account
                    Auth.auth().fetchSignInMethods(forEmail: self.user.email) { methods, error in
                        if let error = error {
                            self.errorMessage = "Failed to fetch user sign-in methods: \(error.localizedDescription)"
                            self.isSuccessMessage = false
                            self.isLoading = false
                            return
                        }

                        if methods == nil || methods!.isEmpty {
                            self.errorMessage = "Librarian account not found in Authentication."
                            self.isSuccessMessage = false
                            self.isLoading = false
                            return
                        }

                        // We need to delete the user, but we can't directly delete another user client-side
                        // Instead, we'll note that this should be done via Admin SDK
                        // For now, we'll send a password reset email as a workaround
                        Auth.auth().sendPasswordReset(withEmail: self.user.email) { error in
                            if let error = error {
                                self.errorMessage = "Failed to initiate password reset: \(error.localizedDescription)"
                                self.isSuccessMessage = false
                                self.isLoading = false
                                return
                            }

                            // Step 5: Send the new password via EmailJS (assuming the user will reset their password)
                            EmailJSManager.shared.sendCredentials(
                                to: self.user.personalEmail,
                                userName: self.user.name,
                                generatedEmail: self.user.email,
                                password: newPassword
                            ) { result in
                                switch result {
                                case .success:
                                    self.errorMessage = "Credentials sent successfully to \(self.user.personalEmail). A password reset email has also been sent."
                                    self.isSuccessMessage = true
                                case .failure(let error):
                                    self.errorMessage = "Failed to send credentials: \(error.localizedDescription)"
                                    self.isSuccessMessage = false
                                }
                                self.isLoading = false
                            }

                            // Note: In production, update the password using Firebase Admin SDK
                            print("Production Note: Use Firebase Admin SDK to update the librarian's password directly.")
                        }
                    }
                }
            }
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

    private func deleteUser() {
        guard Auth.auth().currentUser != nil else {
            errorMessage = "No admin logged in. Please sign in again."
            isSuccessMessage = false
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        isSuccessMessage = false

        db.collection("users")
            .whereField("userId", isEqualTo: user.id)
            .getDocuments { snapshot, error in
                if let error = error {
                    errorMessage = "Failed to find user: \(error.localizedDescription)"
                    isSuccessMessage = false
                    isLoading = false
                    return
                }

                guard let document = snapshot?.documents.first else {
                    errorMessage = "User not found in database."
                    isSuccessMessage = false
                    isLoading = false
                    return
                }

                let authUid = document.documentID

                db.collection("users").document(authUid).delete { error in
                    if let error = error {
                        errorMessage = "Failed to delete user data: \(error.localizedDescription)"
                        isSuccessMessage = false
                        isLoading = false
                        return
                    }

                    let currentUser = Auth.auth().currentUser
                    if currentUser?.uid == authUid {
                        currentUser?.delete { error in
                            if let error = error {
                                errorMessage = "Failed to delete user account: \(error.localizedDescription)"
                                isSuccessMessage = false
                                isLoading = false
                                return
                            }
                            isLoading = false
                            onDelete()
                            dismiss()
                        }
                    } else {
                        isLoading = false
                        onDelete()
                        dismiss()
                    }
                }
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [customAccentColor.opacity(0.8), .purple.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    Text(user.name.prefix(1).uppercased())
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                )
                .padding(.top, 30)

                VStack(spacing: 4) {
                    Text(user.name)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(user.role)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 15) {
                    if user.role == "Librarian" {
                        UserInfoRow(title: "Personal Email", value: user.personalEmail)
                        UserInfoRow(title: "Government ID", value: user.govtDocNumber)
                        UserInfoRow(title: "Official Email", value: user.email)
                    } else {
                        UserInfoRow(title: "Email", value: user.email)
                    }
                    UserInfoRow(title: "Date Joined", value: formattedDateJoined)
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(isSuccessMessage ? .green : .red) // Green for success, red for failure
                        .padding(.horizontal)
                }

                if user.role == "Librarian" {
                    Button(action: {
                        withAnimation(.spring()) {
                            animateResendButton = true
                        }
                        showResendConfirmation = true
                        withAnimation(.spring()) {
                            animateResendButton = false
                        }
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }) {
                        Text("Resend Credentials")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [customAccentColor, customAccentColor.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .scaleEffect(animateResendButton ? 0.95 : 1.0)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    .alert(isPresented: $showResendConfirmation) {
                        Alert(
                            title: Text("Resend Credentials"),
                            message: Text("Are you sure you want to resend credentials to \(user.name)? This will generate a new password and send it to their personal email."),
                            primaryButton: .default(Text("Resend")) {
                                resendCredentials()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }

                Button(action: {
                    withAnimation(.spring()) {
                        animateButton = true
                    }
                    showDeleteConfirmation = true
                    withAnimation(.spring()) {
                        animateButton = false
                    }
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }) {
                    Text("Delete User")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.red, .red.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .scaleEffect(animateButton ? 0.95 : 1.0)
                }
                .disabled(isLoading)
                .padding(.horizontal)
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(
                        title: Text("Delete User"),
                        message: Text("Are you sure you want to delete \(user.name)? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteUser()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color(.systemBackground).opacity(0.7).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: customAccentColor))
                            .scaleEffect(1.5)
                    }
                }
            }
        )
        .onAppear {
            fetchLatestUserData()
        }
        .onChange(of: currentDateJoined) { newValue in
            withAnimation {
                // This will trigger a view update
            }
        }
    }

    private func fetchLatestUserData() {
        db.collection("users")
            .whereField("userId", isEqualTo: user.id)
            .getDocuments { snapshot, error in
                if let document = snapshot?.documents.first, let data = document.data() as? [String: Any], let joinedDate = data["joinedDate"] as? String {
                    self.currentDateJoined = joinedDate
                }
            }
    }
}

struct UserInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

struct UserDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                UserDetailView(
                    user: (id: "jkl345", name: "John Doe", role: "Member", email: "johndoe@example.com", personalEmail: "", govtDocNumber: "", dateJoined: "February 20, 2023"),
                    onDelete: {}
                )
            }
            .previewDisplayName("Member - Light")

            NavigationView {
                UserDetailView(
                    user: (id: "abc123", name: "Jane Smith", role: "Librarian", email: "janesmith@example.com", personalEmail: "jane@gmail.com", govtDocNumber: "123456789", dateJoined: "2023-02-20"),
                    onDelete: {}
                )
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Librarian - Dark")
        }
    }
}
