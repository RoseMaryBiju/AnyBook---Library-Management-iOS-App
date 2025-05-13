import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Profile Picture Placeholder
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(radius: 4)
                            
                            Text(viewModel.name.isEmpty ? "Librarian" : viewModel.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(viewModel.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Profile: \(viewModel.name), \(viewModel.email)")
                        
                        // Form Content
                        VStack(spacing: 16) {
                            // Personal Information Section
                            SectionView(title: "Personal Information") {
                                CustomTextField(
                                    title: "Name",
                                    text: $viewModel.name,
                                    isDisabled: viewModel.isLoading,
                                    accessibilityLabel: "Librarian Name"
                                )
                                
                                CustomTextField(
                                    title: "Email",
                                    text: $viewModel.email,
                                    isDisabled: true,
                                    keyboardType: .emailAddress,
                                    accessibilityLabel: "Librarian Email"
                                )
                            }
                            
                            // App Settings Section
                            SectionView(title: "App Settings") {
                                Toggle("Push Notifications", isOn: $viewModel.notificationsEnabled)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .accessibilityLabel("Toggle Push Notifications")
                            }
                            
                            // Account Section
                            SectionView(title: "Account") {
                                Button(action: { showingSignOutConfirmation = true }) {
                                    Text("Sign Out")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundColor(.red)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(10)
                                }
                                .accessibilityLabel("Sign Out Button")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Librarian Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveProfile()
                            if viewModel.errorMessage == nil {
                                withAnimation {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.isValid)
                    .opacity(viewModel.isLoading ? 0.6 : 1.0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        withAnimation {
                            dismiss()
                        }
                    }
                }
            }
            .overlay(
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                    withAnimation {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .onAppear {
                withAnimation(.easeInOut) {
                    viewModel.loadProfile()
                }
            }
        }
    }
}

// Custom Section View
struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 8) {
                content
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

// Custom Text Field
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let isDisabled: Bool
    var keyboardType: UIKeyboardType = .default
    let accessibilityLabel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField(title, text: $text)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .disabled(isDisabled)
                .keyboardType(keyboardType)
                .accessibilityLabel(accessibilityLabel)
        }
        .padding(.horizontal, 16)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// ViewModel for Profile
class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var notificationsEnabled: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.isValidEmail()
    }
    
    func loadProfile() {
        guard let user = auth.currentUser else {
            errorMessage = "No user logged in"
            showError = true
            return
        }
        
        isLoading = true
        db.collection("users").document(user.uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.showError = true
                return
            }
            
            if let document = document, document.exists, let data = document.data() {
                self.name = data["name"] as? String ?? ""
                self.email = user.email ?? ""
                self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true
            }
        }
        
        // Load from UserDefaults as fallback
        if name.isEmpty {
            name = UserDefaults.standard.string(forKey: "librarianName") ?? ""
        }
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }
    
    func saveProfile() async {
        guard let user = auth.currentUser else {
            errorMessage = "No user logged in"
            showError = true
            return
        }
        
        isLoading = true
        do {
            try await db.collection("users").document(user.uid).setData([
                "name": name,
                "email": email,
                "notificationsEnabled": notificationsEnabled,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Update UserDefaults as fallback
            UserDefaults.standard.set(name, forKey: "librarianName")
            UserDefaults.standard.set(email, forKey: "librarianEmail")
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: "librarianName")
            UserDefaults.standard.removeObject(forKey: "librarianEmail")
            UserDefaults.standard.removeObject(forKey: "notificationsEnabled")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// Email validation extension
extension String {
    func isValidEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }
}

// Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
